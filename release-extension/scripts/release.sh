#!/usr/bin/env bash
# Take every built extension in this repository through signing, GitHub release, console registration, upload and
# optional publishing. The repository's own build runs first, from here, and this script owns everything after it.
#
# Reads its configuration from INPUT_* in the environment, as the composite action passes them, plus GITHUB_* and
# RUNNER_TEMP. See release-extension/README.md for the inputs and the two credential shapes.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/bundles.sh
. "$HERE/lib/bundles.sh"
# shellcheck source=scripts/lib/console.sh
. "$HERE/lib/console.sh"
# shellcheck source=scripts/lib/upload.sh
. "$HERE/lib/upload.sh"

# Inputs mapped onto the names the libraries and the signer read.
export CONSOLE_API_KEY="${INPUT_CONSOLE_API_KEY:-}"
export CONSOLE_URL="${INPUT_CONSOLE_URL:-https://console.duplocloud.com}"
export CONSOLE_TEAM="${INPUT_CONSOLE_TEAM:-}"
export EXTENSION_SIGNING_KEY="${INPUT_SIGNING_KEY:-}"
export EXTENSION_SIGNING_CERT="${INPUT_SIGNING_CERT:-}"
bundle_bucket="${INPUT_BUNDLE_BUCKET:-duplo-helpdesk-channels}"
build_command="${INPUT_BUILD_COMMAND:-./scripts/build-all.sh}"
publish="${INPUT_PUBLISH:-false}"
sdk_versions="${INPUT_SDK_VERSIONS:-}"
sign_cmd="${EXTENSION_SIGN:-python3 "$HERE/extension-sign.py"}"
sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"

duplo_org() { case "${GITHUB_REPOSITORY_OWNER:-}" in duplocloud|duplocloud-internal) return 0 ;; *) return 1 ;; esac; }

# --- Guards, before the build (D3, D13). A failure here means nothing is built, signed or released. ---------------
[ -n "$CONSOLE_API_KEY" ] || { echo "::error::console-api-key is required."; exit 1; }
signing=0
if duplo_org; then
  [ -n "$EXTENSION_SIGNING_KEY" ]  || { echo "::error::signing-key is required in $GITHUB_REPOSITORY_OWNER. DuploCloud releases are always signed."; exit 1; }
  [ -n "$EXTENSION_SIGNING_CERT" ] || { echo "::error::signing-cert is required in $GITHUB_REPOSITORY_OWNER. DuploCloud releases are always signed."; exit 1; }
  [ -n "${INPUT_ARMDOT_LICENSE:-}" ] || { echo "::error::armdot-license is required in $GITHUB_REPOSITORY_OWNER. DuploCloud builds are always obfuscated."; exit 1; }
  signing=1
elif [ -n "$EXTENSION_SIGNING_KEY" ] && [ -n "$EXTENSION_SIGNING_CERT" ]; then
  signing=1
fi

mapfile -t dirs < <(extension_dirs)
[ "${#dirs[@]}" -gt 0 ] || { echo "::error::no extension found under extensions/*/, extension/*/ or extension/."; exit 1; }
check_text_inputs "${#dirs[@]}" || exit 1

# --- License and build. The license applies only in DuploCloud's organizations, where it is required above. -------
if duplo_org && [ -n "${INPUT_ARMDOT_LICENSE:-}" ]; then
  armdot_key="$RUNNER_TEMP/armdot.key"
  printf '%s' "$INPUT_ARMDOT_LICENSE" | base64 -d > "$armdot_key" 2>/dev/null \
    || { echo "::error::armdot-license is not valid base64 of an ArmDot license file."; exit 1; }
  chmod 600 "$armdot_key"
  export ARMDOT_LICENSE_FILE_PATH="$armdot_key"
fi
DUPLO_SDK_VERSIONS="$(printf '%s' "$sdk_versions" | paste -sd, -)"; export DUPLO_SDK_VERSIONS
echo "==> Building with $build_command"
eval "$build_command"

# --- Validate every bundle and resolve every agent, before anything is signed or released. -----------------------
stamp_required=0; duplo_org && stamp_required=1
declare -A dir_bundles dir_uuid dir_id
for dir in "${dirs[@]}"; do
  bl="$(bundles_for "$dir" "$sdk_versions")" || exit 1
  while IFS= read -r zip; do [ -n "$zip" ] || continue; check_bundle "$zip" "$stamp_required" || exit 1; done <<<"$bl"
  first_zip="$(head -1 <<<"$bl")"
  id="$(unzip -p "$first_zip" manifest.json | jq -r '.id')"
  uuid="$(agent_uuid "$id")" || exit 1
  dir_bundles["$dir"]="$bl"; dir_id["$dir"]="$id"; dir_uuid["$dir"]="$uuid"
done

# --- Release, register, upload and publish each bundle. ----------------------------------------------------------
released=0; resumed=0; failed=0
for dir in "${dirs[@]}"; do
  id="${dir_id[$dir]}"; uuid="${dir_uuid[$dir]}"
  slug="$(basename "$dir")"; version="$(jq -r '.version' "$dir/manifest.json")"
  while IFS= read -r zip; do
    [ -n "$zip" ] || continue
    sdk="$(unzip -p "$zip" manifest.json | jq -r '.sdkVersion')"
    base="${slug}-v${version}"; tag="${base}-sdk-${sdk}"

    changed_since=""
    while IFS= read -r gt; do
      [ -n "$gt" ] || continue
      git diff --quiet "$gt^{commit}" "$sha" -- "$dir" || { changed_since="$gt"; break; }
    done < <(git tag -l "$base" "$base-sdk-*")
    if [ -n "$changed_since" ]; then
      echo "::error::$dir — $version is already released as $changed_since and the extension changed since. Bump manifest.version to publish it."
      failed=$((failed + 1)); continue
    fi

    workdir="$(mktemp -d)"; workzip="$workdir/extension.zip"; worksig="$workdir/extension.zip.sig"
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
      if ! gh release download "$tag" -p extension.zip -p extension.zip.sig -D "$workdir" 2>/dev/null; then
        echo "::error::$tag — cannot download its release assets."; rm -rf "$workdir"; failed=$((failed + 1)); continue
      fi
      resumed=$((resumed + 1))
    else
      cp "$zip" "$workzip"
      local_assets=("$workzip")
      if [ "$signing" = 1 ]; then
        # shellcheck disable=SC2086 # sign_cmd is an interpreter plus a script path
        if ! $sign_cmd sign "$workzip"; then echo "::error::$dir — signing $tag failed."; rm -rf "$workdir"; failed=$((failed + 1)); continue; fi
        local_assets+=("$worksig")
      fi
      if ! gh release create "$tag" "${local_assets[@]}" --target "$sha" \
          --title "$slug $version (SDK $sdk)" \
          --notes "Automated release of $slug v$version, built against host SDK $sdk."; then
        echo "::error::$tag — gh release create failed."; rm -rf "$workdir"; failed=$((failed + 1)); continue
      fi
      released=$((released + 1))
    fi

    sha256="$(shasum -a 256 "$workzip" | cut -d' ' -f1)"
    signature=""; [ -f "$worksig" ] && signature="$(cat "$worksig")"
    if ! vuuid="$(ensure_version "$uuid" "$version" "$(version_fields "$workzip")")"; then rm -rf "$workdir"; failed=$((failed + 1)); continue; fi

    backend="$(upload_backend)"; grant=""
    if [ "$backend" = aws ]; then
      key="bundles/$id/$version/sdk-$sdk/extension.zip"; s3_path="s3://$bundle_bucket/$key"
    else
      if ! grant="$(upload_url "$uuid" "$vuuid" "$sdk")"; then rm -rf "$workdir"; failed=$((failed + 1)); continue; fi
      s3_path="$(jq -r '.s3_path' <<<"$grant")"
    fi
    art="$(jq -nc --arg s "$sdk" --arg p "$s3_path" --arg h "$sha256" --arg g "$signature" \
      '{sdk_version:$s, s3_path:$p, sha256:$h, signature:$g}')"

    if ! state="$(artifact_state "$uuid" "$vuuid" "$sdk" "$art")"; then rm -rf "$workdir"; failed=$((failed + 1)); continue; fi
    reg=later
    case "$state" in
      differs) echo "::error::$tag — the console already holds a build for SDK $sdk that differs from this release."; rm -rf "$workdir"; failed=$((failed + 1)); continue ;;
      none) if ! reg="$(register_artifact "$uuid" "$vuuid" "$art")"; then rm -rf "$workdir"; failed=$((failed + 1)); continue; fi ;;
    esac

    if [ "$backend" = aws ]; then
      if ! aws_put_once "$workzip" "$bundle_bucket" "$key" || ! aws_put_once "$worksig" "$bundle_bucket" "$key.sig"; then
        rm -rf "$workdir"; failed=$((failed + 1)); continue
      fi
    else
      if ! console_put_once "$workzip" "$grant" "$state"; then rm -rf "$workdir"; failed=$((failed + 1)); continue; fi
    fi

    if [ "$publish" = true ] && [ "$reg" = first ]; then
      publish_version "$uuid" "$vuuid" || { rm -rf "$workdir"; failed=$((failed + 1)); continue; }
    fi
    rm -rf "$workdir"
  done <<<"${dir_bundles[$dir]}"
done

echo "==> Released $released, resumed $resumed, failed $failed."
[ "$failed" -eq 0 ]
