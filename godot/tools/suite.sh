#!/bin/bash
# The full tool suite, one line per tool. Run from the repo root:
#   bash godot/tools/suite.sh            (GODOT=/path/to/Godot to override the binary)
# Windowed tools (ui_flow, ui_shots, pins, props, terrain, icons) need a display.
cd "$(dirname "$0")/../.." || exit 1
G=${GODOT:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}
OUT=${SUITE_OUT:-/tmp/mandate_suite}; mkdir -p "$OUT/ru" "$OUT/en"
run() { perl -e 'alarm 900; exec @ARGV' "$G" --headless --path godot "res://tools/$1.tscn" --fixed-fps 60 "${@:2}" 2>&1; }
runw() { perl -e 'alarm 900; exec @ARGV' "$G" --path godot "res://tools/$1.tscn" "${@:2}" 2>&1; }
echo "content: $(run content_check --quit-after 2000 | grep -E '^=== CONTENT' | tr '\n' ' ')"
echo "rules: $(run rules_smoke | grep -E '^=== RULES|FAIL' | tr '\n' ' ')"
echo "save_roundtrip: $(run save_roundtrip | grep -E '^=== ROUND' | tr '\n' ' ')"
echo "run_state: $(run run_state_smoke | grep -E '^=== RUN|FAIL' | tr '\n' ' ')"
echo "fuzz: $(run fuzz_smoke -- seed=1 | grep -E '^=== FUZZ' | tr '\n' ' ')"
echo "i18n: $(run i18n_smoke -- prepared | grep -E '^=== I18N' | tr '\n' ' ')"
echo "balance: $(run balance_sim | grep -E 'G ACCEPTANCE' | tr '\n' ' ')"
echo "loop: $(run loop_smoke --quit-after 400000 | grep -E '^=== SMOKE|CHAPTER ACCEPTANCE' | tr '\n' ' ')"
echo "loop prepared: $(run loop_smoke --quit-after 400000 -- prepared | grep -E '^=== SMOKE' | tr '\n' ' ')"
for ch in bogolessky_gorge black_quarry big_nyupa old_capital; do
  echo "loop $ch: $(run loop_smoke --quit-after 400000 -- chapter=$ch | grep -E '^=== SMOKE|CHAPTER ACCEPTANCE|SCRIPT ERROR' | sort -u | tr '\n' ' ')"
done
echo "ui_flow: $(runw ui_flow_smoke | grep -E 'UI FLOW SMOKE|FAIL' | tr '\n' ' ')"
echo "ui_shots: $(runw ui_shots -- out=$OUT/ru | grep -E 'UI SHOTS|FAIL' | tr '\n' ' ')"
echo "ui_shots en: $(runw ui_shots -- out=$OUT/en locale=en | grep -E 'UI SHOTS|FAIL' | tr '\n' ' ')"
for t in pins_smoke props_smoke terrain_smoke ui_icons_smoke; do echo "$t: $(runw $t | grep -E 'SMOKE|FAIL' | tail -1)"; done
