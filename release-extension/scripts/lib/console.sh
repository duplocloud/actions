# shellcheck shell=bash
# Console client on the agents routes, staff or team. Sourced by release.sh and the tests. The API key reaches curl
# through a mode 600 header file under $RUNNER_TEMP, never argv. Every function prints a console error body verbatim.

# console <METHOD> <path-or-url> [json]: one console call. A path is prefixed with CONSOLE_URL; an absolute URL (the
# paginator's next) is used as given. Prints the response body, sets CONSOLE_STATUS to the HTTP code, returns curl's
# exit status.
console() {
  local method="$1" path="$2" json="${3:-}" hdr resp rc target
  case "$path" in http*) target="$path" ;; *) target="${CONSOLE_URL%/}$path" ;; esac
  hdr="$(mktemp "${RUNNER_TEMP:-/tmp}/console-hdr.XXXXXX")"; chmod 600 "$hdr"
  printf 'Authorization: Api-Key %s\n' "$CONSOLE_API_KEY" > "$hdr"
  if [ -n "$json" ]; then
    resp="$(curl -sS --fail-with-body -X "$method" -H @"$hdr" -H 'Content-Type: application/json' --data "$json" \
      -w '\n%{http_code}' "$target")"
  else
    resp="$(curl -sS --fail-with-body -X "$method" -H @"$hdr" -w '\n%{http_code}' "$target")"
  fi
  rc=$?
  rm -f "$hdr"
  CONSOLE_STATUS="${resp##*$'\n'}"
  printf '%s' "${resp%$'\n'*}"
  return $rc
}

# agents_base: the agents route prefix, team-scoped when CONSOLE_TEAM is set.
agents_base() {
  if [ -n "${CONSOLE_TEAM:-}" ]; then printf '/a/%s/agents/api/agents' "$CONSOLE_TEAM"; else printf '/api/agents'; fi
}

# agent_uuid <manifest-id>: page through the agent list and print the uuid whose manifest_id matches. The list
# paginates with results and an absolute next URL, requested as given. Exits 1 naming view_agents on a staff 403.
agent_uuid() {
  local id="$1" url body uuid next bodyfile
  # console is called with its body redirected to a file, not in a command substitution, so the CONSOLE_STATUS it
  # sets survives into this scope and the staff 403 can be told apart from any other failure.
  bodyfile="$(mktemp "${RUNNER_TEMP:-/tmp}/agents.XXXXXX")"
  url="$(agents_base)/"
  while [ -n "$url" ]; do
    if ! console GET "$url" > "$bodyfile"; then
      body="$(cat "$bodyfile")"; rm -f "$bodyfile"
      if [ "${CONSOLE_STATUS:-}" = 403 ] && [ -z "${CONSOLE_TEAM:-}" ]; then
        echo "::error::the console refused to list agents (403). The CI service account's key needs view_agents. Add it to the CI service account's role in the console's platform-owner team." >&2
      else
        echo "::error::agent lookup failed: $body" >&2
      fi
      return 1
    fi
    body="$(cat "$bodyfile")"
    uuid="$(jq -r --arg id "$id" 'first((.results? // .)[] | select(.manifest_id == $id) | .uuid) // empty' <<<"$body")"
    [ -n "$uuid" ] && { rm -f "$bodyfile"; printf '%s' "$uuid"; return 0; }
    next="$(jq -r '.next // empty' <<<"$body")"
    url="$next"
  done
  rm -f "$bodyfile"
  echo "::error::no agent in the console has manifest_id $id. Create the agent in the console first." >&2
  return 1
}

# ensure_version <agent-uuid> <version> <fields-json>: print the version uuid, creating it from {version} + the
# {name, description, changelog} fields when the lookup is empty, and re-reading on a 400 that says it already exists.
ensure_version() {
  local agent="$1" version="$2" fields="$3" base body vuuid create
  base="$(agents_base)/$agent/versions"
  body="$(console GET "$base/?version=$version")" || { echo "::error::version lookup failed: $body" >&2; return 1; }
  vuuid="$(jq -r '(.results? // .)[0].uuid // empty' <<<"$body")"
  if [ -z "$vuuid" ]; then
    create="$(jq -cn --argjson f "$fields" --arg v "$version" '{version:$v} + $f')"
    body="$(console POST "$base/" "$create")" || grep -q "already exists" <<<"$body" \
      || { echo "::error::console refused the version: $body" >&2; return 1; }
    body="$(console GET "$base/?version=$version")" || { echo "::error::version re-lookup failed: $body" >&2; return 1; }
    vuuid="$(jq -r '(.results? // .)[0].uuid // empty' <<<"$body")"
  fi
  [ -n "$vuuid" ] || { echo "::error::the console has no version uuid for $version after creating it." >&2; return 1; }
  printf '%s' "$vuuid"
}

# artifact_state <agent-uuid> <version-uuid> <sdk> <expected-json>: print none, match or differs, comparing s3_path,
# the lowercased sha256 and the signature of the version's build for this SDK against the expected artifact.
artifact_state() {
  local agent="$1" vuuid="$2" sdk="$3" expected="$4" base body
  base="$(agents_base)/$agent/versions/$vuuid/artifacts"
  body="$(console GET "$base/?sdk_version=$sdk")" || { echo "::error::artifact lookup failed: $body" >&2; return 1; }
  if [ "$(jq 'length' <<<"$body")" -eq 0 ]; then printf 'none'; return 0; fi
  if jq -e --argjson a "$expected" \
    '.[0] | .s3_path == $a.s3_path and (.sha256 | ascii_downcase) == ($a.sha256 | ascii_downcase) and .signature == $a.signature' \
    >/dev/null <<<"$body"; then printf 'match'; else printf 'differs'; fi
}

# register_artifact <agent-uuid> <version-uuid> <artifact-json>: post it, and print first when the version had no
# build before this post, else later. A version's first build is what publishing keys on.
register_artifact() {
  local agent="$1" vuuid="$2" art="$3" base before body first=later
  base="$(agents_base)/$agent/versions/$vuuid/artifacts"
  before="$(console GET "$base/")" || { echo "::error::artifact list failed: $before" >&2; return 1; }
  [ "$(jq 'length' <<<"$before")" -gt 0 ] || first=first
  body="$(console POST "$base/" "$art")" || { echo "::error::console refused the artifact: $body" >&2; return 1; }
  printf '%s' "$first"
}

# upload_url <agent-uuid> <version-uuid> <sdk>: print the console's upload grant {url, method, headers, s3_path,
# expires_in} for this SDK's build.
upload_url() {
  local agent="$1" vuuid="$2" sdk="$3" base body
  base="$(agents_base)/$agent/versions/$vuuid/artifacts"
  body="$(console POST "$base/upload-url/" "$(jq -nc --arg s "$sdk" '{sdk_version:$s}')")" \
    || { echo "::error::upload-url request failed: $body" >&2; return 1; }
  printf '%s' "$body"
}

# publish_version <agent-uuid> <version-uuid>: mark the version published unless it already is.
publish_version() {
  local agent="$1" vuuid="$2" base body
  base="$(agents_base)/$agent/versions/$vuuid"
  body="$(console GET "$base/")" || { echo "::error::version lookup before publish failed: $body" >&2; return 1; }
  if jq -e '.is_published == true' >/dev/null <<<"$body"; then echo "==> the version is already published"; return 0; fi
  body="$(console PATCH "$base/" '{"is_published": true}')" || { echo "::error::console refused to publish the version: $body" >&2; return 1; }
  echo "==> published the version in the license server"
}
