Setup
=====

Install skydive in the path. 
Prebuilt binaires are available at https://github.com/skydive-project/skydive-binaries.

Install terraform 0.8.

Install jq >= 0.3.

Source openstack credentials for lab2.

Environments
============

Configuration files for the environment must be placed in the `envs` directory.
This includes terraform tfvars and skydive configuration.

For now, skydive is only available on lab2, so only lab2 configuration is provided.

Tests
=====

Each test consist of a single `test.sh` script. The script must use the `bash-task-runner`[1]
library present in the common directory.

Usually each test will boot an infrastructure with terraform, run some captures with skydive
and validate that the traffic captured is expected. Then the infrastructure is destroyed.

To list all available tests, simply run:

    ls tests

Usage
=====

Run all tests:

    ./run.sh

Run a specific test:

    ./run.sh sg

or

    cd tests/sg/
    ./test.sh

[1] https://github.com/stylemistake/bash-task-runner
