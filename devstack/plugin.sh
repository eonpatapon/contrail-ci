#!/bin/bash

function install_contrail-ci {
    wget https://releases.hashicorp.com/terraform/0.8.8/terraform_0.8.8_linux_amd64.zip
    unzip terraform_0.8.8_linux_amd64.zip
    sudo mv terraform /usr/local/bin/ 
}

function configure_contrail-ci {
    wget https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img 
    IMAGE_ID=$(glance image-create --name "Ubuntu 14.04" --min-disk 20 --container-format bare --file trusty-server-cloudimg-amd64-disk1.img --disk-format qcow2 --visibility public | grep ' id ' | get_field 2)

    cat > $DEST/contrail-ci/envs/${REGION_NAME}.tfvars <<- EOF
public_pool_id = "${EXT_NET_ID}"
image_id = "${IMAGE_ID}"
flavor_id = "2"
region = "${REGION_NAME}"
EOF

    cat > $DEST/contrail-ci/envs/${REGION_NAME}-skydive.yml <<- EOF
analyzers: ${SKYDIVE_ANALYZERS}
EOF

    cat > $DEST/contrail-ci/setup.sh <<- EOF
export SKYDIVE_USERNAME=admin
export SKYDIVE_PASSWORD=${ADMIN_PASSWORD}
export PATH=/opt/stack/go/bin/:${PATH}
EOF

}

if [[ "$1" == "stack" ]]; then
    if [[ "$2" == "install" ]]; then
        install_contrail-ci
    elif [[ "$2" == "extra" ]]; then
        configure_contrail-ci
    fi
fi
