"""Checks console_root_keys against the console's real root-keys response shape, with no network call.

apps/extensions/api_root_keys.py returns {"keys": [{"kid", "public_key", "active"}]}. This pins that shape (a bare
list is accepted too) and confirms the valid vector's signature verifies against the roots it parses out, including
a retired (active=false) row that must still be kept.
"""
import importlib.util, io, json, pathlib, sys, urllib.request

HERE = pathlib.Path(__file__).parent
spec = importlib.util.spec_from_file_location("extension_sign", HERE.parent / "scripts" / "extension-sign.py")
es = importlib.util.module_from_spec(spec)
spec.loader.exec_module(es)

vectors = HERE / "vectors"
data = json.loads((vectors / "cases.json").read_text())
root_kid = next(iter(data["root_keys"]))
root_pub = (vectors / data["root_keys"][root_kid]).read_text()
body = json.dumps({"keys": [
    {"kid": "retired-root", "public_key": "not a real key", "active": False},
    {"kid": root_kid, "public_key": root_pub, "active": True},
]}).encode()


class FakeResponse:
    def __init__(self, payload):
        self._buf = io.BytesIO(payload)

    def __enter__(self):
        return self._buf

    def __exit__(self, *exc_info):
        return False


urllib.request.urlopen = lambda url, timeout=30: FakeResponse(body)

roots = es.console_root_keys("https://console.example.com")
bad = 0
if roots.get("retired-root") != "not a real key":
    print("MISMATCH: a retired (active=false) root key was dropped")
    bad += 1
if roots.get(root_kid) != root_pub:
    print("MISMATCH: the active root key was not parsed from the console's {\"keys\": [...]} shape")
    bad += 1

case = next(c for c in data["cases"] if c["name"] == "valid")
try:
    es.verify_signature((vectors / case["sig"]).read_text(), root_keys=roots, sha256=case["sha256"],
                        manifest_id=case["manifest_id"], version=case["version"], sdk_version=case["sdk_version"],
                        trusted_publishers=case["trusted_publishers"], now=case["now"])
    got = "ok"
except es.SignatureError as exc:
    got = exc.code
if got != "ok":
    print(f"MISMATCH: the valid vector did not verify against the parsed console root keys (got {got})")
    bad += 1

print("console root-keys shape: ok" if not bad else "console root-keys shape: FAIL")
sys.exit(1 if bad else 0)
