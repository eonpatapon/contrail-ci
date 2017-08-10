#!/usr/bin/env bash

set -e

source ../../common/common.sh
source ../../common/runner.sh

check_binary neutron

declare -g itf_name
declare -g tracking_id

# User account on instances
USER=cloud
# Time to wait after starting the traffic to get the flows
WAIT=12
# Treshold for the delta
TRESHOLD=2
# Description of the capture
DESC="LBaaS health-monitor CI test"
# Files to share values.
CAPTURE_FILE="/tmp/capture_ids"
FLOW_BASTION_FILE="/tmp/flow_bastion"
FLOW_BACKEND_0_FILE="/tmp/flow_backend_0"
FLOW_BACKEND_1_FILE="/tmp/flow_backend_1"
REPORT_FILE="/tmp/report"

########
# Task #
########

task_default() {
    runner_sequence setup wait_cloudinit check_backend_from_bastion capture start_traffic wait get_flows compare_packet stop_one_backend wait get_flows compare_packet stop_traffic delete_capture destroy display_report #remove_sg get_flow compare delete_capture
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
    rm $CAPTURE_FILE 2>/dev/null
    rm /tmp/flow_* 2>/dev/null
}

task_capture_and_compare(){
    runner_sequence capture get_flows compare_packet delete_capture
}

task_capture() {
    if [ -f $CAPTURE_FILE  ]; then
      rm $CAPTURE_FILE
    fi

    runner_parallel capture_bastion capture_backend_0 capture_backend_1
}

task_get_flows() {
    runner_parallel get_flow_bastion get_flow_backend_0 get_flow_backend_1
}

task_delete_capture() {
    runner_parallel delete_capture_bastion delete_capture_backend_0 delete_capture_backend_1
    rm $CAPTURE_FILE
}

task_stop_one_backend() {
    runner_log_notice  "Stop one backend"
    terrapply -target=openstack_compute_secgroup_v2.lb_secgroup_backend_0 remove-sg-rule || return 1
}

task_wait_cloudinit() {
    sleep 30
}

task_wait() {
    sleep $WAIT
}

task_check_api() {
    LB_MONITOR_ID=$(cat terraform.tfstate | jq '.modules[0].resources["openstack_lb_monitor_v1.lb_monitor"].primary.id')
    state=$(neutron lb-healthmonitor-show  $LB_MONITOR_ID | grep status | awk '{print $4}')
    [[ $state == "ACTIVE" ]] || return 1
}

###########
# Subtask #
###########

# Capture
task_capture_bastion() {
    capture_id_bastion=$(start_capture_on_port lb_port_bastion)
    echo "capture_id_bastion: " $capture_id_bastion >> $CAPTURE_FILE
}

task_capture_backend_0() {
    capture_id_backend_0=$(start_capture_on_port lb_port_backend_0)
    echo "capture_id_backend_0: " $capture_id_backend_0 >> $CAPTURE_FILE
}

task_capture_backend_1() {
    capture_id_backend_1=$(start_capture_on_port lb_port_backend_1)
    echo "capture_id_backend_1: " $capture_id_backend_1 >> $CAPTURE_FILE
}

# Get Flow
task_get_flow_bastion() {
    flow_bastion=$(get_flow_on_port lb_port_bastion)
    echo $flow_bastion > $FLOW_BASTION_FILE
}

task_get_flow_backend_0() {
    flow_backend_0=$(get_flow_on_port lb_port_backend_0)
    echo $flow_backend_0 > $FLOW_BACKEND_0_FILE
}

task_get_flow_backend_1() {
    flow_backend_1=$(get_flow_on_port lb_port_backend_1)
    echo $flow_backend_1 > $FLOW_BACKEND_1_FILE
}

# Delete Capture
task_delete_capture_bastion() {
    delete_capture $capture_id_bastion
    delete_capture $(cat $CAPTURE_FILE | grep bastion | sed -e 's#.*: \(\)#\1#')
}

task_delete_capture_backend_0() {
    delete_capture $capture_id_backend_0
    delete_capture $(cat $CAPTURE_FILE | grep backend_0 | sed -e 's#.*: \(\)#\1#')
}

task_delete_capture_backend_1() {
    delete_capture $capture_id_backend_1
    delete_capture $(cat $CAPTURE_FILE | grep backend_1 | sed -e 's#.*: \(\)#\1#')
}


task_check_backend_from_bastion() {
    BASTION_IP=$(cat terraform.tfstate | jq '.modules[0].resources["openstack_networking_floatingip_v2.lb_fip_bastion"].primary.attributes.address' | tr -d '"')
    cmd="/tmp/check_backend.sh"
    end=-1
    while [[ $end != 0 ]]; do
        ssh-exec $BASTION_IP $cmd
        end=$?
    done
    return $end
}

task_start_traffic() {
    BASTION_IP=$(cat terraform.tfstate | jq '.modules[0].resources["openstack_networking_floatingip_v2.lb_fip_bastion"].primary.attributes.address' | tr -d '"')
    cmd="tmux send-keys -t ci-test:0 /tmp/loop-curl.sh C-m"
    ssh-exec $BASTION_IP $cmd
    return $?
}

task_stop_traffic() {
    BASTION_IP=$(cat terraform.tfstate | jq '.modules[0].resources["openstack_networking_floatingip_v2.lb_fip_bastion"].primary.attributes.address' | tr -d '"')
    cmd="tmux send-keys -t ci-test:0 C-c"
    ssh-exec $BASTION_IP $cmd
    return $?
}

#############
# Functions #
#############

ssh-exec() {
    user=$USER
    ip=$1
    shift
    cmd=$@
    key="$HOME/git/contrail-ci/common/test-key"
    ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${user}@${ip}" "${cmd}"
    return $?
}

start_capture_on_port() {
    itf_name=$(port_interface_name "$1") || return 1
    capture_id=$(capture "G.V().Has('Name', '${itf_name}')" "$DESC") || return 1
    echo $capture_id
}

get_flow_on_port() {
    itf_name=$(port_interface_name "$1") || return 1
    flow=$(wait_flow 30 "G.V().Has('Name', '${itf_name}').Flows().Has('Application', 'TCP', 'Transport', '80')") || return 1
    echo $flow
}

task_compare_packet() {
    nb_packet_bastion_AB=$(cat $FLOW_BASTION_FILE | jq -r '. | length') || return 1
    nb_packet_backend_0_AB=$(cat $FLOW_BACKEND_0_FILE | jq -r '. | length') || return 1
    nb_packet_backend_1_AB=$(cat $FLOW_BACKEND_1_FILE | jq -r '. | length') || return 1

    printf "Report\n======\n" >> $REPORT_FILE
    printf "Nb Flows bastion = $nb_packet_bastion_AB \n" >> $REPORT_FILE
    printf "Nb Flows backend_0 = $nb_packet_backend_0_AB \n" >> $REPORT_FILE
    printf "Nb Flows backedn_1 = $nb_packet_backend_1_AB \n" >> $REPORT_FILE

    nb_packet_backend_AB=$(( $nb_packet_backend_0_AB + $nb_packet_backend_1_AB ))
    delta=$(( $nb_packet_bastion_AB - nb_packet_backend_AB ))
    delta=$([ $delta -lt 0 ] && echo $((-$delta)) || echo $delta)

    printf "Delta = $delta \n" >> $REPORT_FILE
    if [[ $delta -lt $TRESHOLD ]]; then
      printf "PASSED\n" >> $REPORT_FILE
    else
      printf "FAILED\n" >> $REPORT_FILE
    fi
    printf "=====================================\n" >>$REPORT_FILE
}

task_display_report() {
    cat $REPORT_FILE
    rm $REPORT_FILE
}
