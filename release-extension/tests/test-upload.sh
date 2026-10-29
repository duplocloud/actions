#!/usr/bin/env bash
# Tests for scripts/lib/upload.sh: upload_backend, aws_put_once, console_put_once. Usage: ./tests/test-upload.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0
t()   { printf '  %s … ' "$1"; }
ok()  { echo "ok"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
# shellcheck source=tests/stubs.sh
. ./stubs.sh   # aws + gh stubs; the curl stub below replaces the console one for the PUT backend
export PATH="$TMP/bin:$PATH"
export RUNNER_TEMP="$TMP" LOG="$TMP/log" S3="$TMP/s3"; mkdir -p "$S3"

# A curl stub for the console upload PUT: writes PUT_BODY to -o and prints PUT_CODE as -w would.
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> "$LOG"
out=/dev/stdout; while [ $# -gt 0 ]; do case "$1" in -o) out=$2; shift ;; esac; shift; done
printf '%s' "${PUT_BODY:-{\"detail\":\"stub body\"}}" > "$out"
printf '%s' "${PUT_CODE:-200}"
EOF
chmod +x "$TMP/bin/curl"

# shellcheck source=../scripts/lib/upload.sh
. ../scripts/lib/upload.sh || { echo "scripts/lib/upload.sh not found"; exit 1; }

echo "upload:"

# --- upload_backend ------------------------------------------------------------------------------
t "upload_backend is aws when AWS_ACCESS_KEY_ID is set"
[ "$(AWS_ACCESS_KEY_ID=x upload_backend)" = aws ] && ok || bad "expected aws"

t "upload_backend is console without AWS_ACCESS_KEY_ID"
[ "$(unset AWS_ACCESS_KEY_ID; upload_backend)" = console ] && ok || bad "expected console"

# --- aws_put_once --------------------------------------------------------------------------------
t "aws_put_once uploads a fresh object"
: > "$LOG"; rm -f "$S3"/*; printf 'bytes-A' > "$TMP/a.zip"
aws_put_once "$TMP/a.zip" bkt bundles/a/extension.zip >/dev/null 2>&1 && [ -f "$S3/bundles_a_extension.zip" ] && ok || bad "fresh put"

t "aws_put_once treats a 412 with identical bytes as done"
: > "$LOG"
aws_put_once "$TMP/a.zip" bkt bundles/a/extension.zip >/dev/null 2>&1 && ok || bad "412 identical"

t "aws_put_once fails a 412 with different bytes"
: > "$LOG"; printf 'bytes-B' > "$TMP/b.zip"
out="$(aws_put_once "$TMP/b.zip" bkt bundles/a/extension.zip 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && grep -q 'different bytes' <<<"$out" && ok || bad "rc=$rc $out"

# --- console_put_once ----------------------------------------------------------------------------
grant='{"url":"https://s3.stub/bundles/x/extension.zip?sig=secret","method":"PUT","headers":{"If-None-Match":"*"},"s3_path":"s3://b/k","expires_in":900}'
printf 'payload' > "$TMP/up.zip"

t "console_put_once with a 2xx is done and sends If-None-Match and -T"
: > "$LOG"
PUT_CODE=200 console_put_once "$TMP/up.zip" "$grant" none >/dev/null 2>&1 && \
  grep -q 'If-None-Match: \*' "$LOG" && grep -q -- '-T ' "$LOG" && ok || bad "200 path: $(cat "$LOG")"

t "console_put_once with a 412 and a matching registered artifact is done"
: > "$LOG"
PUT_CODE=412 console_put_once "$TMP/up.zip" "$grant" match >/dev/null 2>&1 && ok || bad "412 match"

t "console_put_once with a 412 and no matching artifact fails with the bucket-admin message"
: > "$LOG"
out="$(PUT_CODE=412 console_put_once "$TMP/up.zip" "$grant" none 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && grep -q 'A bucket admin deletes it' <<<"$out" && ok || bad "rc=$rc $out"

t "console_put_once with a 403 fails and prints the response body"
: > "$LOG"
out="$(PUT_CODE=403 PUT_BODY='{"detail":"denied"}' console_put_once "$TMP/up.zip" "$grant" none 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && grep -q 'denied' <<<"$out" && ok || bad "rc=$rc $out"

t "console_put_once never echoes the grant url"
out="$(PUT_CODE=403 PUT_BODY='{"detail":"denied"}' console_put_once "$TMP/up.zip" "$grant" none 2>&1)"
grep -q 'sig=secret' <<<"$out" && bad "leaked the grant url" || ok

echo; echo "passed $PASS, failed $FAIL"; [ "$FAIL" -eq 0 ]
