#!/bin/bash

basedir=$(dirname "$0")
imagedir=${1:-/tmp/images}
imagename=${2:-image.qcow2}

args="--config ${basedir}/conf --image=${imagedir}/${imagename}"
[[ -f ${basedir}/customize.sh ]] && args="$args --customize=${basedir}/customize.sh"

sudo mkdir -p ${imagedir}
time sudo vmdebootstrap $args
ls -lh ${imagedir}
md5sum ${imagedir}/${imagename}
