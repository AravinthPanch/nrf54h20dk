# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Aravinth Panch
# Author: Aravinth Panch <ara@aracreate.group>
# Description: nRF54H20 DK: Zephyr application build entry (find_package Zephyr + sources)

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(nrf54h20dk)

target_sources(app PRIVATE main.c)
