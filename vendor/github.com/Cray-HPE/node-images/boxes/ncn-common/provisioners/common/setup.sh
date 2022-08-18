#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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
set -ex

function resize_root {
    local dev_disk
    local dev_partition_nr

    # Find device and partition of /
    cd /
    df . | tail -n 1 | tr -s " " | cut -d " " -f 1 | sed -E -e 's/^([^0-9]+)([0-9]+)$/\1 \2/' |
    if read dev_disk dev_partition_nr && [ -n "$dev_partition_nr" ]; then
        echo "Expanding $dev_disk partition $dev_partition_nr";
        sgdisk --move-second-header
        sgdisk --delete=${dev_partition_nr} "$dev_disk"
        sgdisk --new=${dev_partition_nr}:0:0 --typecode=0:8e00 ${dev_disk}
        partprobe "$dev_disk"

        if ! resize2fs "$dev_disk"; then
            if ! xfs_growfs ${dev_disk}${dev_partition_nr}; then
                echo >&2 "Neither resize2fs nor xfs_growfs could resize the device. Potential filesystem mismatch on [$dev_disk]."
                lsblk "$dev_disk"
            fi
        fi
    fi
    cd -
}
resize_root

# Install generic Python tools; ensures both the default python and any other installed python system versions have 
# basic buildtools.
# NOTE: /usr/bin/python3 should point to the Python 3 version installed by python3.rpm, this is set in metal-provision.
function setup_python {
    local pythons

    local        pip_ver='21.3.1'
    local      build_ver='0.8.0'
    local setuptools_ver='59.6.0'
    local      wheel_ver='0.37.1'
    local virtualenv_ver='20.15.1'

    readarray -t pythons < <(find /usr/bin/ -regex '.*python3\.[0-9]+')
    printf 'Discovered [%s] python binaries: %s\n' "${#pythons[@]}" "${pythons[*]}"
    for python in "${pythons[@]}"; do
        $python -m pip install -U "pip==$pip_ver" || $python -m ensurepip
        $python -m pip install -U \
            "build==$build_ver" \
            "setuptools==$setuptools_ver" \
            "virtualenv==$virtualenv_ver" \
            "wheel==$wheel_ver" 
    done
    echo 'Removing /usr/local/bin/pip3 to ensure /usr/bin/pip3 is preferred in the $PATH'
    rm -f /usr/local/bin/pip3
}
setup_python

function install_ansible {
    local ansible_version=${ANSIBLE_VERSION:-2.11.10}
    local python_version=${PYTHON_VERSION:-/usr/bin/python3.9}
    local requirements=( boto3 netaddr )
    
    echo "Installing CSM Ansible $ansible_version"
    mkdir -pv /etc/ansible
    $python_version -m venv /etc/ansible/csm_ansible
    . /etc/ansible/csm_ansible/bin/activate
    python3 -m pip install ansible-core==$ansible_version ansible
    
    echo "Installing requirements: ${requirements[@]}"
    for requirement in ${requirements[@]}; do
        python3 -m pip install -U $requirement
    done
    deactivate
}
install_ansible

mkdir -pv /opt/cray/csm/scripts/csm_rbd_tool
virtualenv --system-site-packages /opt/cray/csm/scripts/csm_rbd_tool -p 3.6
.  /opt/cray/csm/scripts/csm_rbd_tool/bin/activate
pip3 install fabric psutil
deactivate
