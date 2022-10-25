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
set -euo pipefail

SLES_VERSION=$(grep -i VERSION= /etc/os-release | tr -d '"' | cut -d '-' -f2)
echo "purging $SLES_VERSION services repos"
for repo in $(zypper ls | awk '{print $3}' | grep -E $SLES_VERSION); do
    zypper rs $repo
done

echo "remove credential files"
rm -vf /root/.zypp/credentials.cat
rm -vf /etc/zypp/credentials.cat
rm -vf /etc/zypp/credentials.d/*

echo "removing SUSEConnect entries from /etc/containers/mounts.conf"
# remove all lines that start with '/', leaving the informational comment header intact
test -f /etc/containers/mounts.conf && sed -i '/^\//d' /etc/containers/mounts.conf
