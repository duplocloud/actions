# shellcheck shell=bash
# The two create-only upload backends. Sourced by release.sh and the tests. The AWS backend puts straight to the
# bucket with the assumed role. The console backend puts through a console-issued grant, for a pipeline with no role.

# upload_backend: aws when the caller supplied AWS credentials, else console.
upload_backend() {
  if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then printf 'aws'; else printf 'console'; fi
}

# aws_put_once <file> <bucket> <key>: create-only put. On a 412 the bytes are compared, identical counting as already
# uploaded and different failing, so a published build is never replaced.
aws_put_once() {
  local file=$1 bucket=$2 key=$3 out have
  if out="$(aws s3api put-object --bucket "$bucket" --key "$key" --body "$file" --if-none-match '*' 2>&1)"; then
    echo "==> uploaded s3://$bucket/$key"; return 0
  fi
  if ! grep -qE 'PreconditionFailed|\(412\)' <<<"$out"; then echo "::error::upload of $key failed: $out"; return 1; fi
  have="$(mktemp)"
  aws s3api get-object --bucket "$bucket" --key "$key" "$have" >/dev/null || { rm -f "$have"; return 1; }
  if cmp -s "$file" "$have"; then rm -f "$have"; echo "==> $key already uploaded, identical bytes"; return 0; fi
  rm -f "$have"; echo "::error::s3://$bucket/$key already holds different bytes. A published build is never replaced."
  return 1
}

# console_put_once <file> <grant-json> <registered-state>: put through the console grant with each of its headers. A
# 2xx is done. A 412 is done only when this release registered a matching artifact (registered-state is match), else
# it fails, since the object was put by something else. Any other status fails, printing the response body. The
# grant's url is a credential and is never echoed.
console_put_once() {
  local file=$1 grant=$2 registered=$3 url method bodyfile code rc body h
  local hargs=()
  url="$(jq -r '.url' <<<"$grant")"
  method="$(jq -r '.method // "PUT"' <<<"$grant")"
  while IFS= read -r h; do [ -n "$h" ] && hargs+=(-H "$h"); done \
    < <(jq -r '.headers // {} | to_entries[] | "\(.key): \(.value)"' <<<"$grant")
  bodyfile="$(mktemp "${RUNNER_TEMP:-/tmp}/put.XXXXXX")"
  code="$(curl -sS -o "$bodyfile" -w '%{http_code}' -X "$method" -T "$file" "${hargs[@]}" "$url")"; rc=$?
  body="$(cat "$bodyfile")"; rm -f "$bodyfile"
  if [ "$rc" -ne 0 ]; then echo "::error::the upload PUT to the console grant failed to run."; return 1; fi
  case "$code" in
    2*) echo "==> uploaded through the console grant"; return 0 ;;
    412)
      if [ "$registered" = match ]; then echo "==> the grant's object is already uploaded and matches this release"; return 0; fi
      echo "::error::the grant's s3_path already holds an object this release did not register. A bucket admin deletes it, or bump manifest.version."
      return 1 ;;
    *) echo "::error::the console upload failed with HTTP $code: $body"; return 1 ;;
  esac
}
