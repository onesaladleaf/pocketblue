#!/usr/bin/env bash

set -uexo pipefail

loop=$(losetup --find --show --partscan --sector-size 4096 $OUTPUT/disk.raw)
trap "losetup -d $loop" EXIT

export esp_part="${loop}p1"
export root_part="${loop}p2"

[ "$CONF_INSTALL_DTB" = "true" ] && $SCRIPTS/install-dtb.sh
[ "$CONF_BUILD_EROFS" = "true" ] && $SCRIPTS/build-erofs.sh

if [ "$CONF_SPLIT_PARTITIONS" = "true" ]; then
    $SCRIPTS/split-partitions.sh
    trap - EXIT
    losetup -d $loop
    rm $OUTPUT/disk.raw
else
    chmod 666 $OUTPUT/disk.raw
fi
