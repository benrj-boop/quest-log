#!/bin/bash
# Recalculates token burn stats from Claude Code session data and pushes to GitHub

cd ~/quest-log || exit 1

STATS=$(python3 -c "
import json, os, glob

project_dir = os.path.expanduser('~/.claude/projects/-Users-benrj/')
files = sorted(glob.glob(project_dir + '*.jsonl'))

total_input = 0
total_output = 0
total_cache_create = 0
total_cache_read = 0

for f in files:
    with open(f) as fh:
        for line in fh:
            try:
                d = json.loads(line)
                if isinstance(d, dict) and 'message' in d:
                    msg = d['message']
                    if isinstance(msg, dict) and 'usage' in msg:
                        u = msg['usage']
                        total_input += u.get('input_tokens', 0)
                        total_output += u.get('output_tokens', 0)
                        total_cache_create += u.get('cache_creation_input_tokens', 0)
                        total_cache_read += u.get('cache_read_input_tokens', 0)
            except:
                pass

total = total_input + total_output + total_cache_create + total_cache_read
sessions = len(files)
kwh = (total_output/1000*0.01 + total_input/1000*0.003 + total_cache_create/1000*0.003 + total_cache_read/1000*0.0005)
pushups = kwh * 860 / 0.4
tesla_km = kwh / 0.15
bathtubs = kwh * 1.8 / 300
cost = (total_input*15 + total_output*75 + total_cache_create*18.75 + total_cache_read*1.875) / 1_000_000

print(f'{total}|{sessions}|{kwh:.0f}|{pushups:.0f}|{tesla_km:.0f}|{bathtubs:.1f}|{cost:.0f}')
")

IFS='|' read -r TOTAL SESSIONS KWH PUSHUPS TESLA BATHTUBS COST <<< "$STATS"

# Format numbers
TOTAL_FMT=$(printf "%'d" "$TOTAL")
PUSHUPS_FMT=$(python3 -c "print(f'{$PUSHUPS/1_000_000:.1f}M')")
TESLA_FMT=$(printf "%'d" "$TESLA")
BATHTUBS_FMT=$(printf "%.0f" "$BATHTUBS")

# Update the HTML
sed -i '' "s/const baseTokens = [0-9]*/const baseTokens = $TOTAL/" index.html
sed -i '' "s/const baseTime = new Date('[^']*')/const baseTime = new Date('$(date -u +%Y-%m-%dT%H:%M:%S+00:00)')/" index.html

# Update static fallback in the counter div
sed -i '' "s|<div id=\"token-counter\"[^>]*>[^<]*</div>|<div id=\"token-counter\" style=\"font-family: 'Press Start 2P', monospace; font-size: 28px; color: #f97316; text-shadow: 0 0 20px #f9731640; margin: 12px 0; letter-spacing: -1px;\">$TOTAL_FMT</div>|" index.html

# Update sub-stats
sed -i '' "s|<div style=\"font-size: 16px; font-weight: 700; color: #e6edf3;\">[0-9.]*M</div>|<div style=\"font-size: 16px; font-weight: 700; color: #e6edf3;\">${PUSHUPS_FMT}</div>|" index.html
sed -i '' "s|>[0-9]*</div>.*kilowatt hours|>${KWH}</div><div style=\"font-size: 9px; color: #8b949e;\">kilowatt hours|" index.html

# Update cost
sed -i '' "s|≈ \$[0-9,]* at Opus rates|≈ \$${COST} at Opus rates|" index.html

# Commit and push if changed
if ! git diff --quiet; then
  git add -A
  git commit -m "auto-update: ${TOTAL_FMT} tokens burned"
  git push
  echo "Updated: $TOTAL_FMT tokens, \$$COST cost, ${KWH}kWh"
else
  echo "No changes detected"
fi

# Also sync to Erebor
cp index.html ~/Documents/Vault/Erebor/_system/dashboard.html
