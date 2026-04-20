#!/usr/bin/env bash
# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---
runfiles_export_envvars

set -o pipefail -o errexit -o nounset

export DOTNET_MULTILEVEL_LOOKUP="false"
export DOTNET_NOLOGO="1"
export DOTNET_CLI_TELEMETRY_OPTOUT="1"
export DOTNET_ROOT="$(dirname $(rlocation TEMPLATED_dotnet))"

# Coverage support: when Bazel runs `bazel coverage`, it sets COVERAGE=1 and
# expects the test action to write LCOV data to $COVERAGE_OUTPUT_FILE. If the
# dotnet toolchain has been configured with a coverage_tool (a coverlet.console
# DLL), route the test invocation through `dotnet exec coverlet.dll`; otherwise
# fall back to the normal launcher path.
if [ "TEMPLATED_coverage_enabled" = "1" ] && [ -n "${COVERAGE:-}" ]; then
  # Coverlet's positional <path> selects what to instrument. Passing the test
  # DLL alone instruments only that assembly, so transitive code under test
  # shows 0% coverage. Pass the directory containing the test DLL instead so
  # coverlet picks up every assembly with a sibling .pdb (which is everything
  # we ship to runfiles).
  test_dll="$(rlocation TEMPLATED_executable)"
  exec $(rlocation TEMPLATED_dotnet) exec $(rlocation TEMPLATED_coverage_tool) \
    "$(dirname "$test_dll")" \
    --target $(rlocation TEMPLATED_dotnet) \
    --targetargs "exec $test_dll $*" \
    --format lcov \
    --output "${COVERAGE_OUTPUT_FILE}"
else
  exec $(rlocation TEMPLATED_dotnet) exec $(rlocation TEMPLATED_executable) "$@"
fi
