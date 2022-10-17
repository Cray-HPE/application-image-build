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

        if ! resize2fs "${dev_disk}${dev_partition_nr}"; then
            if ! xfs_growfs ${dev_disk}${dev_partition_nr}; then
                echo >&2 "Neither resize2fs nor xfs_growfs could resize the device. Potential filesystem mismatch on [$dev_disk]."
                lsblk "$dev_disk"
            fi
        fi
    fi
    cd -
}
resize_root
