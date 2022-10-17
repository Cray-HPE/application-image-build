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
set -euo pipefail

# Ensure that only the desired kernel version may be installed.
# Clean up old kernels, if any. We should only ship with a single kernel.
# Lock the kernel to prevent inadvertent updates.
function cleanup_kernel {
    local current_kernel

    # Grab this from csm-rpms, the running kernel may not match the kernel we installed and want until the image is rebooted.
    # This ensures we lock to what we want installed.
    current_kernel="$(grep kernel-default /srv/cray/csm-rpms/packages/node-image-common/base.packages | awk -F '=' '{print $NF}')"
    if [ -z "$current_kernel" ]; then
        echo >&2 'Failed to resolve the desired kernel version.'
        exit 1
    fi

    echo "Purging old kernels ... "
    zypper removelock kernel-default || echo 'No lock to remove'
    sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${current_kernel}"'/g' /etc/zypp/zypp.conf
    zypper --non-interactive purge-kernels --details

    echo "Locking the kernel to ${current_kernel}"
    zypper addlock kernel-default && zypper locks
        
    echo "Listing currently installed kernel-default RPM:"
    rpm -q kernel-default
}

function cleanup_zypper {
    echo "removing our autoyast cache to ensure no lingering sensitive content remains there from install"
    rm -rf /var/adm/autoinstall/cache
    zypper clean --all
}

function cleanup_network {
    echo "clean up network interface persistence"
    rm -f /etc/udev/rules.d/*-net.rules

    echo "purging wicked files"
    rm -f /var/lib/wicked/*.xml  
}

function cleanup_id {
    echo "blank netplan machine-id (DUID) so machines get unique ID generated on boot"
    truncate -s 0 /etc/machine-id
    
    echo "force a new random seed to be generated"
    rm -f /var/lib/systemd/random-seed
}

function cleanup_history {
    echo "truncate any logs that have built up during the install"
    find /var/log/ -type f -name "*.log.*" -exec rm -rf {} \;
    find /var/log -type f -exec truncate --size=0 {} \;

    echo "clear the history so our install isn't there"
    rm -f /root/.wget-hsts
    history -c
    export HISTSIZE=0
}

function cleanup_tmp {
    echo "remove the contents of /tmp and /var/tmp"
    rm -rf /tmp/* /var/tmp/*
}

cleanup_kernel
cleanup_zypper
cleanup_network
cleanup_id
cleanup_history
cleanup_tmp
