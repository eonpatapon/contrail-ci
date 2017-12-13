#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary curl
check_binary neutron

task_default() {
    runner_sequence setup wait_backends start_traffic disable_vm1 stop_traffic check_traffic
    result=${?}
    runner_sequence enable_vm1 teardown
    return $result
}

task_setup() {
    clean_vars
    terrapply || return 1
}

task_wait_backends() {
    runner_parallel wait_backend_0 wait_backend_1
}

task_wait_backend_0() {
    wait_cloudinit lb_hm_backend.0
}

task_wait_backend_1() {
    wait_cloudinit lb_hm_backend.1
}

task_destroy() {
    terradestroy || return 1
}

task_teardown() {
    runner_parallel destroy
    clean_vars
}

gen_trafic() {
    `get_vars`
    while ${generate}
    do
        `get_vars`
        curl --connect-timeout 0.5 ${1} >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            success=$((success+1))
        else
            errors=$((errors))
        fi
        save_vars success errors
    done
}

task_start_traffic() {
    fip=$(fip_ip "lb_hm_fip_vip") || return 1
    success=0
    errors=0
    generate=true
    save_vars generate success errors
    gen_trafic ${fip} &
    sleep 2
}

task_disable_vm1() {
    port_id=$(resource_id "openstack_networking_port_v2.lb_hm_port.0") || return 1
    runner_run neutron port-update --security-group lb_hm_secgroup_no_http ${port_id}
}

task_enable_vm1() {
    port_id=$(resource_id "openstack_networking_port_v2.lb_hm_port.0") || return 1
    runner_run neutron port-update --security-group lb_hm_secgroup ${port_id}
}

task_stop_traffic() {
    generate=false
    save_vars generate
    sleep 5
}

task_check_traffic() {
    `get_vars`
    if [ $errors -gt 0 ]; then
        runner_log_error "$errors requests failed ($success ok)"
        return 1
    fi
    runner_log_success "$errors requests failed ($success ok)"
}
