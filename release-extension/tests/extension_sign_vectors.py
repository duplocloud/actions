"""Runs every case in tests/vectors/cases.json through extension-sign.py's verifier and checks the recorded outcome."""
import importlib.util, json, pathlib, sys

HERE = pathlib.Path(__file__).parent
spec = importlib.util.spec_from_file_location("extension_sign", HERE.parent / "scripts" / "extension-sign.py")
es = importlib.util.module_from_spec(spec)
spec.loader.exec_module(es)

vectors = HERE / "vectors"
data = json.loads((vectors / "cases.json").read_text())
roots = {kid: (vectors / name).read_text() for kid, name in data["root_keys"].items()}
bad = 0
for case in data["cases"]:
    try:
        es.verify_signature((vectors / case["sig"]).read_text(), root_keys=roots, sha256=case["sha256"],
                            manifest_id=case["manifest_id"], version=case["version"],
                            sdk_version=case["sdk_version"], trusted_publishers=case["trusted_publishers"],
                            now=case["now"])
        got = "ok"
    except es.SignatureError as exc:
        got = exc.code
    if got != case["expect"]:
        print(f"MISMATCH {case['name']}: expected {case['expect']}, got {got}")
        bad += 1
print(f"{len(data['cases']) - bad} of {len(data['cases'])} vector cases match")
sys.exit(1 if bad else 0)
