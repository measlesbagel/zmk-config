/*
 * Copyright (c) 2026
 * SPDX-License-Identifier: MIT
 */

#define DT_DRV_COMPAT crosses_input_processor_text_nav

#include <stdlib.h>

#include <zephyr/device.h>
#include <zephyr/dt-bindings/input/input-event-codes.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include <drivers/input_processor.h>
#include <zmk/behavior_queue.h>
#include <zmk/events/position_state_changed.h>
#include <zmk/keymap.h>
#include <zmk/virtual_key_position.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#define TEXT_NAV_BINDING_COUNT 4
#define TEXT_NAV_MAX_TAPS_PER_REPORT 4

enum text_nav_direction {
    TEXT_NAV_LEFT = 0,
    TEXT_NAV_RIGHT,
    TEXT_NAV_UP,
    TEXT_NAV_DOWN,
};

struct text_nav_config {
    uint8_t index;
    uint16_t tap_ms;
    const struct zmk_behavior_binding *bindings;
};

struct text_nav_data {
    int32_t x;
    int32_t y;
};

static int queue_taps(const struct text_nav_config *cfg,
                      struct zmk_input_processor_state *state,
                      enum text_nav_direction direction, uint8_t count) {
    struct zmk_behavior_binding_event behavior_event = {
        .position = ZMK_VIRTUAL_KEY_POSITION_BEHAVIOR_INPUT_PROCESSOR(
            state->input_device_index, cfg->index),
        .timestamp = k_uptime_get(),
#if IS_ENABLED(CONFIG_ZMK_SPLIT)
        .source = ZMK_POSITION_STATE_CHANGE_SOURCE_LOCAL,
#endif
    };

    for (uint8_t i = 0; i < count; i++) {
        int ret = zmk_behavior_queue_add(&behavior_event, cfg->bindings[direction], true,
                                         cfg->tap_ms);
        if (ret < 0) {
            return ret;
        }

        ret = zmk_behavior_queue_add(&behavior_event, cfg->bindings[direction], false, 0);
        if (ret < 0) {
            return ret;
        }
    }

    return 0;
}

static int text_nav_handle_event(const struct device *dev, struct input_event *event,
                                 uint32_t param1, uint32_t param2,
                                 struct zmk_input_processor_state *state) {
    if (event->type != INPUT_EV_REL ||
        (event->code != INPUT_REL_X && event->code != INPUT_REL_Y)) {
        return ZMK_INPUT_PROC_CONTINUE;
    }

    const struct text_nav_config *cfg = dev->config;
    struct text_nav_data *data = dev->data;

    if (event->code == INPUT_REL_X) {
        data->x += event->value;
    } else {
        data->y += event->value;
    }

    /*
     * A layer override's STOP result is intentionally consumed by ZMK's input
     * listener before HID reporting. Zero the original axis event instead so
     * the listener can finish the report without also moving the cursor.
     */
    event->value = 0;

    /* Sensors normally sync on Y; retain both axes until the report is whole. */
    if (!event->sync) {
        return ZMK_INPUT_PROC_CONTINUE;
    }

    const int32_t horizontal_threshold = MAX((int32_t)param1, 1);
    const int32_t vertical_threshold = MAX((int32_t)param2, 1);
    int32_t *dominant;
    int32_t *minor;
    int32_t threshold;
    enum text_nav_direction negative_direction;
    enum text_nav_direction positive_direction;

    /* Compare normalized progress toward each axis' independent threshold. */
    int64_t horizontal_progress = (int64_t)abs(data->x) * vertical_threshold;
    int64_t vertical_progress = (int64_t)abs(data->y) * horizontal_threshold;

    if (horizontal_progress >= vertical_progress) {
        dominant = &data->x;
        minor = &data->y;
        threshold = horizontal_threshold;
        negative_direction = TEXT_NAV_LEFT;
        positive_direction = TEXT_NAV_RIGHT;
    } else {
        dominant = &data->y;
        minor = &data->x;
        threshold = vertical_threshold;
        negative_direction = TEXT_NAV_UP;
        positive_direction = TEXT_NAV_DOWN;
    }

    uint32_t available = abs(*dominant) / threshold;
    uint8_t taps = MIN(available, TEXT_NAV_MAX_TAPS_PER_REPORT);
    if (taps == 0) {
        return ZMK_INPUT_PROC_CONTINUE;
    }

    enum text_nav_direction direction =
        *dominant < 0 ? negative_direction : positive_direction;
    int32_t consumed = (int32_t)taps * threshold;
    *dominant += *dominant < 0 ? consumed : -consumed;

    /* Axis-lock each emitted step so diagonal jitter cannot leak out later. */
    *minor = 0;

    int ret = queue_taps(cfg, state, direction, taps);
    if (ret < 0) {
        LOG_ERR("Failed to queue text navigation behavior: %d", ret);
    }

    return ZMK_INPUT_PROC_CONTINUE;
}

static const struct zmk_input_processor_driver_api text_nav_driver_api = {
    .handle_event = text_nav_handle_event,
};

static int text_nav_init(const struct device *dev) { return 0; }

#define TEXT_NAV_INST(n)                                                                           \
    BUILD_ASSERT(DT_INST_PROP_LEN(n, bindings) == TEXT_NAV_BINDING_COUNT,                          \
                 "text-nav bindings must be left, right, up, and down");                          \
    static const struct zmk_behavior_binding text_nav_bindings_##n[] = {                           \
        LISTIFY(DT_INST_PROP_LEN(n, bindings), ZMK_KEYMAP_EXTRACT_BINDING, (, ), DT_DRV_INST(n))}; \
    static const struct text_nav_config text_nav_config_##n = {                                    \
        .index = n,                                                                                \
        .tap_ms = DT_INST_PROP(n, tap_ms),                                                         \
        .bindings = text_nav_bindings_##n,                                                         \
    };                                                                                             \
    static struct text_nav_data text_nav_data_##n;                                                 \
    DEVICE_DT_INST_DEFINE(n, text_nav_init, NULL, &text_nav_data_##n, &text_nav_config_##n,        \
                          POST_KERNEL, CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,                        \
                          &text_nav_driver_api);

DT_INST_FOREACH_STATUS_OKAY(TEXT_NAV_INST)
