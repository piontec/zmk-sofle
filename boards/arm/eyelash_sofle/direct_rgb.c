/*
 * Copyright (c) 2024
 * SPDX-License-Identifier: MIT
 *
 * Custom RGB LED control based on layer state
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/led_strip.h>
#include <zephyr/devicetree.h>
#include <zephyr/logging/log.h>
#include <zmk/events/layer_state_changed.h>
#include <zmk/event_manager.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#define STRIP_NODE DT_NODELABEL(led_strip)
#define STRIP_NUM_PIXELS DT_PROP(STRIP_NODE, chain_length)

static const struct device *led_strip = DEVICE_DT_GET(STRIP_NODE);

struct rgb_value {
    uint8_t r;
    uint8_t g;
    uint8_t b;
};

static struct rgb_value pixels[STRIP_NUM_PIXELS];

static void update_leds(void) {
    if (!device_is_ready(led_strip)) {
        LOG_ERR("LED strip device not ready");
        return;
    }

    struct led_rgb rgb_pixels[STRIP_NUM_PIXELS];
    
    for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
        rgb_pixels[i].r = pixels[i].r;
        rgb_pixels[i].g = pixels[i].g;
        rgb_pixels[i].b = pixels[i].b;
    }

    int ret = led_strip_update_rgb(led_strip, rgb_pixels, STRIP_NUM_PIXELS);
    if (ret != 0) {
        LOG_ERR("Failed to update LEDs: %d", ret);
    } else {
        LOG_DBG("Updated %d LEDs", STRIP_NUM_PIXELS);
    }
}

static void clear_all_leds(void) {
    LOG_DBG("Clearing all LEDs");
    for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
        pixels[i].r = 0;
        pixels[i].g = 0;
        pixels[i].b = 0;
    }
    update_leds();
}

static void set_escape_key_red(void) {
    LOG_DBG("Setting escape key (LED 0) to red");
    // Clear all LEDs first
    for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
        pixels[i].r = 0;
        pixels[i].g = 0;
        pixels[i].b = 0;
    }
    
    // Set LED 0 (escape key) to red
    pixels[0].r = 255;
    pixels[0].g = 0;
    pixels[0].b = 0;
    
    update_leds();
}

static int layer_state_changed_listener(const zmk_event_t *eh) {
    const struct zmk_layer_state_changed *ev = as_zmk_layer_state_changed(eh);
    
    if (ev == NULL) {
        printk("DIRECT_RGB: ERROR - Invalid layer state changed event\n");
        LOG_ERR("Invalid layer state changed event");
        return -EINVAL;
    }

    printk("DIRECT_RGB: Layer state changed: layer=%d, state=%d\n", ev->layer, ev->state);
    LOG_DBG("Layer state changed: layer=%d, state=%d", ev->layer, ev->state);

    // Check if layer 1 is being activated or deactivated
    if (ev->layer == 1) {
        if (ev->state) {
            // Layer 1 activated - highlight escape key in red
            LOG_DBG("Layer 1 activated - setting escape key red");
            set_escape_key_red();
        } else {
            // Layer 1 deactivated - turn off all LEDs
            LOG_DBG("Layer 1 deactivated - clearing LEDs");
            clear_all_leds();
        }
    }
    // For default layer (layer 0), we want no LEDs lit
    // This is handled by clearing when layer 1 is deactivated

    return 0;
}

ZMK_LISTENER(direct_rgb, layer_state_changed_listener);
ZMK_SUBSCRIPTION(direct_rgb, zmk_layer_state_changed);

static struct k_work_delayable test_work;

static void test_work_handler(struct k_work *work) {
    LOG_INF("Clearing test LED");
    clear_all_leds();
}

static int direct_rgb_init(void) {
    // Force a printk to verify code is running
    printk("DIRECT_RGB: Initializing direct RGB control\n");
    LOG_INF("Initializing direct RGB control");
    
    if (led_strip == NULL) {
        printk("DIRECT_RGB: ERROR - led_strip device pointer is NULL\n");
        LOG_ERR("LED strip device pointer is NULL");
        return -ENODEV;
    }
    
    if (!device_is_ready(led_strip)) {
        printk("DIRECT_RGB: ERROR - LED strip device not ready at init\n");
        LOG_ERR("LED strip device not ready at init");
        return -ENODEV;
    }

    printk("DIRECT_RGB: LED strip device ready, %d pixels\n", STRIP_NUM_PIXELS);
    LOG_INF("LED strip device ready, %d pixels", STRIP_NUM_PIXELS);

    // Initialize all LEDs to off
    clear_all_leds();
    
    // Test: Set first LED to red briefly to verify hardware works
    printk("DIRECT_RGB: Testing LED 0 with red color\n");
    LOG_INF("Testing LED 0 with red color");
    pixels[0].r = 255;
    pixels[0].g = 0;
    pixels[0].b = 0;
    update_leds();
    
    // Schedule clearing after 1 second
    k_work_init_delayable(&test_work, test_work_handler);
    k_work_schedule(&test_work, K_MSEC(1000));
    
    printk("DIRECT_RGB: Direct RGB initialization complete\n");
    LOG_INF("Direct RGB initialization complete");

    return 0;
}

// Use POST_KERNEL with lower priority to ensure device is ready
// Priority 90 is after most drivers but before APPLICATION level
SYS_INIT(direct_rgb_init, POST_KERNEL, 90);

