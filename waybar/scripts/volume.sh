#!/bin/bash

# Get the ID of the default audio sink by parsing 'wpctl status'
# This is more reliable than using @DEFAULT_AUDIO_SINK@ which can fail
sink_id=$(wpctl status | awk '/Sinks:/ {f=1; next} /Sources:/ {f=0} f && /\*/ {gsub(/\./, "", $2); print $2; exit}')

# Check if we got an ID
if [ -z "$sink_id" ]; then
    printf '{"text": "!", "tooltip": "Error: Could not find default audio sink", "class": "error"}\n'
    exit 1
fi

# Use the obtained ID to get volume and mute status
volume_info=$(wpctl get-volume "$sink_id")

# Check for mute status
if echo "$volume_info" | grep -q "MUTED"; then
    is_muted="yes"
else
    is_muted="no"
fi

# Extract volume percentage (e.g., from "Volume: 0.50" -> 50)
volume_percent=$(echo "$volume_info" | grep -oP '[0-9]+\.[0-9]+' | awk '{print int($1 * 100)}')

if [[ "$is_muted" == "yes" ]]; then
    icon=""
    text="Muted"
    class="muted"
else
    class="unmuted"
    text="$volume_percent"
    if [[ "$volume_percent" -gt 70 ]]; then
        icon=""
    elif [[ "$volume_percent" -gt 30 ]]; then
        icon=""
    elif [[ "$volume_percent" -gt 0 ]]; then
        icon=""
    else
        icon=""
    fi
fi

# JSON output for Waybar
printf '{"text": "%s", "tooltip": "Volume: %s%%", "class": "%s", "icon": "%s"}\n' "$text" "$volume_percent" "$class" "$icon"