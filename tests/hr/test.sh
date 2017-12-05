#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary neutron

task_default() {
    runner_sequence setup capture can_ping_backend delete_router cannot_ping_backend
    result=${?}
    runner_sequence teardown
    return $result
}

task_setup() {
    clean_vars
    terrapply || return 1
}

task_destroy() {
    terradestroy || return 1
}

task_teardown() {
    runner_parallel delete_capture destroy
    clean_vars
}

task_capture() {
    itf_name=$(port_interface_name "hr_bastion_port") || return 1
    capture_id=$(capture "G.V().Has('Name', '${itf_name}')" "HR test") || return 1
    save_vars itf_name capture_id
}

task_delete_capture() {
    delete_capture $capture_id
}

task_can_ping_backend() {
    `get_vars`
    flow=$(wait_flow 20 "G.V().Has('Name', '${itf_name}').Flows().Has('Application', 'ICMPv4').Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
    tracking_id=$(echo "${flow}" | jq -r '.[].TrackingID')
    runner_log_success "Found expected flow with TrackingID ${tracking_id}"
    save_vars tracking_id
}

task_delete_router() {
    router_id=$(resource_id "openstack_compute_instance_v2.hr_router") || return 1
    runner_run nova delete $router_id
    sleep 5
}

task_cannot_ping_backend() {
    `get_vars`
    flow1=$(gremlin "G.V().Has('Name', '$itf_name').Flows().Has('TrackingID', '${tracking_id}')") || return 1
    local -i flow1AB=$(echo $flow1 | jq -r '.[].Metric.ABPackets')
    local -i flow1BA=$(echo $flow1 | jq -r '.[].Metric.BAPackets')
    runner_log_notice "Flow has $flow1AB ABPackets and $flow1BA BAPackets"
    sleep 3
    flow2=$(gremlin "G.V().Has('Name', '$itf_name').Flows().Has('TrackingID', '${tracking_id}')") || return 1
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
