#!/usr/bin/env bash

set -e

SCRIPT=$(readlink -f $0)
BASEDIR=$(dirname "${SCRIPT}")

source ${BASEDIR}/common/common.sh
source ${BASEDIR}/common/runner.sh

runner_default_task="all"

tests=""
declare -a disabled=(`ls ${BASEDIR}/tests/*/disabled | sed 's!.*tests/\(.*\)/disabled!\1!'`)

# generate list of tests
for test in `ls ${BASEDIR}/tests`
do
    if [[ ! " ${disabled[@]} " =~ " ${test} " ]]; then
        tests="${tests} ${test}"
    fi
done

run_test() {
    local test=$1
    runner_log_notice "Running $test test..."
    cd ${BASEDIR}/tests/${test} && bash test.sh
}

make_tests_funcs() {
    for test in ${tests}
    do
        func="task_${test}() { run_test ${test}; }"
        eval ${func}
    done
}
make_tests_funcs

task_list() {
    runner_log_success ${tests}
}

task_all() {
    runner_sequence ${tests}
}

task_all_parallel() {
    runner_parallel ${tests}
}
