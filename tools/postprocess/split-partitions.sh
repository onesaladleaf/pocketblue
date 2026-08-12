#!/usr/bin/env bash

set -uexo pipefail

mkdir -p $OUTPUT/images

dd if=$esp_part of=$OUTPUT/images/fedora_esp.raw bs=1M
dd if=$root_part of=$OUTPUT/images/fedora_rootfs.raw bs=1M

sync

# pad the last block to 4096 bytes, fastboot needs this
if (( $(stat -c%s "$OUTPUT/images/fedora_rootfs.raw") % 4096 != 0 )); then
    dd if=/dev/zero bs=1 count=512 | tee -a $OUTPUT/images/fedora_rootfs.raw
fi

chmod 666 $OUTPUT/images/*
