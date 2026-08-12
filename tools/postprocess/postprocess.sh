#!/usr/bin/env bash

set -uexo pipefail

kpartx -va $OUTPUT/disk.raw
trap "kpartx -dv $OUTPUT/disk.raw" EXIT

mapfile -t part < <(kpartx -l "$OUTPUT/disk.raw" | awk '{print "/dev/mapper/" $1}')
export esp_part="${part[0]}"
export root_part="${part[1]}"

[ "$CONF_INSTALL_DTB" = "true" ] && $SCRIPTS/install-dtb.sh
[ "$CONF_BUILD_EROFS" = "true" ] && $SCRIPTS/build-erofs.sh

if [ "$CONF_SPLIT_PARTITIONS" = "true" ]; then
    $SCRIPTS/split-partitions.sh
    trap - EXIT
    kpartx -dv $OUTPUT/disk.raw
    rm $OUTPUT/disk.raw
else
    chmod 666 $OUTPUT/disk.raw
fi
