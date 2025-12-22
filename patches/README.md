# ZMK PR 2752 Linker Error Fix

This directory contains patches to fix linker errors in ZMK PR 2752 branch.

## Problem

The PR 2752 branch has missing event implementations causing linker errors:
- `zmk_event_zmk_hid_indicators_changed` 
- `as_zmk_hid_indicators_changed`
- `zmk_event_zmk_split_peripheral_layer_changed`

## Solution

The `add-missing-events.sh` script adds the missing event files to fix these errors.

## Usage

After west updates ZMK, run:
```bash
./patches/add-missing-events.sh <path-to-zmk>
```

For GitHub Actions, this needs to be integrated into the build workflow.

## Alternative: Fork Approach

1. Fork https://github.com/zmkfirmware/zmk
2. Create a branch based on PR 2752
3. Add the missing event files from this directory
4. Update `config/west.yml` to use your fork

