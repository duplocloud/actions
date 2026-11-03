#!/usr/bin/env bash
# Tests for scripts/extension-sign.py against the console's cross-language vectors. Usage: ./tests/test-extension-sign.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0
t()   { printf '  %s … ' "$1"; }
ok()  { echo "ok"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# The vector tests import the signer as a module. Without this, Python leaves scripts/__pycache__/ in the checkout.
export PYTHONDONTWRITEBYTECODE=1
V=vectors; S=../scripts/extension-sign.py
# The vectors' certificate rides in each .sig header, so the valid case's header gives it.
CERT=$(python3 -c 'import jwt,sys; print(jwt.get_unverified_header(open(sys.argv[1]).read())["cert"])' $V/extension.zip.sig)
NOW=$(jq -r '.cases[0].now' $V/cases.json)
# mkzip <id> <version> <sdkVersion|-> <out>: a zip holding only manifest.json. "-" leaves sdkVersion out.
mkzip() { local d; d=$(mktemp -d); jq -n --arg i "$1" --arg v "$2" --arg s "$3" \
  '{id:$i,version:$v} + (if $s == "-" then {} else {sdkVersion:$s} end)' > "$d/manifest.json"
  (cd "$d" && zip -q "$4" manifest.json); rm -rf "$d"; }
sign() { EXTENSION_SIGNING_KEY="$(cat "$1")" EXTENSION_SIGNING_CERT="$CERT" EXTENSION_SIGN_NOW="$NOW" python3 $S sign "$2" 2>&1; }

echo "extension-sign:"

t "verify reproduces every vector case"
OUT=$(python3 extension_sign_vectors.py 2>&1); [ $? = 0 ] && ok || bad "$OUT"

t "verify parses the console's real root-keys response shape (no network)"
OUT=$(python3 extension_sign_console_shape.py 2>&1); [ $? = 0 ] && ok || bad "$OUT"

t "a fresh signature verifies against the test root"
mkzip io.example.hello 1.0.0 1.0.0 "$TMP/a.zip"; OUT=$(sign $V/publisher.pem "$TMP/a.zip")
OUT2=$(EXTENSION_SIGN_NOW="$NOW" python3 $S verify "$TMP/a.zip" "$TMP/a.zip.sig" --root-key $V/root.pub.pem 2>&1)
[ $? = 0 ] && grep -q "not the console's roots" <<<"$OUT2" && ok || bad "$OUT $OUT2"

t "the .sig has no trailing newline"
[ "$(tail -c1 "$TMP/a.zip.sig" | od -An -c | tr -d ' ')" != '\n' ] && ok || bad "trailing newline"

t "refuses a key that does not match the certificate"
mkzip io.example.hello 1.0.0 1.0.0 "$TMP/b.zip"; OUT=$(sign $V/other.pem "$TMP/b.zip")
[ $? != 0 ] && grep -q "signing key and certificate don't match" <<<"$OUT" && [ ! -f "$TMP/b.zip.sig" ] && ok || bad "$OUT"

t "refuses a manifest id outside the certificate's namespaces"
mkzip com.other.thing 1.0.0 1.0.0 "$TMP/c.zip"; OUT=$(sign $V/publisher.pem "$TMP/c.zip")
[ $? != 0 ] && grep -q "manifest id outside this key's namespaces" <<<"$OUT" && ok || bad "$OUT"

t "refuses a missing sdkVersion"
mkzip io.example.hello 1.0.0 - "$TMP/d.zip"; OUT=$(sign $V/publisher.pem "$TMP/d.zip")
[ $? != 0 ] && grep -q "sdkVersion" <<<"$OUT" && ok || bad "$OUT"

t "refuses the sdk-version placeholder"
mkzip io.example.hello 1.0.0 REPLACED_BY_SKILL_FROM_sdk-version_ENDPOINT "$TMP/e.zip"; OUT=$(sign $V/publisher.pem "$TMP/e.zip")
[ $? != 0 ] && grep -q "sdkVersion" <<<"$OUT" && ok || bad "$OUT"

t "refuses a version with build metadata"
mkzip io.example.hello 1.0.0+abc 1.0.0 "$TMP/f.zip"; OUT=$(sign $V/publisher.pem "$TMP/f.zip")
[ $? != 0 ] && grep -q "strict semver" <<<"$OUT" && ok || bad "$OUT"

t "refuses an expired certificate"
mkzip io.example.hello 1.0.0 1.0.0 "$TMP/g.zip"
EXP=$(python3 -c 'import jwt,sys; print(jwt.decode(sys.argv[1], options={"verify_signature": False})["exp"])' "$CERT")
OUT=$(EXTENSION_SIGNING_KEY="$(cat $V/publisher.pem)" EXTENSION_SIGNING_CERT="$CERT" EXTENSION_SIGN_NOW="$EXP" python3 $S sign "$TMP/g.zip" 2>&1)
[ $? != 0 ] && grep -q "expired" <<<"$OUT" && ok || bad "$OUT"

t "refuses a certificate that is not valid yet"
mkzip io.example.hello 1.0.0 1.0.0 "$TMP/n.zip"
NBF=$(python3 -c 'import jwt,sys; print(jwt.decode(sys.argv[1], options={"verify_signature": False})["nbf"])' "$CERT")
OUT=$(EXTENSION_SIGNING_KEY="$(cat $V/publisher.pem)" EXTENSION_SIGNING_CERT="$CERT" EXTENSION_SIGN_NOW="$((NBF - 1))" python3 $S sign "$TMP/n.zip" 2>&1)
[ $? != 0 ] && grep -q "not valid yet" <<<"$OUT" && [ ! -f "$TMP/n.zip.sig" ] && ok || bad "$OUT"

t "warns when the certificate expires within 30 days"
mkzip io.example.hello 1.0.0 1.0.0 "$TMP/h.zip"
OUT=$(EXTENSION_SIGNING_KEY="$(cat $V/publisher.pem)" EXTENSION_SIGNING_CERT="$CERT" EXTENSION_SIGN_NOW="$((EXP - 86400))" python3 $S sign "$TMP/h.zip" 2>&1)
[ $? = 0 ] && grep -q "::warning::.*expires" <<<"$OUT" && ok || bad "$OUT"

t "never prints the key"
grep -q "BEGIN" <<<"$(sign $V/other.pem "$TMP/b.zip")" && bad "key material in output" || ok

echo; echo "passed $PASS, failed $FAIL"; [ "$FAIL" -eq 0 ]
