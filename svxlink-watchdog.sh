#!/usr/bin/env bash

GPIO=16
SERVICE="svxlink"
LOW_TIME_REQUIRED=360   # 6 minutes
CHECK_INTERVAL=1        # seconds

low_since=0
restart_done_for_this_low=0

read_gpio_level() {
    local out

    if command -v pinctrl >/dev/null 2>&1; then
        out="$(pinctrl get "$GPIO" 2>/dev/null || true)"

        if echo "$out" | grep -Eq '(^|[[:space:]])lo([[:space:]|/]|$)'; then
            echo 0
            return 0
        fi

        if echo "$out" | grep -Eq '(^|[[:space:]])hi([[:space:]|/]|$)'; then
            echo 1
            return 0
        fi
    fi

    if command -v raspi-gpio >/dev/null 2>&1; then
        out="$(raspi-gpio get "$GPIO" 2>/dev/null || true)"

        if echo "$out" | grep -q 'level=0'; then
            echo 0
            return 0
        fi

        if echo "$out" | grep -q 'level=1'; then
            echo 1
            return 0
        fi
    fi

    echo "ERROR"
    return 1
}

logger -t svxlink-watchdog "Started GPIO$GPIO watchdog for $SERVICE"

while true; do
    level="$(read_gpio_level)"
    now="$(date +%s)"

    if [ "$level" = "0" ]; then
        if [ "$low_since" -eq 0 ]; then
            low_since="$now"
            restart_done_for_this_low=0
            logger -t svxlink-watchdog "GPIO$GPIO went LOW (restart after ${LOW_TIME_REQUIRED}s)"
        fi

        low_duration=$((now - low_since))
        remaining=$((LOW_TIME_REQUIRED - low_duration))

        if [ "$restart_done_for_this_low" -eq 0 ] \
           && [ "$low_duration" -gt 0 ] \
           && [ $((low_duration % 5)) -eq 0 ]; then
            logger -t svxlink-watchdog "GPIO$GPIO LOW ${low_duration}s, ${remaining}s until restart"
        fi

        if [ "$low_duration" -ge "$LOW_TIME_REQUIRED" ] && [ "$restart_done_for_this_low" -eq 0 ]; then
            logger -t svxlink-watchdog "GPIO$GPIO LOW for ${low_duration}s, restarting $SERVICE"

            systemctl restart "$SERVICE"

            if [ $? -eq 0 ]; then
                logger -t svxlink-watchdog "$SERVICE restarted successfully"
            else
                logger -t svxlink-watchdog "ERROR: failed to restart $SERVICE"
            fi

            restart_done_for_this_low=1
        fi

    elif [ "$level" = "1" ]; then
        if [ "$low_since" -ne 0 ]; then
            logger -t svxlink-watchdog "GPIO$GPIO returned HIGH"
        fi

        low_since=0
        restart_done_for_this_low=0

    else
        logger -t svxlink-watchdog "Could not read GPIO$GPIO state"
    fi

    sleep "$CHECK_INTERVAL"
  done
