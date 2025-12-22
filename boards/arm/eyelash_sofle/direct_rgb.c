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
#include <zmk/events/layer_state_changed.h>
#include <zmk/event_manager.h>

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
        return;
    }

    struct led_rgb rgb_pixels[STRIP_NUM_PIXELS];
    
    for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
        rgb_pixels[i].r = pixels[i].r;
        rgb_pixels[i].g = pixels[i].g;
        rgb_pixels[i].b = pixels[i].b;
    }

    led_strip_update_rgb(led_strip, rgb_pixels, STRIP_NUM_PIXELS);
}

static void clear_all_leds(void) {
    for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
        pixels[i].r = 100;
        pixels[i].g = 100;
        pixels[i].b = 100;
    }
    update_leds();
}

static void set_escape_key_red(void) {
    // Clear all LEDs first
    clear_all_leds();
    
    // Set LED 0 (escape key) to red
    pixels[10].r = 255;
    pixels[10].g = 0;
    pixels[10].b = 0;
    
    update_leds();
}

static int layer_state_changed_listener(const zmk_event_t *eh) {
    const struct zmk_layer_state_changed *ev = as_zmk_layer_state_changed(eh);
    
    if (ev == NULL) {
        return -EINVAL;
    }

    // Check if layer 1 is being activated or deactivated
    if (ev->layer == 1) {
        if (ev->state) {
            // Layer 1 activated - highlight escape key in red
            set_escape_key_red();
        } else {
            // Layer 1 deactivated - turn off all LEDs
            clear_all_leds();
        }
    }
    // For default layer (layer 0), we want no LEDs lit
    // This is handled by clearing when layer 1 is deactivated

    return 0;
}

ZMK_LISTENER(direct_rgb, layer_state_changed_listener);
ZMK_SUBSCRIPTION(direct_rgb, zmk_layer_state_changed);

static int direct_rgb_init(void) {
    if (!device_is_ready(led_strip)) {
        return -ENODEV;
    }

    // Initialize all LEDs to off
    clear_all_leds();

    return 0;
}

SYS_INIT(direct_rgb_init, APPLICATION, CONFIG_APPLICATION_INIT_PRIORITY);

