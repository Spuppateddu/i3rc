#!/usr/bin/env bash
# Emits i3 workspaces grouped by output as JSON, on every workspace/output event.
# Shape: {"HDMI-1":[{num,name,label,focused,visible,urgent},...], "eDP-1":[...]}

emit() {
    i3-msg -t get_workspaces 2>/dev/null | jq -c '
        group_by(.output)
        | map({key: .[0].output,
               value: map({num, name,
                           label: (.name | sub("^[0-9]+: *"; "")),
                           focused, visible, urgent})})
        | from_entries' 2>/dev/null || echo '{}'
}

emit
i3-msg -t subscribe -m '["workspace","output"]' 2>/dev/null | while read -r _; do
    emit
done
