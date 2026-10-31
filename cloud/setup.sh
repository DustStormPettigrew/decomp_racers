#!/usr/bin/env bash
# One-time setup for a Linux cloud session: Wine + MSVC 6.0 + Windows CMake, a full
# build of both targets, and reccmp scoring against the original binaries.
#
# Usage:  ORIGINALS=/path/to/folder/with/originals  bash cloud/setup.sh
# The folder must contain LEGORacers.exe and GolDP.dll (the 1999 release; hashes checked).
# Everything else is downloaded from apt, PyPI and GitHub.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ORIG=${ORIGINALS:?set ORIGINALS to the folder that holds LEGORacers.exe and GolDP.dll}
export WINEPREFIX=${WINEPREFIX:-$HOME/.wine-racers}
export WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
BUILD=${BUILD:-$HOME/rbuild}
VENV=${VENV:-$HOME/venv-racers}
SUDO=""; if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null; then SUDO=sudo; fi

echo "== checking original binaries"
LR_HASH=$(sha256sum "$ORIG/LEGORacers.exe" | cut -d' ' -f1)
GD_HASH=$(sha256sum "$ORIG/GolDP.dll" | cut -d' ' -f1)
[ "$LR_HASH" = fe9e881cfa3ffc208db23ab8057ecc5697bad94d2752e8eccf6c79b10a5c1103 ] || { echo "LEGORacers.exe hash mismatch: $LR_HASH"; exit 1; }
[ "$GD_HASH" = 37856363c936c6baeb3bdbed69de182d9ecb92752b36e6db444369117e80fdba ] || { echo "GolDP.dll hash mismatch: $GD_HASH"; exit 1; }
echo "originals OK"

echo "== apt: wine (32-bit), unzip"
$SUDO dpkg --add-architecture i386
$SUDO apt-get update -y -qq
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wine wine32 wine64 unzip git python3-venv curl >/dev/null

echo "== wine prefix, MSVC 6.0, CMake (Windows)"
wineboot -i >/dev/null 2>&1 || true
wineserver -w || true
[ -d "$WINEPREFIX/drive_c/msvc" ] || git clone -q --depth 1 https://github.com/isledecomp/MSVC600-8168 "$WINEPREFIX/drive_c/msvc"
if [ ! -d "$WINEPREFIX/drive_c/cmake" ]; then
  curl -sSL -o /tmp/cmake.zip https://github.com/Kitware/CMake/releases/download/v3.26.6/cmake-3.26.6-windows-i386.zip
  unzip -q -o /tmp/cmake.zip -d "$WINEPREFIX/drive_c" && mv "$WINEPREFIX/drive_c/cmake-3.26.6-windows-i386" "$WINEPREFIX/drive_c/cmake"
fi
mkdir -p "$BUILD/tmp"
WTMP=$(winepath -w "$BUILD/tmp")
wine reg ADD 'HKCU\Environment' /v PATH /d 'C:\msvc\vc98\bin;C:\msvc\common\msdev98\bin;C:\msvc\common\tools\winnt;C:\msvc\common\tools;C:\cmake\bin;C:\windows\system32' /f >/dev/null
wine reg ADD 'HKCU\Environment' /v INCLUDE /d 'C:\msvc\vc98\include;C:\msvc\vc98\mfc\include;C:\msvc\vc98\atl\include' /f >/dev/null
wine reg ADD 'HKCU\Environment' /v LIB /d 'C:\msvc\vc98\lib;C:\msvc\vc98\mfc\lib' /f >/dev/null
wine reg ADD 'HKCU\Environment' /v TMP /d "$WTMP" /f >/dev/null
wine reg ADD 'HKCU\Environment' /v TEMP /d "$WTMP" /f >/dev/null
wineserver -w || true

echo "== python venv: reccmp, clang-format 22, libclang (ncc + modern-compiler check), capstone, pefile"
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q -r "$REPO/tools/requirements.txt" "clang-format>=22,<23" "clang==18.1.8" "libclang==18.1.1" pyyaml capstone pefile

echo "== lowercase include mirror for the libclang modern-compiler check"
mkdir -p "$HOME/vcinc"
for f in "$WINEPREFIX"/drive_c/msvc/VC98/Include/*; do ln -sfn "$f" "$HOME/vcinc/$(basename "$f" | tr 'A-Z' 'a-z')"; done

echo "== configure + double build (about 5 minutes)"
WREPO=$(winepath -w "$REPO"); WBUILD=$(winepath -w "$BUILD/build")
wine cmake -B "$WBUILD" "$WREPO" -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo > "$BUILD/configure.log" 2>&1
wine cmake --build "$WBUILD" > "$BUILD/build1.log" 2>&1 || true
wine cmake --build "$WBUILD" > "$BUILD/build2.log" 2>&1

echo "== reccmp config (Linux paths)"
cat > "$BUILD/build/reccmp-build.yml" <<EOF
project: '$REPO'
targets:
  GOLDP:
    path: '$BUILD/build/GolDP.dll'
    pdb: '$BUILD/build/GolDP.pdb'
  LEGORACERS:
    path: '$BUILD/build/LEGORacers.exe'
    pdb: '$BUILD/build/LEGORacers.pdb'
EOF
cat > "$REPO/reccmp-user.yml" <<EOF
targets:
  LEGORACERS:
    path: $ORIG/LEGORacers.exe
  GOLDP:
    path: $ORIG/GolDP.dll
EOF

echo "== tools -> ~/racers-tools (match branches do not contain cloud/)"
mkdir -p "$HOME/racers-tools" && cp "$REPO"/cloud/tools/* "$HOME/racers-tools/" && chmod +x "$HOME/racers-tools/"*.sh

cat > "$HOME/racers-env.sh" <<EOF
export WINEPREFIX=$WINEPREFIX WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
export RACERS_REPO=$REPO RACERS_BUILD=$BUILD RACERS_VENV=$VENV RACERS_ORIG=$ORIG
source $VENV/bin/activate
EOF

echo "== baseline scores"
source "$HOME/racers-env.sh"
cd "$BUILD/build"
reccmp-reccmp --target LEGORACERS --json "$BUILD/baseline-LR.json" 2>&1 | tail -4
reccmp-reccmp --target GOLDP --json "$BUILD/baseline-GD.json" 2>&1 | tail -4
echo "== done. Source ~/racers-env.sh in new shells; tools are in ~/racers-tools/."
