/*
 * Copyright (c) 2024 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <zephyr/kernel.h>
#include <zmk/event_manager.h>

struct zmk_split_peripheral_layer_changed {
    uint8_t layer;
    bool state;
};

ZMK_EVENT_DECLARE(zmk_split_peripheral_layer_changed);

