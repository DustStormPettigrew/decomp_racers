#!/usr/bin/env bash
# Incremental double build of both targets (or one: build.sh legoracers|goldp). Prints errors and new warnings.
source "$HOME/racers-env.sh"
W=$(winepath -w "$RACERS_BUILD/build")
T=${1:+--target $1}
wine cmake --build "$W" $T > "$RACERS_BUILD/last_build.log" 2>&1
wine cmake --build "$W" $T >> "$RACERS_BUILD/last_build.log" 2>&1
grep -iE 'error C|fatal error|error LNK|: error' "$RACERS_BUILD/last_build.log" | head -20
grep -iE 'warning C' "$RACERS_BUILD/last_build.log" | sort -u | head -10
exit 0
