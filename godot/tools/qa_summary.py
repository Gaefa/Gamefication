#!/usr/bin/env python3
"""Reads qa.sh's one-line-per-run logs and prints the table a release note can quote."""
import collections, glob, re, sys

out = sys.argv[1]
BOT = re.compile(
    r"^(\w+) \| exit (\d+) \| errors (\d+) \| BOT \[(\w+)\] seed (\d+) lean (\S+) pace (\d+)(?: mechanic (\S+))?: (\S+) \((\w+)\)"
    r".*?жители (\d+) \(пик (\d+), 12 с дня (-?\d+)\) \| сч (\d+) \| доверие (\d+) · поддержка (\d+)(?:.*?норма главы (\S+))?")
bots, other, bad = [], [], []
for path in sorted(glob.glob(out + "/qa_*.log")):
    for raw in open(path, encoding="utf-8"):
        raw = raw.rstrip("\n")
        if raw.startswith("##") or not raw:
            continue
        m = BOT.search(raw)
        if m:
            bots.append(m.groups())
        else:
            other.append(raw)
        head = re.match(r"^(\w+) \| exit (\d+) \| errors (\d+)", raw)
        if head and (head.group(2) != "0" or head.group(3) != "0") and not head.group(1).startswith("botoff_"):
            bad.append(raw[:200])

chapters = list(dict.fromkeys(b[3] for b in bots))
def wins(rows):
    return "%d/%d" % (sum(1 for r in rows if r[9] == "win"), len(rows)) if rows else "—"
def avg(rows, i):
    return "%.0f" % (sum(int(r[i]) for r in rows) / len(rows)) if rows else "—"

print("BOT: wins by pace (decisions a day), plain answers")
print("%-18s %6s %6s %6s %6s | %8s %8s | %6s %9s | %s" % ("chapter", "p1", "p2", "p4", "p30", "patron", "city", "trust", "support", "ignoring the mechanic"))
for ch in chapters:
    rows = [b for b in bots if b[3] == ch and b[0].startswith("bot_")]
    plain = lambda p: [r for r in rows if r[5] == "—" and r[6] == p]
    lean = lambda l: [r for r in rows if r[5] == l]
    full = [r for r in rows if r[6] == "30"]
    off = [b for b in bots if b[3] == ch and b[0].startswith("botoff_")]
    print("%-18s %6s %6s %6s %6s | %8s %8s | %6s %9s | %s" % (
        ch, wins(plain("1")), wins(plain("2")), wins(plain("4")), wins(plain("30")), wins(lean("patron")), wins(lean("city")),
        avg(full, 14), avg(full, 15), wins(off)))
print()
print("BOT: finales at full pace by answer style")
for ch in chapters:
    for style in ["—", "patron", "city"]:
        rows = [b for b in bots if b[3] == ch and b[0].startswith("bot_") and b[6] == "30" and b[5] == style]
        ends = collections.Counter(r[8].replace("ending.", "") for r in rows)
        print("  %-18s %-7s %s" % (ch, style, dict(ends)))
print()
print("LEGACIES with the bot")
for b in bots:
    if b[0].startswith("botleg_"):
        print("  %-48s %-28s people %s mood %s" % (b[0], b[8].replace("ending.", ""), b[10], b[13]))
print()
print("OTHER RUNS")
for raw in other:
    print("  " + raw[:230])
print()
print("FINDINGS (non-zero exit or script errors): %d" % len(bad))
for raw in bad:
    print("  " + raw)
