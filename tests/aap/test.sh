#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

task_default() {
    runner_sequence setup capture can_ping_vip_vm1 \
                    remove_vm1 can_ping_vip_vm2 \
                    # delete_capture setup capture can_ping_vip_vm1
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
    itf_name_vm1=$(port_interface_name "aap_vm1_port") || return 1
    itf_name_vm2=$(port_interface_name "aap_vm2_port") || return 1
    for itf_name in ${itf_name_vm1} ${itf_name_vm2}
    do
        capture_id=$(capture "G.V().Has('Name', '${itf_name}')" "AAP test") || return 1
        capture_ids="${capture_ids} ${capture_id}"
    done
    save_vars capture_ids itf_name_vm1 itf_name_vm2
}

task_delete_capture() {
    `get_vars`
    for capture_id in $capture_ids
    do
        delete_capture $capture_id
    done
}

task_can_ping_vip_vm1() {
    `get_vars`
    flow=$(wait_flow 60 "G.V().Has('Name', '${itf_name_vm1}').Flows().Has('Application', 'ICMPv4').Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
}

task_remove_vm1() {
    id=$(resource_id "openstack_compute_instance_v2.aap_vm1") || return 1
    runner_run nova delete $id
}

task_can_ping_vip_vm2() {
    `get_vars`
    flow=$(wait_flow 60 "G.V().Has('Name', '${itf_name_vm2}').Flows().Has('Application', 'ICMPv4').Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
}
