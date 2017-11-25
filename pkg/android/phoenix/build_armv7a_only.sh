#!/bin/bash
#########################################################################
# File Name: build_armv7a_only.sh
# Author: rany
# mail: hyt@t-chip.com.cn
# Created Time: 2017-11-10 18:04:16
#########################################################################

export TARGET_ABIS=armeabi-v7a
ant $1
