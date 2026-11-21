#!/bin/bash
# Full QA for a version: the scenario matrix on top of suite.sh. Run before every tag.
#   bash godot/tools/qa.sh [out_dir]        (GODOT=/path/to/Godot, QA_JOBS=6 workers, QA_SEEDS="1 2 3 4")
# Every bot run also reports the cost of a simulation tick on its worst day (TICK COST).
# Scenarios, per chapter: the building bot on several seeds, at four paces (1, 2, 4, 30
# decisions a day) and with three answer styles; every legacy start hands-off and with the
# bot; a bot that ignores the chapter's mechanic; fuzz on several seeds; save round-trip,
# run state, i18n and content. Across chapters: campaign walks on several seeds and styles.
# One line per run lands in <out>/qa_<section>.log; the summary table is printed at the end
# and saved to <out>/QA_SUMMARY.txt. It does not replace a human at the keyboard or a real
# device: it says the build runs, saves, reads in both languages, and can be won and lost.
cd "$(dirname "$0")/../.." || exit 1
ROOT=$PWD
G=${GODOT:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}
OUT=${1:-/tmp/mandate_qa}; mkdir -p "$OUT/logs"
JOBS=${QA_JOBS:-6}
SEEDS=${QA_SEEDS:-"1 2 3 4"}
CH=$(ls godot/content/chapters)

run() { name=$1; tool=$2; shift 2; perl -e 'alarm 2400; exec @ARGV' "$G" --headless --path "$ROOT/godot" "res://tools/$tool.tscn" --fixed-fps 60 "$@" > "$OUT/logs/$name.log" 2>&1; echo $?; }
# Parallel tool runs collide on user://saves_tools/save_0.json: that one error is not a finding.
line() { name=$1; pat=$2; code=$3; errs=$(grep "SCRIPT ERROR\|Parse Error\|^ERROR" "$OUT/logs/$name.log" | grep -vc "cannot replace user://saves_tools"); echo "$name | exit $code | errors $errs | $(grep -E "$pat" "$OUT/logs/$name.log" | tr '\n' ' ' | cut -c1-900)" >> "$OUT/qa_$SEC.log"; }
legacies() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d=d if isinstance(d,list) else d.get('legacies',d); print(' '.join(x['id'] for x in (d if isinstance(d,list) else d.values())))" "godot/content/chapters/$1/start_legacies.json" 2>/dev/null; }

section() {
  SEC=$1; : > "$OUT/qa_$SEC.log"
  case $SEC in
  fuzz)
    for ch in $CH; do for seed in $SEEDS; do
      n=fuzz_${ch}_s${seed}; c=$(run $n fuzz_smoke --quit-after 400000 -- chapter=$ch seed=$seed); line $n "^=== FUZZ|НАРУШЕНИЕ|^=== SMOKE" $c
    done; done ;;
  campaign)
    for seed in 1 2 3; do for lean in none patron city; do
      n=campaign_s${seed}_${lean}; args="seed=$seed"; [ $lean != none ] && args="$args lean=$lean"
      c=$(run $n campaign_smoke --quit-after 2000000 -- $args); line $n "^=== CAMPAIGN|^FAIL|^дорога" $c
    done; done ;;
  checks)
    for ch in $CH; do
      n=i18n_$ch; c=$(run $n i18n_smoke --quit-after 400000 -- chapter=$ch); line $n "^=== I18N" $c
      n=save_$ch; c=$(run $n save_roundtrip -- chapter=$ch); line $n "^=== " $c
      n=runstate_$ch; c=$(run $n run_state_smoke -- chapter=$ch); line $n "^=== |FAIL" $c
      n=content_$ch; c=$(run $n content_check --quit-after 2000 -- chapter=$ch); line $n "^=== CONTENT" $c
    done
    n=rules; c=$(run $n rules_smoke); line $n "^=== RULES|^FAIL" $c ;;
  *)
    ch=$SEC
    for seed in $SEEDS; do
      for pace in 1 2 4 30; do
        n=bot_${ch}_s${seed}_p${pace}; c=$(run $n player_bot --quit-after 400000 -- chapter=$ch seed=$seed pace=$pace); line $n "^BOT \[|^TICK COST" $c
      done
      for lean in patron city; do
        n=bot_${ch}_s${seed}_${lean}; c=$(run $n player_bot --quit-after 400000 -- chapter=$ch seed=$seed lean=$lean); line $n "^BOT \[|^TICK COST" $c
      done
      n=botoff_${ch}_s${seed}; c=$(run $n player_bot --quit-after 400000 -- chapter=$ch seed=$seed mechanic=off); line $n "^BOT \[|^TICK COST" $c
    done
    for leg in $(legacies $ch); do
      n=loop_${ch}_${leg}; c=$(run $n loop_smoke --quit-after 400000 -- chapter=$ch legacy=$leg); line $n "^=== SMOKE|CHAPTER ACCEPTANCE|БЛОКЕР" $c
      n=botleg_${ch}_${leg}; c=$(run $n player_bot --quit-after 400000 -- chapter=$ch legacy=$leg seed=5); line $n "^BOT \[|^TICK COST" $c
    done ;;
  esac
  echo "## done" >> "$OUT/qa_$SEC.log"
}

if [ -n "$QA_SECTION" ]; then section "$QA_SECTION"; exit 0; fi
echo "QA: $(grep 'config/version' godot/project.godot) at $(git rev-parse --short HEAD) → $OUT"
for sec in $CH fuzz campaign checks; do
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do sleep 5; done
  QA_SECTION=$sec bash "$0" "$OUT" &
done
wait
python3 godot/tools/qa_summary.py "$OUT" | tee "$OUT/QA_SUMMARY.txt"
