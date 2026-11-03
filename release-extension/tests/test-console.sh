#!/usr/bin/env bash
# Tests for scripts/lib/console.sh against the stubbed console. Usage: ./tests/test-console.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0
t()   { printf '  %s … ' "$1"; }
ok()  { echo "ok"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
# shellcheck source=tests/stubs.sh
. ./stubs.sh
export PATH="$TMP/bin:$PATH"
# shellcheck source=../scripts/lib/console.sh
. ../scripts/lib/console.sh || { echo "scripts/lib/console.sh not found"; exit 1; }

export RUNNER_TEMP="$TMP" LOG="$TMP/log" S3="$TMP/s3" CONSOLE="$TMP/console" BUCKET="duplo-helpdesk-channels"
export CONSOLE_API_KEY="secret-key-value" CONSOLE_URL="https://console.example.com"
mkdir -p "$S3" "$CONSOLE"

reset() { : > "$LOG"; rm -f "$CONSOLE"/versions.json "$CONSOLE"/artifacts.json "$CONSOLE"/published "$CONSOLE"/raced; }
agents_fixture() {
  jq -n '[{manifest_id:"io.acme.one",uuid:"a-1"},{manifest_id:"io.acme.two",uuid:"a-2"},{manifest_id:"io.acme.tool",uuid:"a-3"}]' \
    > "$CONSOLE/agents.json"
}

echo "console:"

# --- agent_uuid ----------------------------------------------------------------------------------
t "agent_uuid finds an agent on the second page"
reset; agents_fixture; unset CONSOLE_TEAM
out="$(agent_uuid io.acme.tool 2>&1)"
[ "$out" = "a-3" ] && ok || bad "$out"

t "agent_uuid fails and says to create the agent when none matches"
reset; agents_fixture
out="$(agent_uuid io.acme.missing 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && grep -q 'Create the agent' <<<"$out" && ok || bad "rc=$rc $out"

t "agent_uuid fails naming view_agents on a staff 403"
reset; agents_fixture
out="$( ( export CONSOLE_AGENTS_403=1; agent_uuid io.acme.tool ) 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && grep -q 'view_agents' <<<"$out" && ok || bad "rc=$rc $out"

# --- routes --------------------------------------------------------------------------------------
all_urls_under() { local u; while read -r u; do case "$u" in *"$1"*) ;; *) return 1 ;; esac; done < <(grep -oE 'https://[^ ]+' "$LOG"); }

t "team routes sit under /a/<team>/agents/api/agents/ and never /api/extensions/"
reset; agents_fixture
( export CONSOLE_TEAM=acme; agent_uuid io.acme.tool >/dev/null 2>&1; ensure_version a-3 1.0.0 '{"name":"n","description":"","changelog":""}' >/dev/null 2>&1 )
if all_urls_under "/a/acme/agents/api/agents/" && ! grep -q '/api/extensions/' "$LOG"; then ok; else bad "$(grep -oE 'https://[^ ]+' "$LOG")"; fi

t "staff routes sit under /api/agents/ and never /api/extensions/"
reset; agents_fixture; unset CONSOLE_TEAM
( agent_uuid io.acme.tool >/dev/null 2>&1; ensure_version a-3 1.0.0 '{"name":"n","description":"","changelog":""}' >/dev/null 2>&1 )
if all_urls_under "/api/agents/" && ! grep -q '/api/extensions/' "$LOG"; then ok; else bad "$(grep -oE 'https://[^ ]+' "$LOG")"; fi

# --- ensure_version ------------------------------------------------------------------------------
t "ensure_version creates once and returns the same uuid on a second call"
reset; unset CONSOLE_TEAM
v1="$(ensure_version a-3 1.0.0 '{"name":"Hello","description":"d","changelog":"c"}' 2>&1)"
v2="$(ensure_version a-3 1.0.0 '{"name":"Hello","description":"d","changelog":"c"}' 2>&1)"
posts="$(grep -- '-X POST' "$LOG" | grep -c '/versions/' || true)"
[ "$v1" = "v-1" ] && [ "$v2" = "v-1" ] && [ "$posts" = 1 ] && ok || bad "v1=$v1 v2=$v2 posts=$posts"

t "the created version body carries the three text fields"
reset
ensure_version a-3 1.0.0 '{"name":"Hello","description":"d","changelog":"c"}' >/dev/null 2>&1
line="$(grep -- '-X POST' "$LOG" | grep '/versions/' | head -1)"
if grep -q '"name":"Hello"' <<<"$line" && grep -q '"description":"d"' <<<"$line" && grep -q '"changelog":"c"' <<<"$line"; then ok; else bad "$line"; fi

# --- artifact_state ------------------------------------------------------------------------------
art='{"sdk_version":"1.0.0","s3_path":"s3://b/k","sha256":"ABCDEF","signature":"sig"}'
t "artifact_state prints none before any build is registered"
reset
[ "$(artifact_state a-3 v-1 1.0.0 "$art" 2>&1)" = none ] && ok || bad "expected none"

t "artifact_state prints match for the registered build"
reset; register_artifact a-3 v-1 "$art" >/dev/null 2>&1
[ "$(artifact_state a-3 v-1 1.0.0 "$art" 2>&1)" = match ] && ok || bad "expected match"

t "artifact_state prints differs when the signature differs"
diffart='{"sdk_version":"1.0.0","s3_path":"s3://b/k","sha256":"ABCDEF","signature":"other"}'
[ "$(artifact_state a-3 v-1 1.0.0 "$diffart" 2>&1)" = differs ] && ok || bad "expected differs"

# --- register_artifact ---------------------------------------------------------------------------
t "register_artifact prints first then later"
reset
r1="$(register_artifact a-3 v-1 "$art" 2>&1)"
r2="$(register_artifact a-3 v-1 '{"sdk_version":"1.0.7","s3_path":"s3://b/k2","sha256":"BEEF","signature":"s2"}' 2>&1)"
[ "$r1" = first ] && [ "$r2" = later ] && ok || bad "r1=$r1 r2=$r2"

# --- publish_version -----------------------------------------------------------------------------
t "publish_version sends one PATCH when the version is unpublished"
reset
publish_version a-3 v-1 >/dev/null 2>&1
[ "$(grep -c 'PATCH' "$LOG")" = 1 ] && ok || bad "patches=$(grep -c 'PATCH' "$LOG")"

t "publish_version sends no PATCH when the version is already published"
reset; echo '{"is_published":true}' > "$CONSOLE/published"
publish_version a-3 v-1 >/dev/null 2>&1
[ "$(grep -c 'PATCH' "$LOG")" = 0 ] && ok || bad "patches=$(grep -c 'PATCH' "$LOG")"

# --- key handling --------------------------------------------------------------------------------
t "the API key never appears in the logged argv and the header file held it"
reset; agents_fixture; unset CONSOLE_TEAM
agent_uuid io.acme.tool >/dev/null 2>&1
if ! grep -q "$CONSOLE_API_KEY" "$LOG" && grep -q 'HEADER_FILE_KEY=yes' "$LOG"; then ok; else bad "key handling"; fi

echo; echo "passed $PASS, failed $FAIL"; [ "$FAIL" -eq 0 ]
