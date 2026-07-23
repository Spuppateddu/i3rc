#!/usr/bin/env bash
# Emits the bar's layout density for the primary output.
# Shape: {"tier":"dense","w":1366,"gap":3,"group":5,"item":4,"title":64,"tray":72}
#
# Two things happen here, both of them the "flex" the bar has:
#
#   1. Tier — gaps and paddings shrink on narrow screens so every segment still
#      fits, and never grow past the `wide` numbers: those are the max gap.
#   2. title — the player marquee is padded to an exact character count, so it
#      is the one element that can absorb leftover width. We compute how many
#      characters are left over after every other (fixed-width by design)
#      segment, so the free space becomes visible song title instead of a dead
#      zone. Never below TITLE_MIN, so a busy bar just scrolls sooner.
#
# `base` below is the pixel width of everything except the title and the
# workspace buttons, per tier. CHAR100 is the advance of the 11px CaskaydiaCove
# cell ×100. Both were measured on-screen, not estimated: grab the bar with
#   ffmpeg -f x11grab -video_size <w>x28 -i :0.0+0,0 -frames:v 1 bar.png
# and find the folder glyph (#b8bb26) and wifi glyph (#83a598) columns. 24px
# between them is the intrinsic padding floor — when the gap reads 24, the
# title is exactly filling the bar. Re-measure if the font or paddings change.
# Only `dense` is measured (1366x768 panel); compact/wide are derived from it
# by their padding deltas, so those may still leave a few px of slack.
#
# `title` is in characters, everything else in pixels. The values are mirrored
# to a state file so player.sh picks up changes without re-spawning.

STATE="${XDG_RUNTIME_DIR:-/tmp}/i3rc-eww-layout"

CHAR100=722
MARGIN=16      # px kept free so a rounding error never pushes the tray off-screen
TITLE_MIN=40
TITLE_MAX=96

emit() {
    local w tier gap group item tray base wspad ipad
    local wsn wschars wscost detached title

    w=$(xrandr --listactivemonitors 2>/dev/null |
        awk 'NR>1 && $2 ~ /\*/ {split($3, a, "/"); print a[1]; exit}')
    case "$w" in ''|*[!0-9]*) w=1920 ;; esac

    if   [ "$w" -ge 1800 ]; then
        tier=wide;    gap=10 group=12 item=6 tray=120 base=1038 wspad=18 ipad=12
    elif [ "$w" -ge 1500 ]; then
        tier=compact; gap=6  group=8  item=5 tray=96  base=892  wspad=14 ipad=8
    else
        tier=dense;   gap=3  group=5  item=4 tray=72  base=781  wspad=12 ipad=5
    fi

    # Workspace buttons are the only variable-width part of the bar: count them
    # (all outputs — the ones elsewhere show in the detached card) so the title
    # gives ground as workspaces appear instead of overflowing the bar.
    read -r wsn wschars detached < <(
        i3-msg -t get_workspaces 2>/dev/null | jq -r '
            [.[] | .name | sub("^[0-9]+: *"; "")] as $l
            | "\($l | length) \($l | map(length) | add // 0) \(
                if ([.[] | .output] | unique | length) > 1 then 1 else 0 end)"
        ' 2>/dev/null
    )
    case "$wsn" in ''|*[!0-9]*) wsn=4 wschars=4 detached=0 ;; esac

    wscost=$(( (wschars * CHAR100 + 50) / 100 + wsn * (wspad + 2) ))
    [ "$detached" = 1 ] && wscost=$(( wscost + 2 * ipad + gap ))

    title=$(( ((w - base - wscost - MARGIN) * 100) / CHAR100 ))
    [ "$title" -lt "$TITLE_MIN" ] && title=$TITLE_MIN
    [ "$title" -gt "$TITLE_MAX" ] && title=$TITLE_MAX

    printf 'LAY_TIER=%s LAY_TITLE=%s\n' "$tier" "$title" >"$STATE"
    printf '{"tier":"%s","w":%s,"gap":%s,"group":%s,"item":%s,"title":%s,"tray":%s}\n' \
        "$tier" "$w" "$gap" "$group" "$item" "$title" "$tray"
}

# Workspace events fire on every focus change; only re-emit when the layout
# actually changed, so the bar is not rebuilt for a plain workspace switch.
last=""
emit_changed() {
    local out
    out=$(emit)
    [ "$out" = "$last" ] && return
    last="$out"
    printf '%s\n' "$out"
}

emit_changed
i3-msg -t subscribe -m '["output","workspace"]' 2>/dev/null | while read -r _; do
    emit_changed
done
