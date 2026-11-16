#!/usr/bin/env bash
#
# mayhem/build.sh — builds the sanitized VoxelCore engine library, one libFuzzer binary plus a
# run-once `-standalone` reproducer per harness (mayhem/harnesses/*.cpp), and the project's own gtest
# suite with normal flags (for mayhem/test.sh). Runs in /mayhem as `mayhem`; every dependency comes
# from apt -dev packages baked into the image, so a re-run needs no network.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs come from the ENVIRONMENT (overridable), with sane defaults — no if-statements,
# just parameter-expansion fallbacks. Default sanitizers are the base's ASan+UBSan (halting); override
# per build via the Dockerfile's `--build-arg SANITIZER_FLAGS="..."`.
# NB: SANITIZER_FLAGS uses `=` (no colon) on purpose — `=` only fills when the var is UNSET, so an
# explicit EMPTY value (`--build-arg SANITIZER_FLAGS=`) is honored and builds with NO sanitizers
# (useful when you want the program's natural crash / full backtrace, not an ASan report). The other
# knobs use `:=` (default on empty too). MAYHEM_JOBS sets build parallelism (falls back to nproc).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DEBUG_FLAGS carries DWARF debug info INDEPENDENTLY of the sanitizer off-switch (so an empty
# SANITIZER_FLAGS still yields DWARF symbols). DWARF MUST be < 4 (Mayhem triage can't read >=4); clang-19's
# plain `-g` emits DWARF-5, so `-gdwarf-3` is explicit. Apply $DEBUG_FLAGS to the fuzz/harness/standalone
# builds (NOT the test/oracle build). Rust/Go carry the same intent via their language flags below.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=-gdwarf-3}"
: "${GO_DEBUG_FLAGS:=-gcflags=all=-N -l}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
# COVERAGE_FLAGS: empty by default → no effect on the normal oracle build. Set it via the Dockerfile's
# `--build-arg COVERAGE_FLAGS="-fprofile-instr-generate -fcoverage-mapping"` to instrument the TEST
# build for source-coverage measurement (how much of the project the test suite actually exercises —
# a quality signal for the oracle; complements the anti-reward-hack sabotage check). APPEND it to the
# test build's compile+link flags in step 3 (NOT the fuzz build); after `test.sh` runs, merge with
# `llvm-profdata` and report with `llvm-cov`. Empty value is honored (`=`, not `:=`).
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS RUST_DEBUG_FLAGS GO_DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
OBJ="$(mktemp -d)"
trap 'rm -rf "$OBJ"' EXIT

HARNESSES="fuzz_json fuzz_binary_json fuzz_toml fuzz_yaml fuzz_xml fuzz_vcm fuzz_obj fuzz_vec3 fuzz_png fuzz_gzip fuzz_base64 fuzz_rle fuzz_commands fuzz_command_scheme fuzz_syntax"

# 1) The project itself (the whole engine library, VoxelCoreSrc), sanitized and SanCov-instrumented
#    so the harnesses cover the real code. Build dir is gitignored upstream (/cmake-build-**).
# Two UBSan checks are relaxed because they fire on benign-on-x86 patterns on nearly every input and
# would stop the fuzzers before they reach anything else: float-cast-overflow (BasicParser's
# static_cast<int64_t>(log10(0)+1) on every "N.0" number) and alignment (rle16 reads uint16_t at odd
# stream offsets). ASan and all other UBSan checks stay on and halting.
FUZZ_FLAGS="$SANITIZER_FLAGS -fno-sanitize=float-cast-overflow,alignment $DEBUG_FLAGS -O1 -fsanitize=fuzzer-no-link"
cmake -S . -B cmake-build-fuzz -G Ninja \
    -DCMAKE_BUILD_TYPE=None \
    -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS"
cmake --build cmake-build-fuzz --target VoxelCoreSrc -j"$MAYHEM_JOBS"
LIB="$SRC/cmake-build-fuzz/src/libVoxelCoreSrc.a"

# 2) Harnesses: libFuzzer binary + non-fuzzer run-once reproducer, both with LSan off.
DEPS="$(pkg-config --libs luajit vorbis vorbisfile glfw3 glew freetype2 openal libpng libcurl openssl zlib) -lpthread"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$OBJ/standalone_main.o"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$OBJ/lsan_off.o"
for h in $HARNESSES; do
    $CXX -std=c++17 $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -fsanitize=fuzzer-no-link -I"$SRC/src" \
        -c "$SRC/mayhem/harnesses/$h.cpp" -o "$OBJ/$h.o"
    $CXX $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE "$OBJ/$h.o" "$OBJ/lsan_off.o" "$LIB" $DEPS \
        -o "$SRC/$h"
    $CXX $SANITIZER_FLAGS $DEBUG_FLAGS "$OBJ/$h.o" "$OBJ/standalone_main.o" "$OBJ/lsan_off.o" "$LIB" $DEPS \
        -o "$SRC/$h-standalone"
done

# 3) The project's own test suites, with NORMAL flags (no sanitizers, no DWARF pin), in build/
#    (gitignored): the gtest suite (VoxelCoreTest) and upstream CI's engine-script suite, which needs
#    the engine executable (VoxelCore) and its runner (vctest). mayhem/test.sh only runs them.
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DVOXELENGINE_BUILD_TESTS=ON \
    -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build --target VoxelCoreTest VoxelCore vctest -j"$MAYHEM_JOBS"
