#!/bin/bash

dd if=/dev/mmcblk0 of=/tmp/bsec.bin bs=512 count=1
cat /tmp/bsec.bin BOOTSECP.CMD >/dev/mmcblk0
