#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary neutron
check_binary terraform

declare -g capture_id
declare -g port_id
declare -g tracking_id

task_default() {
    runner_sequence setup capture can_ping_backend delete_router cannot_ping_backend
    result=${?}
    runner_sequence teardown 
    return $result
}

task_setup() {
    retry 3 terraform apply || return 1
    port_id=$(resource_id "openstack_networking_port_v2.hr_bastion_port") || return 1
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
    sleep 7
}

task_delete_capture() {
    delete_capture $capture_id
}

task_can_ping_backend() {
    result=$(gremlin "G.V().Has('Neutron/PortID', '$port_id').Flows().Has('Application', 'ICMPv4')") || return 1
    tracking_id=$(echo $result | jq -r '.[].TrackingID')
    if [[ -z $tracking_id ]]; then
        runner_log_error "No flow found"
        return 1
    else
        runner_log_success "Found expected flow with TrackingID ${tracking_id}"
    fi
    both_sides=$(echo $result | jq '.[].Metric | has("ABPackets") and has("BAPackets")')
    if [[ $both_sides == "false" ]] || [[ -z $both_sides ]]; then
        runner_log_error "Ping doesn't work. No reply from backend."
        return 1
    else
        runner_log_success "Reply to ping found"
    fi
}

task_delete_router() {
    router_id=$(resource_id "openstack_compute_instance_v2.hr_router") || return 1
    runner_run nova delete $router_id
}

task_cannot_ping_backend() {
    local -r flow1=$(gremlin "G.V().Has('Neutron/PortID', '$port_id').Flows().Has('TrackingID', '${tracking_id}')") || return 1
    local -i flow1AB=$(echo $flow1 | jq -r '.[].Metric.ABPackets')
    local -i flow1BA=$(echo $flow1 | jq -r '.[].Metric.BAPackets')
    runner_log_notice "Flow has $flow1AB ABPackets and $flow1BA BAPackets"
    sleep 3
    local -r flow2=$(gremlin "G.V().Has('Neutron/PortID', '$port_id').Flows().Has('TrackingID', '${tracking_id}')") || return 1
    local -i flow2AB=$(echo $flow2 | jq -r '.[].Metric.ABPackets')
    local -i flow2BA=$(echo $flow2 | jq -r '.[].Metric.BAPackets')
    runner_log_notice "Flow has now $flow2AB ABPackets and $flow2BA BAPackets"

    if [[ $flow2AB -gt $flow1AB ]] && [[ $flow2BA -eq $flow1BA ]]; then
        runner_log_success "No reply to ping found"
    elif [[ $flow2AB -eq $flow1AB ]] && [[ $flow2BA -gt $flow1BA ]]; then
        runner_log_success "No reply to ping found"
    else
        runner_log_error "Ping shouldn't work between VMs"
        return 1
    fi
}
