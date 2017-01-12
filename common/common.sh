#!/usr/bin/env bash

set -e

export CI_COMMON_DIR=$(pwd)/$(dirname $BASH_SOURCE)

check_binary() {
    type -P $1 > /dev/null || (echo "error: $1 is not in your PATH"; exit 1)
}

gremlin() {
    local query=$1
    >&2 runner_log_notice "Sending query : $query"
    local result=$(skydive -c ${CI_COMMON_DIR}/skydive.yml client topology query --gremlin "$1") || return 1
    >&2 runner_log_notice "Query result : $result"
    echo $result
}

capture() {
    local desc=${2:-"CI test"}
    local capture=$(skydive -c ${CI_COMMON_DIR}/skydive.yml client capture create --description "$desc" --gremlin "$1")
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
        skydive -c ${CI_COMMON_DIR}/skydive.yml client capture delete $capture_id || return
        >&2 runner_log_notice "Capture ${capture_id} deleted"
    fi
}

resource_id() {
    local name=$1
    local id=$(cat terraform.tfstate | jq -r ".modules[].resources[\"${name}\"].primary.id")
    if [[ -z $id ]] || [[ $id == "null" ]]; then
		>&2 runner_log_error "Can't find $name id in terraform state"
        return 1
    fi
    echo $id
}

fuzzy_resource_ids() {
    local name=$1
    local matches=$(cat terraform.tfstate | jq -r ".modules[].resources | keys[] | select(contains(\"${name}\"))")
    for match in $matches
    do
        local id=$(resource_id ${match}) || return 1
        echo -n "${id} "
    done
    echo
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

check_binary skydive
check_binary jq
