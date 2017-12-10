#!/bin/bash

export LD_LIBRARY_PATH=/home/vpe/MSPFlasher_1.3.16
/home/vpe/MSPFlasher_1.3.16/MSP430Flasher -w $1 -v -g -e NO_ERASE
# -z [VCC]

