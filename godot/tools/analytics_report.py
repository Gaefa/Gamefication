#!/usr/bin/env python3
"""Turns play logs (RunLog, user://analytics/run_*.jsonl) from testers into one report.

Usage: python3 godot/tools/analytics_report.py <folder, .zip or .jsonl> [more ...]
Folders are searched recursively, so a folder with one sub-folder per tester works, and so
does a folder of the archives testers send (Options -> "Pack a report"): each .zip is read
in place.

Where the game keeps the logs (Options -> "Open folder" opens it):
  macOS   ~/Library/Application Support/Godot/app_userdata/Mandate Cities/analytics
  Windows %APPDATA%\\Godot\\app_userdata\\Mandate Cities\\analytics
"""
import json
import statistics
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path


BROKEN = [0]  # lines that were not JSON (a log cut off by a crash, or two writers on one file)


def parse(text):
    lines = []
    for raw in text.splitlines():
        if not raw.strip():
            continue
        try:
            lines.append(json.loads(raw))
        except json.JSONDecodeError:
            BROKEN[0] += 1
    return [x for x in lines if isinstance(x, dict) and "kind" in x]


def load_runs(paths):
    runs = []
    for arg in paths:
        p = Path(arg)
        if p.is_dir():
            files = sorted(p.rglob("run_*.jsonl")) + sorted(p.rglob("*.zip"))
        else:
            files = [p]
        for f in files:
            if f.suffix == ".zip":
                with zipfile.ZipFile(f) as archive:
                    for name in sorted(archive.namelist()):
                        if name.startswith("analytics/") and name.endswith(".jsonl"):
                            lines = parse(archive.read(name).decode("utf-8"))
                            if lines:
                                runs.append((f"{f}:{name}", lines))
                continue
            lines = parse(f.read_text(encoding="utf-8"))
            if lines:
                runs.append((f, lines))
    return runs


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    runs = load_runs(argv)
    if not runs:
        print("No run_*.jsonl files found.")
        return 1

    outcomes, last_days, playtimes, sessions, versions = Counter(), [], [], [], Counter()
    tut_reached, tut_done, tut_runs = Counter(), 0, 0
    choices = defaultdict(Counter)
    pressure_by_day = defaultdict(Counter)
    chapters = defaultdict(lambda: defaultdict(list))
    for _, lines in runs:
        start = next((x for x in lines if x["kind"] == "run_start"), lines[0])
        versions[start.get("version", "?")] += 1
        last = lines[-1]
        end = next((x for x in lines if x["kind"] == "run_end"), None)
        if end:
            outcomes[f'{end.get("result")}: {end.get("ending")}'] += 1
        elif last["kind"] == "quit":
            outcomes["quit mid-run"] += 1
        else:
            outcomes["unfinished (new run started or crash)"] += 1
        last_days.append(last.get("day", start.get("day", 1)))
        # Per chapter: how it ended and whether the 0.4 mechanics were found at all.
        chapter = chapters[start.get("chapter", "rust_pit")]
        chapter["runs"].append(1)
        chapter["result"].append(end.get("result") if end else ("quit" if last["kind"] == "quit" else "open"))
        chapter["day"].append(last.get("day", 1))
        norm = (end or last).get("norm") or {}
        if norm:
            chapter["norm"].append(1 if norm.get("met") else 0)
            chapter["held"].append(1 if any((x.get("norm") or {}).get("held") for x in lines) else 0)
        chapter["rush"].append(1 if last.get("rushes", 0) > 0 else 0)
        chapter["market"].append(1 if last.get("lots_bought", 0) > 0 else 0)
        chapter["feast"].append(1 if last.get("feasts", 0) > 0 else 0)
        playtimes.append(last.get("playtime", 0))
        # Real minutes played: the sum of the last line of every sitting (start, each continue).
        starts = [i for i, x in enumerate(lines) if x["kind"] in ("run_start", "run_continue")] + [len(lines)]
        sessions.append(sum(lines[b - 1].get("session_sec", 0) for b in starts[1:]))
        steps = [x for x in lines if x["kind"] == "tutorial_step"]
        if steps:
            tut_runs += 1
            tut_reached[max(x["step"] for x in steps)] += 1
            tut_done += any(x["kind"] == "tutorial_end" and x.get("completed") for x in lines)
        for x in lines:
            if x["kind"] == "desk_choice":
                choices[x["event"]][x["option"]] += 1
            elif x["kind"] == "pressure_full":
                pressure_by_day[x.get("day", 0)][x["category"]] += 1

    print(f"Runs: {len(runs)}   versions: {dict(versions)}")
    if BROKEN[0]:
        print(f"Skipped {BROKEN[0]} unreadable log lines.")
    print(f"Real minutes per run: median {statistics.median(sessions) / 60:.0f}, max {max(sessions) / 60:.0f}"
          f"   (game minutes: median {statistics.median(playtimes) / 60:.0f})")
    print("\nOutcomes:")
    for name, n in outcomes.most_common():
        print(f"  {n:4d}  {name}")
    print("\nBy chapter (runs · win/lose/quit/open · median last day · norm met · used: wagons held, evening rush, market, feast):")
    for name, data in sorted(chapters.items()):
        results = Counter(data["result"])
        norm = f'{sum(data["norm"])}/{len(data["norm"])}' if data["norm"] else "—"
        held = f'{sum(data["held"])}/{len(data["held"])}' if data["held"] else "—"
        total = len(data["runs"])
        print(f"  {name:18s} {total:3d} · {results.get('win', 0)}/{results.get('lose', 0)}/{results.get('quit', 0)}/{results.get('open', 0)}"
              f" · day {statistics.median(data['day']):.0f} · norm {norm} · held {held},"
              f" rush {sum(data['rush'])}/{total}, market {sum(data['market'])}/{total}, feast {sum(data['feast'])}/{total}")
    print("\nLast day reached (where runs stop):")
    for day, n in sorted(Counter(last_days).items()):
        print(f"  day {day:3d}  {'#' * n} {n}")
    if tut_runs:
        print(f"\nTutorial: {tut_runs} runs, completed {tut_done} ({100 * tut_done // tut_runs}%). Furthest step:")
        for step, n in sorted(tut_reached.items()):
            print(f"  step {step:2d}  {'#' * n} {n}")
    if pressure_by_day:
        print("\nPressure bars full (runs per day and category):")
        for day in sorted(pressure_by_day):
            print(f"  day {day:3d}  " + ", ".join(f"{c} {n}" for c, n in pressure_by_day[day].most_common()))
    print("\nDesk answers (option index: times chosen):")
    for event_id in sorted(choices):
        split = ", ".join(f"#{opt}: {n}" for opt, n in sorted(choices[event_id].items()))
        print(f"  {event_id:40s} {split}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
