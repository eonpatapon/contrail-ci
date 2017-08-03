Setup
=====

Install skydive in the path. 
Prebuilt binaires are available at https://github.com/skydive-project/skydive-binaries.

Install terraform 0.8.

Install jq >= 0.3.

Source openstack credentials.

Environments
============

Configuration files for the environment must be placed in the `envs` directory.
This includes terraform tfvars and skydive configuration.

If the region name is "foo", create envs/foo-skydive.yml and envs/foo.tfvars files.

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

Devstack
========

In local.conf:

    enable_plugin skydive https://github.com/skydive-project/skydive.git
    enable_plugin contrail-ci https://github.com/eonpatapon/contrail-ci.git

    SKYDIVE_ANALYZER_LISTEN=0.0.0.0:8282
    SKYDIVE_ANALYZERS=${HOST_IP}:8282
    SKYDIVE_AGENT_LISTEN=${HOST_IP}:8281
    SKYDIVE_AGENT_ETCD=${HOST_IP}:2379
    SKYDIVE_AGENT_PROBES="netns netlink opencontrail neutron"
    SKYDIVE_FLOWS_STORAGE="none"
    SKYDIVE_GRAPH_STORAGE="memory"
    SKYDIVE_KEYSTONE_API_VERSION="v2.0"

Once devstack setup is complete, go to /opt/stack/contrail-ci:

    source setup.sh
    ./run.sh sg

[1] https://github.com/stylemistake/bash-task-runner
