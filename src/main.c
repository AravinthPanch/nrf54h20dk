/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) 2026 Aravinth Panch
 * Author: Aravinth Panch <ara@aracreate.group>
 * Description: nRF54H20 DK: application entry (cpuapp) — prints a boot banner, then
 * reports the state of BUTTON1 (sw0 / P0.8) over VCOM0.
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

/*
 * DK silkscreen BUTTON1 == devicetree alias sw0 (node button0, P0.8).
 * Configured active-low with a pull-up in the board devicetree, so the logical value
 * from gpio_pin_get_dt() is 1 when pressed, 0 when released.
 */
#define BUTTON1_NODE DT_ALIAS(sw0)
#if !DT_NODE_EXISTS(BUTTON1_NODE)
#error "sw0 alias (BUTTON1 / P0.8) is not defined in the board devicetree"
#endif

static const struct gpio_dt_spec button1 = GPIO_DT_SPEC_GET(BUTTON1_NODE, gpios);

int main(void)
{
	printk("Hello from Ara on %s\n", CONFIG_BOARD_TARGET);

	if (!gpio_is_ready_dt(&button1)) {
		printk("Error: BUTTON1 GPIO port %s not ready\n", button1.port->name);
		return 0;
	}

	int ret = gpio_pin_configure_dt(&button1, GPIO_INPUT);
	if (ret != 0) {
		printk("Error %d: failed to configure BUTTON1\n", ret);
		return 0;
	}

	int last = -1;

	while (1) {
		int val = gpio_pin_get_dt(&button1);

		if (val < 0) {
			printk("Error %d: failed to read BUTTON1\n", val);
		} else if (val != last) {
			printk("BUTTON1: %s\n", val ? "PRESSED" : "released");
			last = val;
		}

		k_msleep(50);
	}

	return 0;
}
