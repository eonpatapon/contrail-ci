#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

task_default() {
    runner_sequence setup capture can_ping_google
    result=${?}
    runner_sequence teardown
    return $result
}

task_setup() {
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
    port_ids=$(fuzzy_resource_ids "openstack_networking_port_v2.snat_client_port") || return 1
    for port_id in $port_ids
    do
        local itf_name="tap${port_id:0:11}"
        capture_id=$(capture "G.V().Has('Name', '${itf_name}')" "SNAT test") || return 1
        capture_ids="${capture_ids} ${capture_id}"
        itf_names="${itf_names} ${itf_name}"
    done
    save_vars itf_names capture_ids
}

task_can_ping_google() {
    `get_vars`
    for itf_name in $itf_names
    do
        flow=$(wait_flow 20 "G.V().Has('Name', '${itf_name}').Flows().Has('Application', 'ICMPv4').Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
    done
}

task_delete_capture() {
    `get_vars`
    for capture_id in $capture_ids
    do
        delete_capture $capture_id
    done
}
