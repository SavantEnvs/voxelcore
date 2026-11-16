#!/usr/bin/env bash
#
# mayhem/test.sh — runs VoxelCore's two upstream suites, both built by mayhem/build.sh into build/:
#  1) the gtest suite (test/**, build/test/VoxelCoreTest), counted from gtest's summary lines;
#  2) the engine-script suite upstream CI runs (`vctest -e build/VoxelCore -d dev/tests -u build`):
#     each dev/tests/*.lua runs under `VoxelCore --headless --test`, counted from vctest's
#     per-test [PASSED]/[FAILED] lines and its final "N test(s) passed, M test(s) failed" line.
# Both suites assert parsed values, encoded bytes and layouts; a neutered binary prints no summary
# and the script fails.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

RUNNER="$SRC/build/test/VoxelCoreTest"
[ -x "$RUNNER" ] || { echo "missing $RUNNER: mayhem/build.sh did not build the test suite" >&2; emit_ctrf gtest+vctest 0 1 0; exit 1; }

# test/ expects to run from its build dir (it reads ../../res); curltest needs the network.
out="$(cd "$SRC/build/test" && "$RUNNER" --gtest_filter='-curltest.*' 2>&1)"
echo "$out" | tail -n 25

num() { echo "$out" | sed -n "s/^\[ *$1 *\] \([0-9][0-9]*\) test.*/\1/p" | head -n1; }
passed="$(num PASSED)"; failed="$(num FAILED)"; skipped="$(num SKIPPED)"
ran="$(echo "$out" | sed -n 's/^\[=*\] \([0-9][0-9]*\) tests\? from .* ran\..*/\1/p' | tail -n1)"

if [ -z "$ran" ] || [ -z "$passed" ]; then
  echo "no gtest summary found: the suite did not run to completion" >&2
  emit_ctrf gtest+vctest 0 1 0; exit 1
fi
passed="${passed:-0}"; failed="${failed:-0}"; skipped="${skipped:-0}"

# 2) Engine-script suite. vctest has no filter option, so run it over a scratch copy of dev/tests
#    without network_http.lua, which downloads from the internet. network_tcp/network_udp stay: they
#    talk to localhost only and pass with no network. vctest resolves res/ from the cwd ($SRC).
VCTEST="$SRC/build/vctest/vctest"; ENGINE="$SRC/build/VoxelCore"
for b in "$VCTEST" "$ENGINE"; do
  [ -x "$b" ] || { echo "missing $b: mayhem/build.sh did not build it" >&2; emit_ctrf gtest+vctest "$passed" $((failed + 1)) "$skipped"; exit 1; }
done
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT
cp -r "$SRC/dev/tests" "$SCRATCH/tests"
rm -f "$SCRATCH/tests/network_http.lua"   # needs the internet (HTTP fetches to a public host)
mkdir -p "$SCRATCH/user"
vout="$("$VCTEST" -e "$ENGINE" -d "$SCRATCH/tests" -u "$SCRATCH/user" 2>&1)"
echo "$vout" | grep -E '^\[(PASSED|FAILED)\]|test\(s\) passed'
vsum="$(echo "$vout" | sed -n 's/^\([0-9][0-9]*\) test(s) passed, \([0-9][0-9]*\) test(s) failed$/\1 \2/p' | tail -n1)"
if [ -z "$vsum" ]; then
  echo "no vctest summary found: the engine-script suite did not run to completion" >&2
  echo "$vout" | tail -n 40 >&2
  emit_ctrf gtest+vctest "$passed" $((failed + 1)) "$skipped"; exit 1
fi
read -r vpassed vfailed <<<"$vsum"
# Cross-check the summary against the per-test lines, and require every script to have run.
vp_lines="$(echo "$vout" | grep -c '^\[PASSED\] ' || true)"
vf_lines="$(echo "$vout" | grep -c '^\[FAILED\] ' || true)"
vexpected="$(find "$SCRATCH/tests" -maxdepth 1 -name '*.lua' | wc -l)"
if [ "$vp_lines" != "$vpassed" ] || [ "$vf_lines" != "$vfailed" ] || [ $((vpassed + vfailed)) -ne "$vexpected" ]; then
  echo "vctest counts disagree (summary $vpassed/$vfailed, lines $vp_lines/$vf_lines, scripts $vexpected)" >&2
  vfailed=$(( vfailed > 0 ? vfailed : 1 ))
fi
[ "$vfailed" -eq 0 ] || echo "$vout" | grep -A40 '^\[OUTPUT\]' | head -n 200 >&2
emit_ctrf gtest+vctest $((passed + vpassed)) $((failed + vfailed)) "$skipped"
