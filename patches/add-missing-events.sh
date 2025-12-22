#!/bin/bash
# Script to add missing event implementations to ZMK PR 2752 branch
# This fixes linker errors for missing event functions

ZMK_DIR="$1"
if [ -z "$ZMK_DIR" ]; then
    echo "Usage: $0 <zmk_directory>"
    exit 1
fi

cd "$ZMK_DIR" || exit 1

# Create split_peripheral_layer_changed event header
mkdir -p app/include/zmk/events
cat > app/include/zmk/events/split_peripheral_layer_changed.h << 'EOF'
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
EOF

# Create split_peripheral_layer_changed event implementation
mkdir -p app/src/events
cat > app/src/events/split_peripheral_layer_changed.c << 'EOF'
/*
 * Copyright (c) 2024 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

#include <zephyr/kernel.h>
#include <zmk/events/split_peripheral_layer_changed.h>

ZMK_EVENT_IMPL(zmk_split_peripheral_layer_changed);
EOF

# Ensure hid_indicators_changed event is implemented
# Check if implementation exists, if not create it
if [ ! -f "app/src/events/hid_indicators_changed.c" ]; then
    cat > app/src/events/hid_indicators_changed.c << 'EOF'
/*
 * Copyright (c) 2022 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

#include <zephyr/kernel.h>
#include <zmk/events/hid_indicators_changed.h>

ZMK_EVENT_IMPL(zmk_hid_indicators_changed);
EOF
fi

echo "Patched ZMK with missing event implementations"

