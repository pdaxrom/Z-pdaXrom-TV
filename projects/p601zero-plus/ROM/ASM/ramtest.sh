#!/bin/bash

writefile=$(mktemp)
readfile=$(mktemp)

ram_test() {
    dd if=/dev/urandom of=$writefile bs=1 count=53248 &>/dev/null
    ../bootloader /dev/ttyUSB1 load $writefile 1000

    ../bootloader /dev/ttyUSB1 save $readfile 1000 e000
    cmp -s $writefile $readfile && echo "RAM TEST OKAY" || echo "RAM TEST FAILED"
}

ram_test
ram_test
ram_test
ram_test

rm -f $writefile $readfile
