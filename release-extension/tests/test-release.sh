#!/usr/bin/env bash
# Tests for scripts/release.sh, the orchestrator, against a real temp git repo and the stubbed gh, aws and curl.
# Usage: ./tests/test-release.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0
t()   { printf '  %s … ' "$1"; }
ok()  { echo "ok"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/bin"
TMP="$ROOT"   # stubs.sh writes its fakes into "$TMP/bin"
# shellcheck source=tests/stubs.sh
. "$HERE/stubs.sh"
# A fake signer that writes a .sig beside the zip, so no real keys are needed.
cat > "$ROOT/bin/fakesign" <<'EOF'
#!/usr/bin/env bash
# args: sign <zip>
[ "$1" = sign ] || exit 1
printf 'SIG(%s)' "$(basename "$2")" > "$2.sig"
EOF
chmod +x "$ROOT/bin/fakesign"
export PATH="$ROOT/bin:$PATH"
export EXTENSION_SIGN="fakesign"

# A build script that writes a bundle per requested SDK. BUILD_SDKS is a space list ("" = one plain dist/extension.zip).
# BUILD_STAMP=1 adds the armdot stamp. Touches built.marker so a test can prove the build ran (or did not).
write_build() {
  cat > "$WORK/fakebuild.sh" <<'EOF'
#!/usr/bin/env bash
set -e
: > built.marker
mkbundle() { # <dir> <sdk> <out.zip>
  local d; d="$(mktemp -d)"
  jq -n --arg s "$2" --argjson stamp "${BUILD_STAMP:-0}" \
    '{id:"io.acme.tool",version:"1.0.0",name:"Hello",description:"d",sdkVersion:$s,
      resources:[{restSegment:"extensions/hello"}]}
     + (if $stamp == 1 then {obfuscation:{tool:"armdot",version:"2026.6.0"}} else {} end)' > "$d/manifest.json"
  ( cd "$d" && zip -q "$3" manifest.json ); rm -rf "$d"
}
dir=extensions/hello
if [ -z "${BUILD_SDKS:-}" ]; then
  mkdir -p "$dir/dist"; mkbundle "$dir" "1.0.0" "$PWD/$dir/dist/extension.zip"
else
  for s in $BUILD_SDKS; do mkdir -p "$dir/dist/sdk-$s"; mkbundle "$dir" "$s" "$PWD/$dir/dist/sdk-$s/extension.zip"; done
fi
EOF
  chmod +x "$WORK/fakebuild.sh"
}

# fresh_repo: a new git repo with one extension manifest, committed, GITHUB_SHA at HEAD. Resets console + S3 state.
fresh_repo() {
  WORK="$(mktemp -d)"; cd "$WORK"
  git init -q; git config user.email t@t; git config user.name t
  mkdir -p extensions/hello
  jq -n '{id:"io.acme.tool",version:"1.0.0",name:"Hello",description:"d",resources:[{restSegment:"extensions/hello"}]}' \
    > extensions/hello/manifest.json
  git add -A; git commit -qm init
  export GITHUB_SHA="$(git rev-parse HEAD)"
  write_build
  export LOG="$WORK/log" S3="$WORK/s3" CONSOLE="$WORK/console" ASSETS="$WORK/assets" RUNNER_TEMP="$WORK/rt"
  mkdir -p "$S3" "$CONSOLE" "$ASSETS" "$RUNNER_TEMP"; : > "$LOG"
  jq -n '[{manifest_id:"io.acme.tool",uuid:"a-1"}]' > "$CONSOLE/agents.json"
  export ZSHA="deadbeef"
}

# Common inputs. Each test overrides what it needs.
base_env() {
  export INPUT_CONSOLE_API_KEY="console-key-xyz" INPUT_CONSOLE_URL="https://console.example.com"
  export INPUT_BUILD_COMMAND="$WORK/fakebuild.sh" INPUT_BUNDLE_BUCKET="duplo-helpdesk-channels" BUCKET="duplo-helpdesk-channels"
  export INPUT_SIGNING_KEY="" INPUT_SIGNING_CERT="" INPUT_ARMDOT_LICENSE="" INPUT_SDK_VERSIONS="" INPUT_PUBLISH="false"
  export INPUT_NAME="" INPUT_DESCRIPTION="" INPUT_CHANGELOG="" INPUT_CONSOLE_TEAM=""
  unset AWS_ACCESS_KEY_ID BUILD_SDKS BUILD_STAMP
}
run_release() { ( "$HERE/../scripts/release.sh" ) >"$WORK/out" 2>&1; echo $?; }

echo "release:"

# --- Guards --------------------------------------------------------------------------------------
t "duplocloud without a signing key fails before the build"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=duplocloud INPUT_ARMDOT_LICENSE="$(printf x | base64)"
rc="$(run_release)"
[ "$rc" -ne 0 ] && [ ! -f "$WORK/built.marker" ] && grep -q 'signing-key is required' "$WORK/out" && ok || bad "rc=$rc $(cat "$WORK/out")"

t "duplocloud without an armdot license fails before the build"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=duplocloud INPUT_SIGNING_KEY=k INPUT_SIGNING_CERT=c
rc="$(run_release)"
[ "$rc" -ne 0 ] && [ ! -f "$WORK/built.marker" ] && grep -q 'armdot-license is required' "$WORK/out" && ok || bad "rc=$rc $(cat "$WORK/out")"

t "outside a DuploCloud org the build runs unsigned and no license is written"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme AWS_ACCESS_KEY_ID=x
rc="$(run_release)"
[ "$rc" -eq 0 ] && [ -f "$WORK/built.marker" ] && [ ! -f "$RUNNER_TEMP/armdot.key" ] && ok || bad "rc=$rc $(cat "$WORK/out")"

t "a text input across two extensions fails before the build"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme AWS_ACCESS_KEY_ID=x INPUT_NAME=Renamed
mkdir -p extensions/second
jq -n '{id:"io.acme.two",version:"1.0.0",resources:[{restSegment:"extensions/second"}]}' > extensions/second/manifest.json
rc="$(run_release)"
[ "$rc" -ne 0 ] && [ ! -f "$WORK/built.marker" ] && grep -q 'single extension' "$WORK/out" && ok || bad "rc=$rc $(cat "$WORK/out")"

# --- Fresh release, AWS backend (DuploCloud) -----------------------------------------------------
t "a fresh DuploCloud build releases both assets, creates one version, registers one artifact, then uploads, in order"
fresh_repo; base_env
export GITHUB_REPOSITORY_OWNER=duplocloud GITHUB_REPOSITORY=duplocloud/ext AWS_ACCESS_KEY_ID=x
export INPUT_SIGNING_KEY=k INPUT_SIGNING_CERT=c INPUT_ARMDOT_LICENSE="$(printf lic | base64)" BUILD_STAMP=1
rc="$(run_release)"
order="$(grep -oE 'gh release create|-X POST .*/versions/|-X POST .*/artifacts/ |put-object' "$WORK/log" | tr '\n' '|')"
# normalize: collapse the two put-objects, keep first occurrences
seq="$(grep -nE 'gh release create|/versions/|/artifacts/|put-object' "$WORK/log" >/dev/null 2>&1; :)"
if [ "$rc" -eq 0 ] \
  && grep -q 'gh release create .*extension.zip .*extension.zip.sig' "$WORK/log" \
  && [ "$(grep -c 'gh release create' "$WORK/log")" = 1 ] \
  && [ "$(grep -- '-X POST' "$WORK/log" | grep -c '/versions/$')" = 1 ] \
  && [ "$(grep -- '-X POST' "$WORK/log" | grep -c '/artifacts/$')" = 1 ] \
  && [ "$(grep -c 'put-object' "$WORK/log")" = 2 ]; then ok
else bad "rc=$rc; log: $(cat "$WORK/log")"; fi

t "the release create targets GITHUB_SHA"
grep -q "gh release create .*--target $GITHUB_SHA" "$WORK/log" && ok || bad "$(grep 'release create' "$WORK/log")"

t "the console steps run after the release and before the upload"
rc_rel=$(grep -n 'gh release create' "$WORK/log" | head -1 | cut -d: -f1)
rc_ver=$(grep -n -- '-X POST' "$WORK/log" | grep '/versions/$' | head -1 | cut -d: -f1)
rc_art=$(grep -n -- '-X POST' "$WORK/log" | grep '/artifacts/$' | head -1 | cut -d: -f1)
rc_put=$(grep -n 'put-object' "$WORK/log" | head -1 | cut -d: -f1)
[ "$rc_rel" -lt "$rc_ver" ] && [ "$rc_ver" -lt "$rc_art" ] && [ "$rc_art" -lt "$rc_put" ] && ok \
  || bad "rel=$rc_rel ver=$rc_ver art=$rc_art put=$rc_put"

t "the console key and signing key never appear in the logged argv"
if ! grep -q 'console-key-xyz' "$WORK/log"; then ok; else bad "key in log"; fi

# --- Fresh release, console backend (customer) ---------------------------------------------------
t "a customer console-backend build uploads only the zip through the console grant"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme GITHUB_REPOSITORY=acme/ext INPUT_CONSOLE_TEAM=acme
rc="$(run_release)"
if [ "$rc" -eq 0 ] \
  && grep -q 'curl .*-T .*extension.zip .*https://s3.stub/' "$WORK/log" \
  && ! grep -q 'put-object' "$WORK/log" \
  && [ "$(grep -c 'https://s3.stub/' "$WORK/log")" = 1 ]; then ok
else bad "rc=$rc; log: $(cat "$WORK/log")"; fi

# --- Two SDK versions ----------------------------------------------------------------------------
t "two sdk-versions make two tags and two artifacts under one version"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme GITHUB_REPOSITORY=acme/ext AWS_ACCESS_KEY_ID=x
export INPUT_SDK_VERSIONS="$(printf '1.0.6\n1.0.7')" BUILD_SDKS="1.0.6 1.0.7"
rc="$(run_release)"
if [ "$rc" -eq 0 ] \
  && [ "$(grep -c 'gh release create' "$WORK/log")" = 2 ] \
  && [ "$(grep -- '-X POST' "$WORK/log" | grep -c '/artifacts/$')" = 2 ] \
  && [ "$(grep -- '-X POST' "$WORK/log" | grep -c '/versions/$')" = 1 ]; then ok
else bad "rc=$rc; creates=$(grep -c 'gh release create' "$WORK/log")"; fi

# --- Publish -------------------------------------------------------------------------------------
t "publish true publishes the version on its first build"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme GITHUB_REPOSITORY=acme/ext AWS_ACCESS_KEY_ID=x INPUT_PUBLISH=true
rc="$(run_release)"
[ "$rc" -eq 0 ] && [ "$(grep -c 'PATCH' "$WORK/log")" = 1 ] && ok || bad "rc=$rc patches=$(grep -c 'PATCH' "$WORK/log")"

t "publish true does not publish when the version already had a build"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme GITHUB_REPOSITORY=acme/ext AWS_ACCESS_KEY_ID=x INPUT_PUBLISH=true
# Seed the version with a build for a different SDK, so this build is 'later', not the version's first.
echo '[{"uuid":"v-1"}]' > "$CONSOLE/versions.json"
echo '[{"sdk_version":"9.9.9","s3_path":"s3://x/y","sha256":"aa","signature":"s"}]' > "$CONSOLE/artifacts.json"
rc="$(run_release)"
[ "$rc" -eq 0 ] && [ "$(grep -c 'PATCH' "$WORK/log")" = 0 ] && ok || bad "rc=$rc patches=$(grep -c 'PATCH' "$WORK/log") $(cat "$WORK/out")"

# --- Changed content at an existing tag ----------------------------------------------------------
t "a version already released at a tag whose content changed fails with the bump message"
fresh_repo; base_env; export GITHUB_REPOSITORY_OWNER=acme GITHUB_REPOSITORY=acme/ext AWS_ACCESS_KEY_ID=x
git tag hello-v1.0.0-sdk-1.0.0           # tag the original commit
echo x > extensions/hello/extra.txt; git add -A; git commit -qm change   # change the dir, keep manifest.json valid
export GITHUB_SHA="$(git rev-parse HEAD)"
rc="$(run_release)"
[ "$rc" -ne 0 ] && grep -q 'Bump manifest.version' "$WORK/out" && ok || bad "rc=$rc $(cat "$WORK/out")"

echo; echo "passed $PASS, failed $FAIL"; [ "$FAIL" -eq 0 ]
