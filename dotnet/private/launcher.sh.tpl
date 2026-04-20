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
  test_dll="$(rlocation TEMPLATED_executable)"
  test_dir="$(dirname "$test_dll")"
  workspace_runfiles="${RUNFILES_DIR:-${test_dll}.runfiles}/_main"

  # Coverlet instruments by rewriting assemblies and PDBs in place. Bazel's
  # runfiles tree exposes them as symlinks to immutable build outputs, so any
  # write fails with "Permission denied". Materialize each first-party
  # assembly+PDB as a writable copy (sandbox is writable, originals are not)
  # so coverlet can do its in-place IL rewrite.
  if [ -d "$workspace_runfiles" ]; then
    while IFS= read -r f; do
      if [ -L "$f" ]; then
        target=$(readlink "$f")
        rm "$f"
        cp "$target" "$f"
        chmod u+w "$f"
      else
        chmod u+w "$f" 2>/dev/null || true
      fi
    done < <(find "$workspace_runfiles" \( -name '*.dll' -o -name '*.pdb' \) -print)
  fi

  # Bazel scatters each transitive .NET dependency under its own runfiles
  # directory rather than co-locating them next to the test DLL. Coverlet
  # instruments only the directory passed as <path> plus any directories
  # listed via --include-directory, so enumerate every workspace runfiles
  # dir that contains a .pdb (== our own first-party code) and add it.
  include_dir_args=()
  if [ -d "$workspace_runfiles" ]; then
    while IFS= read -r dir; do
      [ "$dir" = "$test_dir" ] && continue
      include_dir_args+=("--include-directory" "$dir")
    done < <(find "$workspace_runfiles" -name '*.pdb' -exec dirname {} \; | sort -u)
  fi

  exec $(rlocation TEMPLATED_dotnet) exec $(rlocation TEMPLATED_coverage_tool) \
    "$test_dir" \
    "${include_dir_args[@]}" \
    --target $(rlocation TEMPLATED_dotnet) \
    --targetargs "exec $test_dll $*" \
    --format lcov \
    --output "${COVERAGE_OUTPUT_FILE}"
else
  exec $(rlocation TEMPLATED_dotnet) exec $(rlocation TEMPLATED_executable) "$@"
fi
