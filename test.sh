#!/usr/bin/env bash
# Runs the test suite. Extra arguments go to `swift test`, e.g.
#   ./test.sh --filter MatchRowPresentationTests
#
# Why this script exists: on a machine with only the Command Line Tools (no
# full Xcode), Swift Testing ships in the CLT's Developer directory, which
# `swift test` doesn't search, so plain `swift test` fails with
# "no such module 'Testing'". The flags below add that directory to the
# compiler's and linker's framework search paths and to the runtime search
# paths. They are only added when the active developer directory is the
# Command Line Tools, so with full Xcode selected (which may also have the CLT
# installed) this is plain `swift test` and can't mix two copies of Testing.
set -euo pipefail
cd "$(dirname "$0")"

F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib

flags=()
if [[ "$(xcode-select -p 2>/dev/null || true)" == /Library/Developer/CommandLineTools && -d "$F" ]]; then
  flags+=(-Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F"
          -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L")
fi

swift test ${flags[@]+"${flags[@]}"} "$@"
