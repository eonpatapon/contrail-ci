#!/bin/bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary neutron

capture_id=""
port_id=""

task_default() {
	runner_sequence setup capture can_ping_backend
    result=${?}
    runner_sequence teardown 
    return $result
}

task_setup() {
    retry 3 terraform apply || return 1
    port_id=$(resource_id "openstack_networking_port_v2.hr_router_port_bastion") || return 1
}

task_teardown() {
    runner_sequence delete_capture
    retry 3 terraform destroy -force || return 1
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
    both_sides=$(echo $result | jq '.[].Metric | has("ABPackets") and has("BAPackets")')
	if [[ $both_sides == "false" ]] || [[ $both_sides == "" ]]; then
		runner_log_error "Ping doesn't work. No reply from backend."
		return 1
	fi
}
