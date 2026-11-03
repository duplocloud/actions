# shellcheck shell=bash
# Fakes for the console client and the upload backends, shared by the console, upload and release tests. Source this
# after creating "$TMP/bin" and putting it on PATH. It writes gh, aws and curl there and makes them executable. The
# caller exports ASSETS (a directory holding extension.zip and extension.zip.sig), S3 and CONSOLE (scratch directories
# standing in for the bucket and the console's records), BUCKET, and LOG (where every stubbed call is appended).
#
# The curl stub models the console on the agents routes. It serves the paginated agent list from $CONSOLE/agents.json
# (pages of 2, absolute next URLs), versions and artifacts as files under $CONSOLE, and an artifact upload-url grant.
# It prints the response body, then a final line with the HTTP code, and exits 22 for a code of 400 or more, so the
# client's console() reads the code the way curl --fail-with-body plus -w would hand it over. It logs raw argv,
# unmasked, so a key leaked onto the command line would show up, and records whether the call's header file held the
# key (HEADER_FILE_KEY=yes/no) so a test can prove that without the key itself in the log.

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$LOG"
case "$1 $2" in
  "release download")
    pats=(); dest=""
    while [ $# -gt 0 ]; do case "$1" in -p) pats+=("$2"); shift ;; -D) dest=$2; shift ;; esac; shift; done
    for p in "${pats[@]}"; do cp "$ASSETS/$p" "$dest"/; done ;;
  "release create") exit "${GH_CREATE_RC:-0}" ;;
  "release view") [ "${GH_VIEW_RC:-0}" = 0 ] || exit "${GH_VIEW_RC}"
                   printf '%s\n' "${GH_ASSETS:-extension.zip,extension.zip.sig}" ;;
  "api repos/{owner}/{repo}/releases/tags/"*)
    [ "${GH_API_RC:-0}" = 0 ] || exit "${GH_API_RC}"
    if [[ "$*" == *'assets[]'* ]]; then printf '%s\n' "${GH_DIGEST-sha256:$ZSHA}"
    else printf '%s\n' "${GH_IMMUTABLE:-true}"; fi ;;
esac
EOF

cat > "$TMP/bin/aws" <<'EOF'
#!/usr/bin/env bash
echo "aws $*" >> "$LOG"
key=""; body=""; out=""; while [ $# -gt 0 ]; do case "$1" in --key) key=$2 ;; --body) body=$2 ;; esac; out=$1; shift; done
obj="$S3/$(echo "$key" | tr / _)"
if grep -q put-object <<<"$(tail -1 "$LOG")"; then
  [ -f "$obj" ] && { echo "An error occurred (PreconditionFailed) when calling the PutObject operation" >&2; exit 254; }
  cp "$body" "$obj"; echo '{}'
else cp "$obj" "$out"; fi
EOF

cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> "$LOG"
url=""; data=""; method=GET; hdrfile=""; outfile=""; putfile=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift ;;
    --data|-d) data=$2; method=${method/GET/POST}; shift ;;
    -H) case "$2" in @*) hdrfile=${2#@} ;; esac; shift ;;
    -o) outfile=$2; shift ;;
    -T) putfile=$2; shift ;;
    http*) url=$1 ;;
  esac
  shift
done

# The console upload PUT goes to the grant's s3.stub URL. Model it as a create-only put into $S3, writing the body to
# -o and the HTTP code to stdout the way curl -w does (no --fail-with-body, so the exit is 0 and the caller branches
# on the code). 412 when the key already holds an object.
if [ "$method" = PUT ]; then
  [ -n "$outfile" ] && echo '{}' > "$outfile"
  key="${url#*://s3.stub/}"; key="${key%%\?*}"; obj="$S3/$(echo "$key" | tr / _)"
  if [ -f "$obj" ]; then printf '412'; else cp "$putfile" "$obj" 2>/dev/null; printf '200'; fi
  exit 0
fi
if [ -n "$hdrfile" ] && grep -qF -- "$CONSOLE_API_KEY" "$hdrfile" 2>/dev/null
then echo "HEADER_FILE_KEY=yes" >> "$LOG"; else echo "HEADER_FILE_KEY=no" >> "$LOG"; fi

# emit <code> <body>: print the body then a final line with the code, and exit the way --fail-with-body would.
emit() { printf '%s\n%s' "$2" "$1"; [ "$1" -ge 400 ] && exit 22 || exit 0; }

# CONSOLE_FAIL, a regex matched against the URL, makes that call fail the way curl --fail-with-body does.
if [ -n "${CONSOLE_FAIL:-}" ] && [[ "$url" =~ $CONSOLE_FAIL ]]; then emit 500 '{"detail":"server error"}'; fi

case "$method $url" in
  "GET "*"/agents/" | "GET "*"/agents/?page="*)
    [ -n "${CONSOLE_AGENTS_403:-}" ] && emit 403 '{"detail":"forbidden"}'
    page=1; case "$url" in *"?page="*) page="${url##*page=}"; page="${page%%&*}" ;; esac
    path="${url%%\?*}"
    total=$(jq 'length' "$CONSOLE/agents.json")
    start=$(( (page - 1) * 2 ))
    results=$(jq -c ".[$start:$start+2]" "$CONSOLE/agents.json")
    if [ $((start + 2)) -lt "$total" ]; then nxt="\"$path?page=$((page + 1))\""; else nxt=null; fi
    emit 200 "{\"results\":$results,\"next\":$nxt}" ;;
  "GET "*"/versions/?version="*) emit 200 "$(cat "$CONSOLE/versions.json" 2>/dev/null || echo '[]')" ;;
  "POST "*"/versions/")
    [ -n "${RACE:-}" ] && [ ! -f "$CONSOLE/raced" ] && { touch "$CONSOLE/raced"; echo '[{"uuid":"v-1"}]' > "$CONSOLE/versions.json"; emit 400 '{"version":["1.0.0 already exists for this extension."]}'; }
    echo '[{"uuid":"v-1"}]' > "$CONSOLE/versions.json"; emit 200 '{"uuid":"v-1"}' ;;
  "GET "*"/versions/v-1/")
    if [ -f "$CONSOLE/published" ]; then emit 200 '{"uuid":"v-1","is_published":true}'; else emit 200 '{"uuid":"v-1","is_published":false}'; fi ;;
  "PATCH "*"/versions/v-1/")
    [ -n "${PATCH_FAIL:-}" ] && emit 400 '{"detail":"refused"}'
    echo "$data" > "$CONSOLE/published"; emit 200 '{"uuid":"v-1","is_published":true}' ;;
  "POST "*"/artifacts/upload-url/")
    key="bundles/stub/extension.zip"
    emit 200 "$(jq -nc --arg u "https://s3.stub/$key" --arg p "s3://${BUCKET:-duplo-helpdesk-channels}/$key" \
      '{url:$u, method:"PUT", headers:{"If-None-Match":"*"}, s3_path:$p, expires_in:900}')" ;;
  "GET "*"/artifacts/?sdk_version="*)
    emit 200 "$(jq -c --arg s "${url##*sdk_version=}" '[.[] | select(.sdk_version == $s)]' "$CONSOLE/artifacts.json" 2>/dev/null || echo '[]')" ;;
  "GET "*"/artifacts/") emit 200 "$(cat "$CONSOLE/artifacts.json" 2>/dev/null || echo '[]')" ;;
  "POST "*"/artifacts/")
    jq -c --argjson a "$data" '. + [$a]' "$CONSOLE/artifacts.json" 2>/dev/null > "$CONSOLE/a.tmp" || echo "[$data]" > "$CONSOLE/a.tmp"
    mv "$CONSOLE/a.tmp" "$CONSOLE/artifacts.json"; emit 200 "$data" ;;
  *) emit 404 '{"detail":"no stub route"}' ;;
esac
EOF

chmod +x "$TMP/bin/gh" "$TMP/bin/aws" "$TMP/bin/curl"
