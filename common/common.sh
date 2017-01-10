#!/bin/bash

set -e

export CI_COMMON_DIR=$(pwd)/$(dirname $BASH_SOURCE)

check_binary() {
    which $1 > /dev/null
}

gremlin() {
    local query=$1
    local result=$(skydive -c ${CI_COMMON_DIR}/skydive.yml client topology query --gremlin "$1") || return 1
    >&2 runner_log_notice $result
    echo $result
}

capture() {
    local desc=${2:-"CI test"}
    local capture_id=$(skydive -c ${CI_COMMON_DIR}/skydive.yml client capture create --description "$desc" --gremlin "$1" | jq -r '.UUID')
    if [[ -z $capture_id ]]; then
		>&2 runner_log_error "Capture wasn't properly started"
        return 1
    fi
    echo $capture_id
}

delete_capture() {
    local capture_id=$1
    [ ! -z $capture_id ] && skydive -c ${CI_COMMON_DIR}/skydive.yml client capture delete $capture_id || return
}

resource_id() {
    local name=$1
    local id=$(cat terraform.tfstate | jq -r ".modules[].resources.\"${name}\".primary.id")
    if [[ -z $id ]] || [[ $id == "null" ]]; then
		>&2 runner_log_error "Can't find $name id in terraform state"
        return 1
    fi
    echo $id
}

check_binary skydive
