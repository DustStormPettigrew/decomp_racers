#!/usr/bin/env bash
# score.sh LEGORACERS|GOLDP              -> totals + writes $RACERS_BUILD/<TARGET>.json
# score.sh LEGORACERS|GOLDP 0xADDRESS    -> verbose diff for one function (or vtable)
# score.sh compare LEGORACERS before.json -> list every function whose score changed vs a saved json
source "$HOME/racers-env.sh"
cd "$RACERS_BUILD/build"
if [ "$1" = compare ]; then
  reccmp-reccmp --target "$2" --json "$RACERS_BUILD/$2.json" >/dev/null 2>&1
  python3 - "$3" "$RACERS_BUILD/$2.json" <<'PY'
import json,sys
a={e['address']:e for e in json.load(open(sys.argv[1]))['data']}
b={e['address']:e for e in json.load(open(sys.argv[2]))['data']}
for k in sorted(set(a)|set(b)):
    x=(a.get(k) or {}).get('matching') or 0; y=(b.get(k) or {}).get('matching') or 0
    if abs(x-y)>1e-9: print(f"{'UP  ' if y>x else 'DOWN'} {k} {(b.get(k) or a.get(k))['name']}: {x*100:.2f}% -> {y*100:.2f}%")
if set(a)!=set(b): print('ADDRESS SET CHANGED:',sorted(set(a)^set(b))[:10])
PY
elif [ -n "$2" ]; then
  reccmp-reccmp --target "$1" --verbose "$2" --print-rec-addr 2>&1 | grep -v 'WARNING'
else
  reccmp-reccmp --target "$1" --json "$RACERS_BUILD/$1.json" 2>&1 | tail -4
fi
