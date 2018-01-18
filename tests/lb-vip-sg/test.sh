#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary curl
check_binary neutron

task_default() {
    runner_sequence setup wait_backends check_vip apply_sg_vip check_vip_not_responding 
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
    runner_sequence remove_sg_vip destroy
    clean_vars
}

task_wait_backends() {
    runner_parallel wait_backend_0 wait_backend_1
}

task_wait_backend_0() {
    wait_cloudinit lb_vip_sg_backend_0
}

task_wait_backend_1() {
    wait_cloudinit lb_vip_sg_backend_1
}

task_check_vip() {
    fip=$(fip_ip "lb_vip_sg_fip_vip") || return 1
    backend_1=$(curl --connect-timeout 1 $fip 2>/dev/null)
    backend_2=$(curl --connect-timeout 1 $fip 2>/dev/null)
    if [ "${backend_1}" == "lb-vip-sg-backend-0" ]; then
        if [ ! "${backend_2}" == "lb-vip-sg-backend-1" ]; then
            runner_log_error "Backend 1 isn't responding"
            return 1
        fi
    else
        if [ ! "${backend_2}" == "lb-vip-sg-backend-0" ]; then
            runner_log_error "Backend 0 isn't responding"
            return 1
        fi
    fi
    runner_log_success "All backends are responding"
}

task_apply_sg_vip() {
    port_id=$(fip_port_id "lb_vip_sg_fip_vip") || return 1
    sg_id=$(resource_id "openstack_compute_secgroup_v2.lb_vip_sg_secgroup") || return 1
    neutron port-update ${port_id} --security-group ${sg_id}
    # wait a bit for the sg to be propagated
    sleep 3
}

task_check_vip_not_responding() {
    fip=$(fip_ip "lb_vip_sg_fip_vip") || return 1
    curl --connect-timeout 1 ${fip} 2>/dev/null
    if [ $? -eq 0 ]; then
        runner_log_error "VIP is still responding"
        return 1
    fi
    runner_log_success "VIP is not responding"
}

task_remove_sg_vip() {
    port_id=$(fip_port_id "lb_vip_sg_fip_vip") || return 1
    neutron port-update ${port_id} --security-group default
}
