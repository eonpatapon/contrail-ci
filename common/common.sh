#!/usr/bin/env bash

set -e

[[ -z ${OS_REGION_NAME} ]] && echo "OS_REGION_NAME is empty" && return 1

export CI_COMMON_DIR=$(pwd)/$(dirname $BASH_SOURCE)
export CI_ENVS_DIR=${CI_COMMON_DIR}/../envs
export CI_SKYDIVE_CONF=${CI_ENVS_DIR}/${OS_REGION_NAME}-skydive.yml
export CI_TERRAFORM_VARS=${CI_ENVS_DIR}/${OS_REGION_NAME}.tfvars
export CI_TERRAFORM_STATE=${OS_REGION_NAME}/terraform.tfstate

save_vars() {
    declare -pg $@ >> ${OS_REGION_NAME}/environ
}

get_vars() {
    [ -f ${OS_REGION_NAME}/environ ] && echo eval "source ${OS_REGION_NAME}/environ"
}

clean_vars() {
    rm -f ${OS_REGION_NAME}/environ
}

check_binary() {
    type -P $1 > /dev/null || (echo "error: $1 is not in your PATH"; exit 1)
}

random_string() {
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
}

gen_key() {
    mkdir -p ${OS_REGION_NAME}
    local key_path=${OS_REGION_NAME}/$(random_string)
    ssh-keygen -N "" -q -f ${key_path} && echo ${key_path} || return 1
}

terrapply() {
    `get_vars`
    # Avoid creating multiple keys when a test is running multiple times this function
    if [ -z ${key_path} ]; then
        key_path=$(gen_key) || return 1
        key_pair=$(basename ${key_path} | cut -f1 -d'.')
        save_vars key_path
    fi
    retry 3 terraform apply -var key_path=${key_path}.pub -var key_pair=${key_pair} -var-file=${CI_TERRAFORM_VARS} -state ${CI_TERRAFORM_STATE} $@ || return 1
}

terradestroy() {
    `get_vars`
    retry 3 terraform destroy -var key_path=${key_path}.pub -var key_pair=${key_pair} -var-file=${CI_TERRAFORM_VARS} -state ${CI_TERRAFORM_STATE} -force
    rm -f ${key_path} ${key_path}.pub
    if [ ! $? -eq 0 ]; then
        return 1
    fi
}

gremlin() {
    local query=$1
    >&2 runner_log_notice "Sending query : $query"
    result=$(skydive -c ${CI_SKYDIVE_CONF} client query "$1") || return 1
    >&2 runner_log_notice "Query result : $result"
    echo $result
}

capture() {
    local desc=${2:-"CI test"}
    local capture=$(skydive -c ${CI_SKYDIVE_CONF} client capture create --description "$desc ($USER)" --type "pcap" --gremlin "$1")
    >&2 runner_log_notice "Capture result : $capture"
    local capture_id=$(echo $capture | jq -r '.UUID')
    if [[ -z $capture_id ]]; then
		>&2 runner_log_error "Capture wasn't properly started"
        return 1
    fi
    echo $capture_id
}

delete_capture() {
    local capture_id=$1
    if [ ! -z $capture_id ]; then
        skydive -c ${CI_SKYDIVE_CONF} client capture delete $capture_id || return
        >&2 runner_log_notice "Capture ${capture_id} deleted"
    fi
}

resource_id() {
    local name=$1
    local id=$(cat ${CI_TERRAFORM_STATE} | jq -r ".modules[].resources[\"${name}\"].primary.id")
    if [[ -z $id ]] || [[ $id == "null" ]]; then
		>&2 runner_log_error "Can't find $name id in terraform state"
        return 1
    fi
    echo $id
}

vm_id() {
    local name=$1
    id=$(resource_id openstack_compute_instance_v2.${name}) || return 1
    echo $id
}

fuzzy_resource_ids() {
    local name=$1
    local matches=$(cat ${CI_TERRAFORM_STATE} | jq -r ".modules[].resources | keys[] | select(contains(\"${name}\"))")
    for match in $matches
    do
        id=$(resource_id ${match}) || return 1
        echo -n "${id} "
    done
    echo
}

port_interface_name() {
    local name=$1
    port_id=$(resource_id "openstack_networking_port_v2.${name}") || return 1
    echo tap${port_id:0:11}
}

port_fixed_ip() {
    local name=$1
    local fixed_ip=$(cat ${CI_TERRAFORM_STATE} | jq -r ".modules[].resources[\"openstack_networking_port_v2.${name}\"].primary.attributes[\"fixed_ip.0.ip_address\"]")
    if [[ -z $fixed_ip ]] || [[ $fixed_ip == "null" ]]; then
        >&2 runner_log_error "Can't find $name IP in terraform state"
        return 1
    fi
    echo $fixed_ip
}

fip_ip() {
    local name=$1
    local ip=$(cat ${CI_TERRAFORM_STATE} | jq -r ".modules[].resources[\"openstack_networking_floatingip_v2.${name}\"].primary.attributes.address")
    if [[ -z $ip ]] || [[ $ip == "null" ]]; then
        >&2 runner_log_error "Can't find $name IP in terraform state"
        return 1
    fi
    echo $ip
}

fip_port_id() {
    local name=$1
    local port_id=$(cat ${CI_TERRAFORM_STATE} | jq -r ".modules[].resources[\"openstack_networking_floatingip_v2.${name}\"].primary.attributes.port_id")
    if [[ -z $port_id ]] || [[ $port_id == "null" ]]; then
        >&2 runner_log_error "Can't find $name port_id in terraform state"
        return 1
    fi
    echo $port_id
}

# Wait for skydive flow.
# $1 - number of seconds to wait
# $2 - the gremlin query
# Returns flow
wait_flow() {
    local -r -i max_attempts=$1
    local -r query=$2
    >&2 runner_log_notice "Polling for flow ${query} during ${max_attempts}s..."
    for attempt_num in $(seq $max_attempts)
	do
        local -i nb_flows=$(2>/dev/null gremlin "${query}" | jq -r '. | length')
		if (( attempt_num == max_attempts )); then
            >&2 runner_log_error "No flow found in ${max_attempts}s, aborting..."
            return 1
        elif (( nb_flows == 0 )); then
            >&2 runner_log_notice "No flow found in ${attempt_num}s"
            sleep 1
        else
            >&2 runner_log_notice "Flow found"
            break
        fi
	done
    result=$(gremlin "${query}") || return 1
    echo $result
}

# Retries a command on failure.
# $1 - the max number of attempts
# $2... - the command to run
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=1

    until $cmd
    do
        if (( attempt_num == max_attempts ))
        then
            >&2 runner_log_error "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            >&2 runner_log_warning "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}

wait_cloudinit() {
    local vm_name=$1
    vm_id=$(vm_id ${vm_name}) || return 1
    local -r -i max_attempts=30
    >&2 runner_log_notice "Waiting for VM ${vm_name} to be ready..."
    for attempt_num in $(seq $max_attempts)
    do
        nova console-log --length 10 ${vm_id} | grep -q 'Instance booted'
        if [ $? -eq 0 ]; then
            >&2 runner_log_notice "VM ${vm_name} is ready"
            break
        else
            >&2 runner_log_notice "VM ${vm_name} is not ready..."
        fi
    done
}

check_binary skydive
check_binary jq
check_binary terraform
