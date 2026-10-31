#!/usr/bin/env bash
# CI-equivalent checks for the current checkout vs upstream/master:
# clang-format 22 on changed files, decomplint (both modules), address padding, ncc on changed .cpp,
# and a modern-compiler (libclang, MSVC-compat) parse of changed .cpp files.
source "$HOME/racers-env.sh"
cd "$RACERS_REPO"
files=$(git diff --name-only upstream/master...HEAD)
src=$(echo "$files" | grep -E '\.(h|cpp)$' || true)
cpp=$(echo "$files" | grep -E '\.cpp$' || true)
[ -n "$src" ] && { clang-format --style=file --dry-run $src 2>&1 | grep -c warning | sed 's/^/clang-format warnings: /'; }
reccmp-decomplint LEGORacers common --module LEGORACERS --warnfail >/dev/null 2>&1 && echo "decomplint LR: ok" || echo "decomplint LR: FAIL"
reccmp-decomplint GolDP common --module GOLDP --warnfail >/dev/null 2>&1 && echo "decomplint GD: ok" || echo "decomplint GD: FAIL"
python tools/reccmp_addr_padding.py >/dev/null 2>&1 && echo "address padding: ok" || echo "address padding: FAIL"
LIB=$(python -c 'import clang.cindex as c,os;print(os.path.dirname(c.__file__))')/native/libclang.so
if [ -n "$cpp" ]; then
  python3 tools/ncc/ncc.py --clang-lib "$LIB" --style tools/ncc/ncc.style --skip tools/ncc/skip.yml \
    --definition DEFINE_GUID PASCAL WINAPI FAR BOOL CALLBACK HWND__=HWND \
    --include util LEGORacers/include LEGORacers GolDP/include GolDP common/include common --path $cpp 2>&1 | tail -3
  python3 "$(dirname "$0")/modern_check.py" $cpp
fi
