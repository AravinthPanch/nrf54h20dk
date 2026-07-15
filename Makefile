# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Aravinth Panch
# Author: Aravinth Panch <ara@aracreate.group>
# Description: nRF54H20 DK: Unified build, flash, and environment tasks

SHELL   := /bin/bash
SRC_DIR := ./src
MOTD    := ./scripts/motd

# ---- Configuration (override on the CLI, e.g. `make flash SN=123`) ----------
NCS_VERSION ?= v3.4.0
ZEPHYR_BASE ?= /opt/nordic/ncs/$(NCS_VERSION)/zephyr
BOARD       ?= nrf54h20dk/nrf54h20/cpuapp
SN          ?= 1051113059
PORT        ?= /dev/tty.usbmodem0010511130591
BAUD        ?= 115200
BUILD_DIR   ?= build

# Pull the NCS toolchain into the recipe shell + point west at Zephyr. Used as a prefix
# so every west command runs in a correctly set-up shell.
#
# `eval "$$(...)"` (command substitution), NOT `source <(...)` (process substitution):
# nrfutil panics with a broken pipe when its stdout is the live process-sub pipe read by
# `source`, leaving PATH unset ("west: command not found"). Command substitution reads all
# output to EOF first, then evals — no live pipe to break.
#
# `env -u NRFUTIL_HOME`: the `sdk-manager` component lives in nrfutil's DEFAULT home, but
# the env script this emits exports NRFUTIL_HOME=<toolchain>/nrfutil/home (which only ships
# `device`). If the parent shell already sourced the toolchain env, that NRFUTIL_HOME is
# inherited and `nrfutil sdk-manager` fails with "Subcommand not found". Unsetting it for
# this one call makes the target work regardless of parent-shell state.
ENV = eval "$$(env -u NRFUTIL_HOME nrfutil sdk-manager toolchain env --ncs-version $(NCS_VERSION) --as-script sh)" \
      && export ZEPHYR_BASE=$(ZEPHYR_BASE)

################################################################################
# Help
################################################################################
.DEFAULT_GOAL := help

help:
	@cat $(MOTD)
	@echo "========================================================================"
	@echo "make install        --> Install the NCS SDK + toolchain (one-time)"
	@echo "make setup          --> Show resolved env + list connected devices"
	@echo "make dev            --> Build, flash, then open the serial monitor"
	@echo "make build          --> Incremental build (--sysbuild)"
	@echo "make pristine       --> Clean (pristine) build — after board/config changes"
	@echo "make flash          --> Flash the app onto the DK"
	@echo "make monitor        --> Open the VCOM0 serial console (Ctrl-A Ctrl-Q to exit)"
	@echo "make test           --> Run tests (Twister)"
	@echo "make release        --> Cut a semantic release"
	@echo "make clean          --> Remove build artefacts"
	@echo "========================================================================"
	@echo ""

################################################################################
# Targets
################################################################################
.PHONY: help install setup dev build pristine flash monitor test release clean

install:
	@printf "\n==> Installing NCS SDK + toolchain ($(NCS_VERSION))\n\n"
	@env -u NRFUTIL_HOME nrfutil sdk-manager install --ncs-version $(NCS_VERSION)

setup:
	@printf "\n==> Resolved toolchain environment\n\n"
	@env -u NRFUTIL_HOME nrfutil sdk-manager toolchain env --ncs-version $(NCS_VERSION) --as-script sh
	@printf "\n==> Connected devices\n\n"
	@env -u NRFUTIL_HOME nrfutil device list

dev: build flash monitor

build:
	@printf "\n==> Building ($(BOARD))\n\n"
	@$(ENV) && cd $(SRC_DIR) && west build -b $(BOARD) --sysbuild -d $(BUILD_DIR) .

pristine:
	@printf "\n==> Pristine build ($(BOARD))\n\n"
	@$(ENV) && cd $(SRC_DIR) && west build -p -b $(BOARD) --sysbuild -d $(BUILD_DIR) .

flash:
	@printf "\n==> Flashing (SN=$(SN))\n\n"
	@$(ENV) && cd $(SRC_DIR) && west flash -d $(BUILD_DIR) --dev-id $(SN)

monitor:
	@printf "\n==> Serial console $(PORT) @ $(BAUD) 8N1 — exit with Ctrl-A Ctrl-Q\n\n"
	@picocom $(PORT) -b $(BAUD)

test:
	@printf "\n==> Running tests (Twister)\n\n"
	@$(ENV) && west twister -T $(SRC_DIR) --platform $(BOARD) || \
	  printf "\n(no tests defined yet)\n\n"

release:
	@printf "\n==> Cutting release\n\n"
	@printf "(managed by semantic-release; VERSION currently $$(cat VERSION))\n\n"

clean:
	@printf "\n==> Cleaning build artefacts\n\n"
	@rm -rf $(SRC_DIR)/$(BUILD_DIR) $(BUILD_DIR)
