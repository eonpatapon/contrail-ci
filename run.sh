#!/bin/bash

set -e

cd $(dirname $0)
CI_TEST_DIR=$(pwd)
declare -a CI_TESTS=(${1:-$(ls $CI_TEST_DIR/tests)})
declare -a CI_TESTS_RESULTS=()
CI_TEST_INDEX=-1
CI_CURRENT_TEST=

echo "Tests to be run : ${CI_TESTS[@]}"

run_test() {
    local test=$1
    echo "Running test $test ..."
    pushd $(dirname $test) > /dev/null
    bash test.sh
    popd > /dev/null
    CI_TESTS_RESULTS=("${CI_TESTS_RESULTS[@]}" "${CI_CURRENT_TEST} PASS")
    next_test
}

next_test() {
    CI_TEST_INDEX=$((CI_TEST_INDEX+1))
    CI_CURRENT_TEST=${CI_TESTS[$CI_TEST_INDEX]}
    if [ ! -z $CI_CURRENT_TEST ]; then
        local test=$CI_TEST_DIR/tests/$CI_CURRENT_TEST/test.sh
        if [[ -x "$test" ]]; then
            run_test $test
        else
            echo "$test doesn't exists or is not executable, skipping..."
            next_test
        fi
    else
        echo -e "\nTest results:"
        for result in "${CI_TESTS_RESULTS[@]}"
        do
            echo $result
        done
        # we are done remove trap before exiting
        trap - EXIT
    fi
}

test_failed() {
    CI_TESTS_RESULTS=("${CI_TESTS_RESULTS[@]}" "${CI_CURRENT_TEST} FAILED")
    next_test
}

trap "test_failed" EXIT

[[ -z $OS_AUTH_URL ]] && echo "You must source Openstack credentials" && exit 1

pushd ${CI_TEST_DIR}/common > /dev/null
    terraform apply
    [[ ! $? -eq 0 ]] && exit 1
popd > /dev/null

next_test
