# Extension signing test vectors

**These keys are test-only.** `root.pem`, `publisher.pem` and `other.pem` are throwaway EC P-256
private keys. They are committed on purpose so that two independent verifiers can be checked
against the same inputs. No console, portal or license trusts them. Never use them for anything
else.

The .NET helpdesk copies this directory as-is into its own test suite. For every entry in
`cases.json`, its verifier must produce the same outcome as the console's
`verify_artifact_signature` (`apps/extensions/signing/verify.py`).

## Files

| File | Contents |
|---|---|
| `root.pem` / `root.pub.pem` | Test root key, private and public. Its kid is the only key of `root_keys` in `cases.json` |
| `publisher.pem` | Test publisher private key. Its root-signed certificate rides in each `.sig` header (`cert`) |
| `other.pem` | An unrelated key. It signs the `bad-signature` and `unknown-root` vectors |
| `extension.zip` | A tiny zip holding `manifest.json`: `{"id":"io.example.hello","version":"1.0.0"}` |
| `*.zip.sig` | One compact JWS per file, with no trailing newline. Each case's `sig` names the file it uses |
| `cases.json` | `root_keys` (a map from root kid to PEM file name in this directory) and `cases` |

## How to run a case

Each case is:

```
{name, sig, sha256, manifest_id, version, sdk_version, trusted_publishers, now, expect}
```

Call the verifier once per case with these inputs:

- **Signature:** the contents of the file named by `sig`.
- **Root keys:** loaded from `root_keys`.
- **`sha256`, `manifest_id`, `version`, `sdk_version`:** the case's own values. They are the
  *observed* values: what the portal would have computed from the zip and read from its
  manifest. Feed them **directly** into the claim comparison. Do **not** re-hash
  `extension.zip` or re-read its manifest for the case run. Several cases deliberately supply
  observed values that differ from the zip.
- **`trusted_publishers`:** the license's `trusted_pub`. `null` means skip the trust check, as
  the console does. A list (including an empty list) means the certificate's `sub` must be in
  it.
- **`now`:** the current time, as integer epoch seconds. Use it for the certificate's
  `nbf`/`exp` check instead of the clock.

`expect` is `ok` or the error code the verifier must report.

`extension.zip` is only the source of the valid cases' `sha256`, and a sample for a separate
end-to-end test (hash the zip, read the manifest, then verify `extension.zip.sig`).

## Check order and codes

The steps run in this order. The first step that fails decides the code, so a token with several
defects reports the earliest one.

1. **Signature header** (read unverified, only to route).
   - `typ` must be `duplo-ext-sig+jwt`, else `bad_typ`.
   - `alg` must be `ES256`, else `malformed`. This covers `none` and `HS256`.
   - `cert` must be a non-empty string, else `malformed`.
   - A header that can't be read at all is `malformed`.
2. **Certificate.**
   - `typ` must be `duplo-ext-cert+jwt`, else `bad_typ`.
   - Its header `kid` must be in `root_keys`, else `unknown_root`.
   - It must verify as ES256 under that root key, else `bad_cert`.
   - `iss` must be `duplocloud-console`. `sub` and `kid` must be strings, `ns` a list of strings
     and `nbf`/`exp` integers. `jwk` must be an EC P-256 key with 32-byte canonical base64url
     coordinates. Any failure is `bad_cert`.
   - Validity has zero leeway: `now < nbf` or `now >= exp` is `cert_expired`.
3. **Trust** (only when `trusted_publishers` is not null): the certificate's `sub` must be in
   it, else `untrusted_publisher`.
4. **Signature and key binding.**
   - The signature must verify as ES256 under the certificate's `jwk`, else `bad_signature`.
     Any other decode failure is `malformed`.
   - The signature header `kid` must then equal the certificate's `kid`, else `kid_mismatch`.
   - The claims `manifest_id`, `version`, `sdk_version` and `sha256` must be non-empty strings,
     with `sha256` as 64 lowercase hex characters, else `malformed`.
5. **Claims.** `sha256` is compared first: a mismatch is `hash_mismatch`, and the observed value
   is compared case-insensitively. Then `manifest_id`, `version` and `sdk_version` are compared:
   a mismatch is `manifest_mismatch`.
6. **Namespace.** `manifest_id` must equal one of the certificate's `ns` prefixes or start with
   `prefix + "."`, else `outside_namespace`.

All codes: `malformed`, `bad_typ`, `unknown_root`, `bad_cert`, `cert_expired`,
`untrusted_publisher`, `kid_mismatch`, `bad_signature`, `hash_mismatch`, `manifest_mismatch`,
`outside_namespace`.

## Regenerating

```bash
make manage ARGS='make_signing_vectors'
```

The command reuses the existing private keys, so the kids, the certificate claims and the zip
stay the same. ECDSA signatures are randomised, so the `.sig` files change on every run. Before
writing `cases.json`, the command checks every case against the console verifier.

The committed files are the source of truth. Only regenerate when the format changes, and copy
the result to the helpdesk again.
