Setup
=====

Install skydive in the path. 
Prebuilt binaires are available at https://github.com/skydive-project/skydive-binaries.

Source openstack credentials for lab2.

Usage
=====

Run all tests:

    ./run.sh

Run a specific test:

    ./run.sh sg

or

    # must be done only once
    cd common/
    terraform apply
     
    cd tests/sg/
    ./test.sh
