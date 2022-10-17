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
# This script ensures vagrant-libvirt is installed in a Debian/Ubuntu environment.
set -eo pipefail
function setup_libvirt {
    sudo apt update
    while ps aux | grep apt | grep -v grep; do echo 'waiting for apt to exit' ; sleep 1; done
    echo 'Setting up vagrant and its dependencies ... '
    sudo apt install -y \
        bridge-utils \
        ebtables \
        libguestfs-tools \
        libvirt-clients \
        libvirt-daemon \
        libvirt-daemon-system \
        libvirt-dev \
        libxml2-dev \
        libxslt-dev \
        ruby-dev \
        ruby-libvirt \
        vagrant \
        vagrant-libvirt \
        virtinst \
        zlib1g-dev
    if ! sudo groups `whoami` | grep -qoE 'kvm' ; then
        echo "Adding group 'kvm' to $(whoami) ... "
        sudo usermod -aG kvm `whoami`
    fi
    if ! sudo groups `whoami` | grep -qoE 'libvirt' ; then
        echo "Adding group 'libvirt' to $(whoami) ... "
        sudo usermod -aG libvirt `whoami`
    fi
    if ! vagrant plugin list | grep -q libvirt; then
        echo "Installing vagrant-libvirt for $(whoami)"
        vagrant plugin install vagrant-libvirt
    fi
    echo 'Done.'
}

setup_libvirt
