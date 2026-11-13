"""Source/data-only recovery proof; never compiles, applies, or copies binaries."""
import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument("--plan", required=True)
parser.add_argument("--plan-sha", required=True)
parser.add_argument("--label", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]


def sha(file):
    with open(file, "rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load(file):
    return json.loads(Path(file).read_text(encoding="utf-8-sig"))


def pin(file):
    return {"file": str(file), "sha256": sha(file), "bytes": Path(file).stat().st_size}


assert args.label and all(c in "abcdefghijklmnopqrstuvwxyz0123456789-" for c in args.label)
plan_file = (root / args.plan).resolve()
assert sha(plan_file) == args.plan_sha
plan = load(plan_file)
source = Path(plan["source"])
output = root / ".cache/nwn71" / ("subset-recovery-" + args.label)
assert not output.exists(), "Preserve existing recovery evidence"
failed_file = Path(plan["output"]) / "build-receipt.json"
failed = load(failed_file)
assert failed["phase"] == "Build" and failed["exit"] == 0 and failed["success"] is False
assert failed["failure"] == "Unexpected compilation set; review dry-run before any build"
assert failed["sourceRestored"] and failed["protectedUnchanged"]
assert failed["planSha256"] == args.plan_sha
expected, actual = set(plan["expectedCompiles"]), set(failed["compiles"])
skipped = expected - actual
assert len(expected) == 217 and len(actual) == 211 and not actual - expected
assert skipped == {
    "platform/windows/godot_windows.cpp", "modules/gdscript/gdscript_vm.cpp",
    "servers/rendering/rendering_device.cpp", "core/profiling/nwn_tracy_bridge.cpp",
    "core/profiling/profiling.cpp", "core/os/memory.cpp",
}
stdout_file = Path(plan["output"]) / "build.stdout.log"
stdout = stdout_file.read_text(encoding="utf-8-sig").replace("\\", "/")
generated_lines = [line for line in stdout.splitlines() if line.startswith("Generating ")]
assert generated_lines == ["Generating core/profiling/profiling.gen.h ..."]
assert "Linking Program bin/godot.windows.template_release.x86_64.exe ..." in stdout

# methods.py was inherited from the pinned original archive, rather than listed
# separately in the61modified engine sources. Verify that lineage explicitly.
base = load(plan["basePlan"]["file"])
reconstruction = load(base["reconstruction"]["file"])
archive = reconstruction["archive"]
assert sha(archive["file"]) == archive["sha256"]
methods = source / "methods.py"
archive_methods = None
with tarfile.open(archive["file"], "r|gz") as tar:
    for member in tar:
        if member.name.endswith("/methods.py") and len(Path(member.name).parts) == 2:
            archive_methods = tar.extractfile(member).read()
            break
assert archive_methods is not None
assert hashlib.sha256(archive_methods).hexdigest() == sha(methods), "methods.py differs from inherited archive"
builder = source / "core/profiling/profiling_builders.py"
builder_pin = next(row for row in base["changes"] if row.get("relative") == "core/profiling/profiling_builders.py")
assert sha(builder) == builder_pin["sha256"]

for row in plan["changes"]:
    assert sha(row["file"]) == row["beforeSha256"]
    assert sha(row["afterFile"]) == row["afterSha256"]
for row in plan["protectedInputs"]:
    assert sha(row["file"]) == row["sha256"]
headers_verified = 0
for row in plan["headerClosure"]:
    assert sha(row["file"]) == row["sha256"], "Restored local header differs: " + row["file"]
    headers_verified += 1

output.mkdir(parents=True)
generator = output / "generator-source"
helper_files = ["methods.py", "platform_methods.py", "misc/utility/color.py", "core/profiling/profiling_builders.py"]
helper_pins = []
for relative in helper_files:
    original = source / relative
    destination = generator / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(original, destination)
    helper_pins.append({"relative": relative, "original": pin(original), "frozen": pin(destination)})
sys.dont_write_bytecode = True
sys.path.insert(0, str(generator))
sys.path.insert(0, str(generator / "core/profiling"))
profiling_builders = importlib.import_module("profiling_builders")
assert Path(profiling_builders.__file__).resolve() == (generator / "core/profiling/profiling_builders.py").resolve()
assert Path(sys.modules["methods"].__file__).resolve() == (generator / "methods.py").resolve()
requested = {"profiler": "tracy", "profiler_sample_callstack": False, "profiler_track_memory": False, "profiler_record_on_demand": True}
none = {**requested, "profiler": "none"}
headers = {}
for name, environment in [("reconstructed-none", none), ("reconstructed-tracy", requested), ("reconstructed-tracy-repeat", requested)]:
    file = output / name / "profiling.gen.h"
    file.parent.mkdir()
    profiling_builders.profiler_gen_builder([str(file)], [], environment)
    headers[name] = pin(file)
original_generated = next(row for row in plan["generatedRestore"] if row["file"].replace("\\", "/").endswith("/core/profiling/profiling.gen.h"))
assert headers["reconstructed-none"]["sha256"] == original_generated["sha256"], "Same builder/wrapper failed to reproduce captured prebuild header"
assert headers["reconstructed-tracy"]["sha256"] == headers["reconstructed-tracy-repeat"]["sha256"]
tracy_text = Path(headers["reconstructed-tracy"]["file"]).read_text(encoding="utf-8")
assert "#define GODOT_USE_TRACY" in tracy_text and "#define TRACY_PORT 48135" in tracy_text and "#define TRACY_ON_DEMAND" in tracy_text
assert "#define TRACY_CALLSTACK" not in tracy_text and "#define GODOT_PROFILER_TRACK_MEMORY" not in tracy_text

binary = source / plan["target"]
symbols = source / "bin/godot.windows.template_release.x86_64.pdb"
markers = ["NWN71/Shader/compile_group_wait", "NWN71/Shader/compile_variant", "pool=%p;group=%lld;shader=%s;variant_group=%d", "pool=%p;group=%lld;task=%lld;description=%s"]
found = {marker: False for marker in markers}
with binary.open("rb") as stream:
    tail = b""
    while chunk := stream.read(1024 * 1024):
        data = tail + chunk
        for marker in markers:
            found[marker] |= marker.encode() in data
        tail = data[-256:]
assert all(found.values()), "Re-linked binary lacks requested labeled CPP code"
shutil.copyfile(failed_file, output / "original-failed-build-receipt.json")
proposal = {
    "status": "recovery-proposal-not-promoted", "compiledAgain": False, "binaryCopied": False,
    "plan": pin(plan_file), "failedReceipt": pin(failed_file), "failedReceiptPreserved": pin(output / "original-failed-build-receipt.json"),
    "stdout": pin(stdout_file), "generatedStdoutLines": generated_lines,
    "subset": {"planned": len(expected), "actual": len(actual), "unexpected": [], "skipped": sorted(skipped)},
    "binary": pin(binary), "symbols": pin(symbols), "binaryMarkers": found,
    "restoration": {"cppExact": True, "protectedExact": True, "localHeadersExact": headers_verified},
    "generator": {"archive": archive, "methodsArchiveMatch": True, "helpers": helper_pins, "requestedEnvironment": requested,
        "outputs": headers, "prebuildNoneReproducedExactly": True, "deterministicRepeat": True,
        "evidenceType": "Reconstruction after build from the same pinned builder and archive-verified methods.py. The Tracy header was NOT captured after compilation. Original failed receipt remains unchanged."},
    "port": 48135,
    "scope": "Explicit211-of217 incremental build recovery proposal only. No new compilation or accepted/selected artifact writes; root independently approves/copies before diagnostic capture. No normal-engine/FPS/optimization acceptance.",
}
(output / "recovery-proposal.json").write_text(json.dumps(proposal, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"proposal": str(output / "recovery-proposal.json"), "sha256": sha(output / "recovery-proposal.json"), "binary": proposal["binary"], "symbols": proposal["symbols"], "reconstructedTracy": headers["reconstructed-tracy"], "headersVerified": headers_verified}))
