#!/usr/bin/env bash
# Tests for scripts/lib/bundles.sh: extension_dirs, bundles_for, check_bundle, version_fields, check_text_inputs.
# Usage: ./tests/test-bundles.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0
t()   { printf '  %s … ' "$1"; }
ok()  { echo "ok"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# shellcheck source=../scripts/lib/bundles.sh
. ../scripts/lib/bundles.sh || { echo "scripts/lib/bundles.sh not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# mkbundle <out.zip> <jq-manifest-expr>: write a zip holding only the manifest built by `jq -n <expr>`.
mkbundle() {
  local out="$1" expr="$2" d; d="$(mktemp -d)"
  jq -n "$expr" > "$d/manifest.json"
  ( cd "$d" && zip -q "$out" manifest.json )
  rm -rf "$d"
}

echo "bundles:"

# --- bundles_for ---------------------------------------------------------------------------------
t "bundles_for lists each version's sdk path when all are present"
d="$TMP/e1"; mkdir -p "$d/dist/sdk-1.0.6" "$d/dist/sdk-1.0.7"
: > "$d/dist/sdk-1.0.6/extension.zip"; : > "$d/dist/sdk-1.0.7/extension.zip"
out="$(bundles_for "$d" "$(printf '1.0.6\n1.0.7')" 2>&1)"
if [ "$out" = "$(printf '%s/dist/sdk-1.0.6/extension.zip\n%s/dist/sdk-1.0.7/extension.zip' "$d" "$d")" ]; then ok; else bad "$out"; fi

t "bundles_for fails and names the devkit upgrade when a listed version's zip is absent"
d="$TMP/e2"; mkdir -p "$d/dist"; : > "$d/dist/extension.zip"
out="$(bundles_for "$d" "$(printf '1.0.6\n1.0.7')" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'upgrade the devkit' <<<"$out"; then ok; else bad "rc=$rc $out"; fi

t "bundles_for lists the single bundle for an empty version list"
d="$TMP/e3"; mkdir -p "$d/dist"; : > "$d/dist/extension.zip"
out="$(bundles_for "$d" "" 2>&1)"
if [ "$out" = "$d/dist/extension.zip" ]; then ok; else bad "$out"; fi

# --- check_bundle --------------------------------------------------------------------------------
good='{id:"io.acme.tool",version:"1.0.0",sdkVersion:"1.0.0",resources:[{restSegment:"extensions/x"}],obfuscation:{tool:"armdot",version:"2026.6.0"}}'
nostamp='{id:"io.acme.tool",version:"1.0.0",sdkVersion:"1.0.0",resources:[{restSegment:"extensions/x"}]}'

t "check_bundle passes a good obfuscated bundle when the stamp is required"
mkbundle "$TMP/good.zip" "$good"
check_bundle "$TMP/good.zip" 1 >/dev/null 2>&1 && ok || bad "rejected a good bundle"

t "check_bundle fails an unstamped bundle when the stamp is required"
mkbundle "$TMP/nostamp.zip" "$nostamp"
check_bundle "$TMP/nostamp.zip" 1 >/dev/null 2>&1 && bad "accepted an unstamped bundle" || ok

t "check_bundle passes an unstamped bundle when the stamp is not required"
check_bundle "$TMP/nostamp.zip" 0 >/dev/null 2>&1 && ok || bad "rejected an unstamped bundle with stamp off"

t "check_bundle fails a manifest with no resources"
mkbundle "$TMP/nores.zip" '{id:"io.acme.tool",version:"1.0.0",sdkVersion:"1.0.0",resources:[]}'
check_bundle "$TMP/nores.zip" 0 >/dev/null 2>&1 && bad "accepted an empty resources list" || ok

t "check_bundle fails an id outside the allowed charset"
mkbundle "$TMP/badid.zip" '{id:"a/b",version:"1.0.0",sdkVersion:"1.0.0",resources:[{restSegment:"extensions/x"}]}'
check_bundle "$TMP/badid.zip" 0 >/dev/null 2>&1 && bad "accepted id a/b" || ok

t "check_bundle fails a missing sdkVersion"
mkbundle "$TMP/nosdk.zip" '{id:"io.acme.tool",version:"1.0.0",resources:[{restSegment:"extensions/x"}]}'
check_bundle "$TMP/nosdk.zip" 0 >/dev/null 2>&1 && bad "accepted a missing sdkVersion" || ok

# --- version_fields ------------------------------------------------------------------------------
t "version_fields defaults from the manifest when no inputs are set"
mkbundle "$TMP/vf.zip" '{id:"io.acme.tool",version:"1.0.0",sdkVersion:"1.0.0",name:"Hello",description:"d",resources:[{restSegment:"extensions/x"}]}'
out="$(unset INPUT_NAME INPUT_DESCRIPTION INPUT_CHANGELOG; version_fields "$TMP/vf.zip" 2>&1)"
if [ "$out" = '{"name":"Hello","description":"d","changelog":""}' ]; then ok; else bad "$out"; fi

t "version_fields takes INPUT_NAME over the manifest"
out="$(unset INPUT_DESCRIPTION INPUT_CHANGELOG; INPUT_NAME=X version_fields "$TMP/vf.zip" 2>&1)"
if [ "$(jq -r .name <<<"$out")" = "X" ]; then ok; else bad "$out"; fi

# --- check_text_inputs ---------------------------------------------------------------------------
t "check_text_inputs fails a text input across more than one extension"
( unset INPUT_DESCRIPTION INPUT_CHANGELOG; INPUT_NAME=X check_text_inputs 2 ) >/dev/null 2>&1 && bad "allowed a name for 2 extensions" || ok

t "check_text_inputs allows a text input for a single extension"
( unset INPUT_DESCRIPTION INPUT_CHANGELOG; INPUT_NAME=X check_text_inputs 1 ) >/dev/null 2>&1 && ok || bad "refused a name for 1 extension"

echo; echo "passed $PASS, failed $FAIL"; [ "$FAIL" -eq 0 ]
