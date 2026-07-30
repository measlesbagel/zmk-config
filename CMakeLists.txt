# Copyright (c) 2026
# SPDX-License-Identifier: MIT

if(CONFIG_CROSSES_TEXT_NAV)
  zephyr_library()
  zephyr_library_sources(src/input_processor_text_nav.c)
endif()
