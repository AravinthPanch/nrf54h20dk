/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) 2026 Aravinth Panch
 * Author: Aravinth Panch <ara@aracreate.group>
 *
 * Minimal Zephyr hello-world for the nRF54H20 DK application core (cpuapp):
 * prints a boot banner over VCOM0, then idles.
 */

#include <zephyr/kernel.h>

int main(void)
{
	printk("Hello from nrf54h20dk on %s\n", CONFIG_BOARD_TARGET);

	while (1) {
		k_msleep(1000);
	}

	return 0;
}
