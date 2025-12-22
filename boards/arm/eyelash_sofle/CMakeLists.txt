# Copyright (c) 2024
# SPDX-License-Identifier: MIT

# Add custom source file to the application
if(TARGET app)
    target_sources(app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/direct_rgb.c)
else()
    # Fallback: try zephyr_library if app target doesn't exist
    zephyr_library_sources(${CMAKE_CURRENT_SOURCE_DIR}/direct_rgb.c)
endif()

