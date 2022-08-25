#!/usr/bin/env bash

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

echo "Initializing directories and resources"
mkdir -pv /srv/cray
cp -prv /tmp/files/* /srv/cray/ || true
rm -rf /tmp/files
