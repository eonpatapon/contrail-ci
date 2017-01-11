#!/bin/bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary neutron
check_binary terraform

declare -g capture_id
declare -g port_id
declare -g tracking_id

task_default() {
    runner_sequence setup capture should_see_ping_on_both_ends delete_capture remove_sg_rule capture should_not_see_ping_on_both_ends
    result=${?}
    runner_sequence teardown 
    return $result
}

task_setup() {
    retry 3 terraform apply || return 1
    port_id=$(resource_id "openstack_networking_port_v2.sg_vm1_port") || return 1
}

task_destroy() {
    retry 3 terraform destroy -force || return 1
}

task_teardown() {
    runner_parallel delete_capture destroy
}

task_capture() {
    capture_id=$(capture "G.V().Has('Neutron/PortID', '${port_id}')") || return 1
    # wait a bit to collect some data
    sleep 5
}

task_delete_capture() {
    delete_capture $capture_id
}

task_should_see_ping_on_both_ends() {
    local -r result=$(gremlin "G.V().Has('Neutron/PortID', '$port_id').Flows().Has('Application', 'ICMPv4')") || return 1
    local -r both_sides=$(echo $result | jq '.[].Metric | has("ABPackets") and has("BAPackets")')
    tracking_id=$(echo $result | jq -r '.[].TrackingID')
    runner_log_success "Found expected flow with TrackingID ${tracking_id}"
    if [[ $both_sides == "false" ]] || [[ $both_sides == "" ]]; then
        runner_log_error "Ping doesn't work between VMs"
        return 1
    fi
}

task_should_not_see_ping_on_both_ends() {
    local -r result=$(gremlin "G.V().Has('Neutron/PortID', '$port_id').Flows().Has('Application', 'ICMPv4')") || return 1
    if [[ $tracking_id != $(echo $result | jq -r '.[].TrackingID') ]]; then
        runner_log_error "Can't find the flow"
        return 1
    else
        runner_log_success "Found expected flow with TrackingID ${tracking_id}"
    fi
    both_sides=$(echo $result | jq '.[].Metric | has("ABPackets") and has("BAPackets")')
    if [[ $both_sides == "true" ]] || [[ $both_sides == "" ]]; then
        runner_log_error "Ping shouldn't work between VMs"
        return 1
    fi
}

task_remove_sg_rule() {
    uuid=$(neutron security-group-rule-list | grep 'sg_secgroup' | grep 'ingress' | grep 'icmp' | cut -d'|' -f2)
    runner_run neutron security-group-rule-delete $uuid
}
