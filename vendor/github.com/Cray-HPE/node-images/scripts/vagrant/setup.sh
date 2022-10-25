#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# This script ensures vagrant is installed in our buildenvironment.
set -eo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null 2>&1 && pwd )"
if [ -d {$ROOT_DIR} ]; then
    echo >&2 "Can't find setup directory!"
    exit 1
fi

# Setup the `Vagrantfile` that packer will use as a base template.
function setup_template {
    
    local nproc
    
    # Get NPROC from the environment, or find it if it isn't set.
    if [ -z ${NPROC:-} ]; then 
        nproc="$(nproc)"
    else
        nproc=${NPROC}
    fi

    export nproc
    envsubst < ${ROOT_DIR}/vagrant/Vagrantfile.template.rb > ${ROOT_DIR}/vagrant/Vagrantfile

    # Jenkins should hide the password when it dumps this template.
    cat ${ROOT_DIR}/vagrant/Vagrantfile
}

# A default pool needs to be created before we can import images into libvirt.
# vagrant-libvirt does this for us, but since we import images into libvirt prior to invoking
# vagrant-libivrt, we need to do this manually.
function setup_storage_pool {
    local libvirt_uid
    local libvirt_gid
    libvirt_uid="$(id -u libvirt-qemu)"
    libvirt_gid="$(getent group libvirt-qemu | awk -F : '{print $3}')"
    export libvirt_uid
    export libvirt_gid
    envsubst < ${ROOT_DIR}/vagrant/default-pool.template.xml > ${ROOT_DIR}/vagrant/default-pool.xml
    cat ${ROOT_DIR}/vagrant/default-pool.xml 
    sudo virsh pool-create --build ${ROOT_DIR}/vagrant/default-pool.xml
    sudo virsh pool-list
}

if [ -f ${ROOT_DIR}/vagrant/Vagrantfile ]; then
    # just update the file
    setup_template
else
    setup_storage_pool
    setup_template
fi
