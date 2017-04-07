#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

declare -g capture_ids
declare -g itf_names

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
    rm -f environ
}

task_teardown() {
    runner_parallel delete_capture destroy
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
    declare -p itf_names capture_ids > environ
}

task_can_ping_google() {
    source environ
    for itf_name in $itf_names
    do
        flow=$(wait_flow 20 "G.V().Has('Name', '${itf_name}').Flows().Has('Application', 'ICMPv4').Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
    done
}

task_delete_capture() {
    source environ
    for capture_id in $capture_ids
    do
        delete_capture $capture_id
    done
}
