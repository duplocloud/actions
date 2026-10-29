#!/usr/bin/env bash
# Bundle discovery, the build-output check, and the version's text fields. Sourced by release.sh and the tests.
# No side effects on source: every function is called explicitly.

# The charset every id, version and sdkVersion must match, so each is safe in a tag and an S3 key.
_bundles_token_re='^[A-Za-z0-9][A-Za-z0-9._-]*$'
# A bundle over this many bytes is refused, matching the devkit's EXTENSION_MAX_BYTES default.
_bundles_max_bytes="${EXTENSION_MAX_BYTES:-268435456}"

# extension_dirs: print each directory holding a manifest.json, across the devkit's three layouts.
extension_dirs() {
  local m dir
  shopt -s nullglob
  for m in extensions/*/manifest.json extension/*/manifest.json extension/manifest.json; do
    [ -f "$m" ] || continue
    dir="$(dirname "$m")"
    printf '%s\n' "$dir"
  done
}

# bundles_for <dir> <sdk-versions>: print the bundle zip paths the build must have produced. One
# <dir>/dist/sdk-<v>/extension.zip per non-empty version line, else <dir>/dist/extension.zip. Exit 1 naming each
# missing path when a listed version's zip is absent, since that means the build ignored DUPLO_SDK_VERSIONS.
bundles_for() {
  local dir="$1" versions="$2" v path missing=0
  if [ -z "$versions" ]; then
    path="$dir/dist/extension.zip"
    if [ ! -f "$path" ]; then
      echo "::error::$dir — no dist/extension.zip (the build produced nothing)." >&2
      return 1
    fi
    printf '%s\n' "$path"
    return 0
  fi
  local paths=()
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    path="$dir/dist/sdk-$v/extension.zip"
    paths+=("$path")
    if [ ! -f "$path" ]; then
      echo "::error::$dir — the build did not produce $path." >&2
      missing=1
    fi
  done <<<"$versions"
  if [ "$missing" -ne 0 ]; then
    echo "::error::$dir — upgrade the devkit so its build honors DUPLO_SDK_VERSIONS." >&2
    return 1
  fi
  printf '%s\n' "${paths[@]}"
}

# check_bundle <zip> <require-stamp: 0|1>: exit 1 with ::error:: on a malformed build output. With the second
# argument 1, also require the armdot obfuscation stamp.
check_bundle() {
  local zip="$1" require_stamp="$2" m id version sdk tool bytes
  m="$(unzip -p "$zip" manifest.json 2>/dev/null)" || { echo "::error::$zip — cannot read manifest.json." >&2; return 1; }
  if ! jq -e '(.resources // []) | length > 0' >/dev/null 2>&1 <<<"$m"; then
    echo "::error::$zip — the manifest declares no resource, so the host refuses the bundle." >&2
    return 1
  fi
  bytes="$(wc -c < "$zip")"
  if [ "$bytes" -gt "$_bundles_max_bytes" ]; then
    echo "::error::$zip — the bundle is over $_bundles_max_bytes bytes, which the release job refuses to publish." >&2
    return 1
  fi
  id="$(jq -r '.id // empty' <<<"$m")"
  version="$(jq -r '.version // empty' <<<"$m")"
  sdk="$(jq -r '.sdkVersion // empty' <<<"$m")"
  if [ -z "$sdk" ]; then
    echo "::error::$zip — the bundle carries no sdkVersion. Build it with scripts/build-extension.sh." >&2
    return 1
  fi
  local field val
  for field in id version sdk; do
    val="${!field}"
    if ! [[ "$val" =~ $_bundles_token_re ]]; then
      echo "::error::$zip — $field '$val' is outside $_bundles_token_re." >&2
      return 1
    fi
  done
  if [ "$require_stamp" = 1 ]; then
    tool="$(jq -r '.obfuscation.tool // empty' <<<"$m")"
    if [ "$tool" != armdot ]; then
      echo "::error::$zip — the bundle is not obfuscated (obfuscation.tool='$tool'). Set armdot-license, or upgrade the devkit." >&2
      return 1
    fi
  fi
}

# version_fields <zip>: print {name, description, changelog}, each the matching INPUT_* when set, else the
# manifest's value, else the fallback (name falls back to id, the other two to empty).
version_fields() {
  local zip="$1" m name description changelog
  m="$(unzip -p "$zip" manifest.json 2>/dev/null)" || { echo "::error::$zip — cannot read manifest.json." >&2; return 1; }
  name="${INPUT_NAME:-$(jq -r '.name // .id' <<<"$m")}"
  description="${INPUT_DESCRIPTION:-$(jq -r '.description // ""' <<<"$m")}"
  changelog="${INPUT_CHANGELOG:-}"
  jq -cn --arg n "$name" --arg d "$description" --arg c "$changelog" '{name:$n,description:$d,changelog:$c}'
}

# check_text_inputs <dir-count>: exit 1 when any of INPUT_NAME, INPUT_DESCRIPTION, INPUT_CHANGELOG is set and the
# repository holds more than one extension, since one text value cannot label several agents.
check_text_inputs() {
  local count="$1"
  if [ "$count" -le 1 ]; then return 0; fi
  if [ -n "${INPUT_NAME:-}" ] || [ -n "${INPUT_DESCRIPTION:-}" ] || [ -n "${INPUT_CHANGELOG:-}" ]; then
    echo "::error::name, description and changelog apply to a single extension, but this repository has $count. Set them in each manifest.json instead." >&2
    return 1
  fi
}
