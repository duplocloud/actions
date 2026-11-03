#!/usr/bin/env python3
"""Sign and verify an extension bundle's signature, extension.zip.sig.

sign writes one compact ES256 JWS whose claims come from the BUILT zip's manifest.json, since sdkVersion exists only
there, and whose sha256 is over the zip's final bytes. It reproduces the console's reference signer (sign_artifact in
apps/extensions/signing/verify.py). verify ports the console's verify_artifact_signature, check for check and code
for code, so tests/vectors (the console's cross-language vectors) pin both.

The key and certificate come from EXTENSION_SIGNING_KEY and EXTENSION_SIGNING_CERT, never the command line, so ps on
a shared runner never shows them. EXTENSION_SIGN_NOW overrides the clock for tests.

verify's --root-key substitutes one local root public key for the console's published roots. It exists for tests
only, and its success line says so, so the output is never mistaken for a verification against the console's real
roots.
"""
import argparse, base64, hashlib, json, os, re, sys, time, urllib.request, zipfile

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

ALG = "ES256"
SIG_TYP = "duplo-ext-sig+jwt"
CERT_TYP = "duplo-ext-cert+jwt"
CERT_ISSUER = "duplocloud-console"
PLACEHOLDER = "REPLACED_BY_SKILL"
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
WARN_DAYS = 30
NO_TIME_CHECKS = {"verify_exp": False, "verify_nbf": False, "verify_iat": False, "verify_aud": False, "verify_iss": False}


class SignatureError(Exception):
    def __init__(self, code, message=""):
        super().__init__(message or code)
        self.code = code


def now_s():
    return int(os.environ.get("EXTENSION_SIGN_NOW") or time.time())


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def coordinate(text):
    if not isinstance(text, str):
        raise ValueError("JWK coordinate must be a string")
    raw = base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))
    if len(raw) != 32 or b64url(raw) != text:
        raise ValueError("JWK coordinate must be 32 bytes of canonical base64url")
    return raw


def pem_from_jwk(jwk):
    if not isinstance(jwk, dict) or jwk.get("kty") != "EC" or jwk.get("crv") != "P-256":
        raise ValueError("only EC P-256 JWKs are supported")
    x = int.from_bytes(coordinate(jwk.get("x")), "big")
    y = int.from_bytes(coordinate(jwk.get("y")), "big")
    key = ec.EllipticCurvePublicNumbers(x, y, ec.SECP256R1()).public_key()
    return key.public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()


def jwk_of(public_key):
    n = public_key.public_numbers()
    return {"kty": "EC", "crv": "P-256", "x": b64url(n.x.to_bytes(32, "big")), "y": b64url(n.y.to_bytes(32, "big"))}


def in_namespaces(manifest_id, prefixes):
    return any(manifest_id == p or manifest_id.startswith(p + ".") for p in prefixes)


def built_manifest(zip_path):
    with zipfile.ZipFile(zip_path) as z:
        return json.loads(z.read("manifest.json"))


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def refuse(message):
    raise SystemExit(f"::error::{message}")


def sign_bytes(zip_path, key_pem, cert, now):
    m = built_manifest(zip_path)
    manifest_id, version, sdk = m.get("id"), m.get("version"), m.get("sdkVersion")
    if not isinstance(sdk, str) or not sdk or sdk.startswith(PLACEHOLDER):
        refuse(f"{zip_path}: the built manifest carries no real sdkVersion. Build it with scripts/build-extension.sh")
    for name, value in (("version", version), ("sdkVersion", sdk)):
        if not isinstance(value, str) or not SEMVER.match(value):
            refuse(f"{zip_path}: {name} {value!r} is not strict semver (MAJOR.MINOR.PATCH[-pre], no +build)")
    claims = jwt.decode(cert, options={"verify_signature": False})
    if not in_namespaces(manifest_id, claims.get("ns") or []):
        refuse(f"manifest id outside this key's namespaces: {manifest_id} is not under {claims.get('ns')}")
    key = serialization.load_pem_private_key(key_pem.encode(), password=None)
    if jwk_of(key.public_key()) != {k: claims.get("jwk", {}).get(k) for k in ("kty", "crv", "x", "y")}:
        refuse("signing key and certificate don't match")
    nbf = claims.get("nbf")
    if not isinstance(nbf, int) or now < nbf:
        refuse("the signing certificate is not valid yet. Check the runner clock, or wait for its start time")
    exp = claims.get("exp")
    if not isinstance(exp, int) or now >= exp:
        refuse("the signing certificate has expired. Reissue it in the console and update CONSOLE_SIGNING_CERT")
    if exp - now < WARN_DAYS * 86400:
        print(f"::warning::the signing certificate expires in {(exp - now) // 86400} days. Reissue it in the console",
              file=sys.stderr)
    body = {"manifest_id": manifest_id, "version": version, "sdk_version": sdk,
            "sha256": sha256_of(zip_path), "iat": now}
    return jwt.encode(body, key, algorithm=ALG, headers={"kid": claims["kid"], "typ": SIG_TYP, "cert": cert})


def header(token, code):
    if not isinstance(token, str):
        raise SignatureError(code, "token is not a string")
    try:
        h = jwt.get_unverified_header(token)
    except Exception as exc:
        raise SignatureError(code, f"unreadable header: {exc}") from exc
    if not isinstance(h, dict):
        raise SignatureError(code, "header is not an object")
    return h


def decode(token, public_pem, bad_sig, malformed):
    try:
        claims = jwt.decode(token, public_pem, algorithms=[ALG], options=NO_TIME_CHECKS)
    except jwt.InvalidSignatureError as exc:
        raise SignatureError(bad_sig, "signature does not verify") from exc
    except Exception as exc:
        raise SignatureError(malformed, f"cannot decode token: {exc}") from exc
    if not isinstance(claims, dict):
        raise SignatureError(malformed, "claims are not an object")
    return claims


def is_str(v):
    return isinstance(v, str) and v != ""


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def verify_signature(sig, *, root_keys, sha256, manifest_id, version, sdk_version, trusted_publishers, now):
    h = header(sig, "malformed")
    if h.get("typ") != SIG_TYP:
        raise SignatureError("bad_typ", "signature typ")
    if h.get("alg") != ALG:
        raise SignatureError("malformed", "signature alg")
    cert = h.get("cert")
    if not isinstance(cert, str) or not cert:
        raise SignatureError("malformed", "missing cert header")
    ch = header(cert, "bad_cert")
    if ch.get("typ") != CERT_TYP:
        raise SignatureError("bad_typ", "certificate typ")
    if ch.get("alg") != ALG:
        raise SignatureError("bad_cert", "certificate alg")
    root_kid = ch.get("kid")
    if not isinstance(root_kid, str) or root_kid not in root_keys:
        raise SignatureError("unknown_root", "certificate is not signed by a known root key")
    cc = decode(cert, root_keys[root_kid], "bad_cert", "bad_cert")
    ns = cc.get("ns")
    if cc.get("iss") != CERT_ISSUER or not (is_str(cc.get("sub")) and is_str(cc.get("kid")) and isinstance(ns, list)
                                            and all(is_str(p) for p in ns) and is_int(cc.get("nbf"))
                                            and is_int(cc.get("exp"))):
        raise SignatureError("bad_cert", "certificate claims")
    try:
        public_pem = pem_from_jwk(cc.get("jwk"))
    except Exception as exc:
        raise SignatureError("bad_cert", "certificate jwk") from exc
    if now < cc["nbf"] or now >= cc["exp"]:
        raise SignatureError("cert_expired", "certificate is outside its validity window")
    if trusted_publishers is not None and cc["sub"] not in set(trusted_publishers):
        raise SignatureError("untrusted_publisher", "publisher is not trusted")
    claims = decode(sig, public_pem, "bad_signature", "malformed")
    if h.get("kid") != cc["kid"]:
        raise SignatureError("kid_mismatch", "signature kid differs from certificate kid")
    fields = ("manifest_id", "version", "sdk_version", "sha256")
    if not all(is_str(claims.get(f)) for f in fields) or not SHA256.match(claims["sha256"]):
        raise SignatureError("malformed", "signature claims")
    if not isinstance(sha256, str) or claims["sha256"] != sha256.lower():
        raise SignatureError("hash_mismatch", "sha256 differs")
    if (claims["manifest_id"], claims["version"], claims["sdk_version"]) != (manifest_id, version, sdk_version):
        raise SignatureError("manifest_mismatch", "manifest_id, version or sdk_version differs")
    if not in_namespaces(claims["manifest_id"], ns):
        raise SignatureError("outside_namespace", "manifest_id is outside the certificate's namespaces")
    return {"publisher": cc["sub"], "kid": cc["kid"], "cert_exp": cc["exp"], "root_kid": root_kid}


def console_root_keys(console_url):
    with urllib.request.urlopen(f"{console_url.rstrip('/')}/api/extensions/root-keys/", timeout=30) as r:
        body = json.load(r)
    rows = body["keys"] if isinstance(body, dict) else body
    # A retired root stays here with active=false: certificates it issued are still live until they expire.
    return {row["kid"]: row["public_key"] for row in rows if row.get("public_key")}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sign")
    s.add_argument("zip")
    s.add_argument("--out")
    v = sub.add_parser("verify")
    v.add_argument("zip")
    v.add_argument("sig")
    v.add_argument("--root-key", help="a local root public key PEM, for tests only")
    v.add_argument("--console", default="https://console.duplocloud.com")
    a = p.parse_args(argv)
    if a.cmd == "sign":
        key, cert = os.environ.get("EXTENSION_SIGNING_KEY", ""), os.environ.get("EXTENSION_SIGNING_CERT", "")
        if not key or not cert:
            refuse("EXTENSION_SIGNING_KEY and EXTENSION_SIGNING_CERT must both be set")
        token = sign_bytes(a.zip, key, cert, now_s())
        out = a.out or a.zip + ".sig"
        with open(out, "w") as f:
            f.write(token)
        print(f"==> signed {a.zip} -> {out}")
        return 0
    sig = open(a.sig).read()
    if a.root_key:
        # A local root key is addressed by the kid the signature's certificate names, so a test root verifies.
        root_kid = jwt.get_unverified_header(jwt.get_unverified_header(sig)["cert"]).get("kid")
        roots = {root_kid: open(a.root_key).read()}
    else:
        roots = console_root_keys(a.console)
    m = built_manifest(a.zip)
    try:
        verify_signature(sig, root_keys=roots, sha256=sha256_of(a.zip), manifest_id=m.get("id"),
                         version=m.get("version"), sdk_version=m.get("sdkVersion"), trusted_publishers=None,
                         now=now_s())
    except SignatureError as exc:
        print(exc.code)
        return 1
    print("ok (against the local root key, not the console's roots)" if a.root_key else "ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
