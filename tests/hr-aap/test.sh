#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary neutron

declare -g capture_ids
declare -g itf_name_bastion
declare -g itf_name_vm1
declare -g itf_name_fw1
declare -g itf_name_fw2
declare -g vm1_tracking_id

task_default() {
    runner_sequence setup capture can_ping_vm1 can_ping_google vm1_use_fw1 delete_fw1 vm1_use_fw2 restore_fw1 vm1_use_fw1
    result=${?}
    #runner_sequence teardown
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
}

task_capture() {
    itf_name_bastion=$(port_interface_name "aap_fw_bastion_port") || return 1
    itf_name_vm1=$(port_interface_name "aap_fw_vm1_port") || return 1
    itf_name_fw1=$(port_interface_name "aap_fw_fw1_port_backend") || return 1
    itf_name_fw2=$(port_interface_name "aap_fw_fw2_port_backend") || return 1
    for itf_name in ${itf_name_bastion} ${itf_name_vm1} ${itf_name_fw1} ${itf_name_fw2}
    do
        capture_id=$(capture "G.V().Has('Name', '${itf_name}')" "hr-aap test") || return 1
        capture_ids="${capture_ids} ${capture_id}"
    done
}

task_delete_capture() {
    for capture_id in $capture_ids
    do
        delete_capture $capture_id
    done
}

task_can_ping_vm1() {
    flow=$(wait_flow 30 "G.V().Has('Name', '${itf_name_bastion}').Flows().Has('Application', 'ICMPv4').Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
}

task_can_ping_google() {
    port_ip=$(port_fixed_ip "aap_fw_vm1_port") || return 1
    flow=$(wait_flow 30 "G.V().Has('Name', '${itf_name_vm1}').Flows().Has('Application', 'ICMPv4').Has('Network.A', within('8.8.8.8', '${port_ip}')).Has('Network.B', within('8.8.8.8', '${port_ip}')).Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
}

task_vm1_use_fw1() {
    port_ip=$(port_fixed_ip "aap_fw_vm1_port") || return 1
    flow=$(wait_flow 30 "G.V().Has('Name', '${itf_name_fw1}').Flows().Has('Application', 'ICMPv4').Has('Network.A', within('8.8.8.8', '${port_ip}')).Has('Network.B', within('8.8.8.8', '${port_ip}')).Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
}

task_delete_fw1() {
    fw1_id=$(resource_id "openstack_compute_instance_v2.aap_fw_fw1") || return 1
    runner_run nova delete $fw1_id
}

task_vm1_use_fw2() {
    port_ip=$(port_fixed_ip "aap_fw_vm1_port") || return 1
    flow=$(wait_flow 20 "G.V().Has('Name', '${itf_name_fw2}').Flows().Has('Application', 'ICMPv4').Has('Network.A', within('8.8.8.8', '${port_ip}')).Has('Network.B', within('8.8.8.8', '${port_ip}')).Has('Metric.ABPackets', GT(0)).Has('Metric.BAPackets', GT(0))") || return 1
}

task_restore_fw1() {
    terrapply || return 1
    itf_name_fw1=$(port_interface_name "aap_fw_fw1_port_backend") || return 1
    capture_id=$(capture "G.V().Has('Name', '${itf_name_fw1}')" "hr-aap test") || return 1
    capture_ids="${capture_ids} ${capture_id}"
}
