"""Execute two bounded original timer slices in private Unicorn memory.

This is an instruction oracle, not a Python implementation of the conversion.
WinAPI results, CPU/MXCSR, and configuration inputs are controlled. The original
16dd60 configuration prefix is stopped before GetTickCount/cache/thread work.
No original process, system clock API, compiler, engine, or network is invoked.
Run only through the reviewed, bounded test-native-clock-real-oracle.mjs wrapper.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time

sys.dont_write_bytecode = True

WORKSPACE = Path(__file__).resolve().parents[2]
DEPENDENCIES = WORKSPACE / "backups/research-python"
BINARY = WORKSPACE.parent / "FullDecomp/NwnRootInstall/bin/win32/nwmain.exe"
BINARY_SHA256 = "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
BASE = 0x140000000
CONFIG_START, CONFIG_STOP = 0x14016DD60, 0x14016DDE2
REAL_START, REAL_END = 0x14016E110, 0x14016E16F
HEAP, STACK, STUBS = 0x200000000, 0x300000000, 0x400000000
HEAP_SIZE, STACK_SIZE = 0x10000, 0x10000
RETURN, QPF, QPC, TICKS = STUBS, STUBS + 0x100, STUBS + 0x200, STUBS + 0x300
IATS = {0x140D7C868: QPF, 0x140D7C908: QPC, 0x140D7C950: TICKS}
MXCSR = 0x1F80  # Explicit controlled round-to-nearest, masked FP exceptions.
MASK64 = (1 << 64) - 1
LIMITS = {
    "binaryBytes": 128 * 1024 * 1024,
    "mappedImageBytes": 128 * 1024 * 1024,
    "configurationCases": 16,
    "realCases": 128,
    "configurationInstructions": 512,
    "realInstructions": 256,
    "emulationTimeoutMicrosecondsPerCall": 100000,
    "wallSeconds": 30,
    "resultBytes": 512 * 1024,
    "dependencyBytes": 64 * 1024 * 1024,
    "dependencyFiles": 256,
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def words(value: int) -> dict:
    value &= MASK64
    return {
        "unsignedDecimal": str(value),
        "signedDecimal": str(value if value < (1 << 63) else value - (1 << 64)),
        "hi": value >> 32,
        "lo": value & 0xFFFFFFFF,
        "hex": f"{value:016x}",
    }


def source_rows() -> list[dict]:
    relatives = [
        "godot-client/tools/native-clock-real-oracle.py",
        "godot-client/tools/test-native-clock-real-oracle.mjs",
        "godot-client/NATIVE-REMOTE-CLIENT-CLOCK-LIFECYCLE.md",
        "godot-client/reports/native-remote-client-clock-lifecycle-v1.json",
        "scripts/inspect-native-intratile-coordinator.py",
        "scripts/inspect-native-client-pause.py",
    ]
    return [{"path": name, "sha256": digest((WORKSPACE / name).read_bytes())} for name in relatives]


def dependency_rows() -> list[dict]:
    # Pin existing files only; -B prevents importing them from writing pycache.
    candidates = [DEPENDENCIES / "pefile.py"]
    candidates += sorted(p for p in (DEPENDENCIES / "unicorn").rglob("*")
                         if p.is_file() and p.suffix.lower() in (".py", ".dll", ".pyd"))
    for name in ("pefile-2024.8.26.dist-info/METADATA", "unicorn-2.1.4.dist-info/METADATA"):
        candidates.append(DEPENDENCIES / name)
    if len(candidates) > LIMITS["dependencyFiles"]:
        raise RuntimeError("Dependency file bound exceeded")
    total, rows = 0, []
    for p in candidates:
        size = p.stat().st_size
        total += size
        if total > LIMITS["dependencyBytes"]:
            raise RuntimeError("Dependency byte bound exceeded")
        rows.append({"path": p.relative_to(WORKSPACE).as_posix(), "bytes": size,
                     "sha256": digest(p.read_bytes())})
    return rows


def changed(rows: list[dict]) -> list[str]:
    return [r["path"] for r in rows if digest((WORKSPACE / r["path"]).read_bytes()) != r["sha256"]]


def matrix() -> tuple[list[dict], list[dict]]:
    frequencies = [1, 1000000, 10000000, 199999999, 200000000, 200000001,
                   999999999, 1000000000, (1 << 63) - 1]
    configs = [{"id": f"qpf-{f}", "qpfResult": 1, "frequency": f} for f in frequencies]
    configs += [{"id": f"qpf-result-{r}", "qpfResult": r, "frequency": 10000000}
                for r in (0, 2)]
    counter_bits = [0, 1, 999, 1000, (1 << 32) - 1, (1 << 53) - 1,
                    1 << 53, (1 << 53) + 1, (1 << 63) - 1, 1 << 63, MASK64]
    rows = []
    for cfg in configs[:len(frequencies)]:
        for q in counter_bits:
            rows.append({"id": f"{cfg['id']}-q-{q:016x}", "configurationId": cfg["id"],
                         "qpcBits": q, "qpcSucceeds": True, "tickDword": 0,
                         "scratchSeed": 0xA5A5A5A5A5A5A5A5})
    for cfg in configs[len(frequencies):]:
        for index, tick in enumerate((0, 1, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFE, 0xFFFFFFFF, 0)):
            rows.append({"id": f"{cfg['id']}-tick-{index}-{tick:08x}", "configurationId": cfg["id"],
                         "qpcBits": 0, "qpcSucceeds": True, "tickDword": tick,
                         "scratchSeed": 0xA5A5A5A5A5A5A5A5,
                         "sequenceLabel": "after-dword-wrap" if index == 6 else "tick-sample"})
    for f in (10000000, 200000000):
        for seed in (0, 0x1122334455667788):
            rows.append({"id": f"qpf-{f}-qpc-failure-seed-{seed:016x}",
                         "configurationId": f"qpf-{f}", "qpcBits": 0,
                         "qpcSucceeds": False, "tickDword": 123,
                         "scratchSeed": seed})
    if len(configs) > LIMITS["configurationCases"] or len(rows) > LIMITS["realCases"]:
        raise RuntimeError("Authored matrix exceeds bound")
    return configs, rows


class Oracle:
    def __init__(self, binary: bytes):
        # Deferred imports: merely reading/compiling this file does not emulate.
        sys.path.insert(0, str(DEPENDENCIES))
        import pefile
        import unicorn
        from unicorn import x86_const as x
        if pefile.__version__ != "2024.8.26" or unicorn.__version__ != "2.1.4":
            raise RuntimeError("Unexpected existing pefile/Unicorn runtime")
        for module in (pefile, unicorn):
            Path(module.__file__).resolve().relative_to(DEPENDENCIES.resolve())
        self.versions = {"python": sys.version, "pefile": pefile.__version__,
                         "unicorn": unicorn.__version__, "pythonExecutable": sys.executable}
        self.unicorn, self.x = unicorn, x
        pe = pefile.PE(data=binary)
        if pe.OPTIONAL_HEADER.ImageBase != BASE or pe.FILE_HEADER.Machine != 0x8664:
            raise RuntimeError("Unexpected native image architecture/base")
        size = (pe.OPTIONAL_HEADER.SizeOfImage + 4095) & ~4095
        if size > LIMITS["mappedImageBytes"]:
            raise RuntimeError("Mapped image exceeds bound")
        image = pe.get_memory_mapped_image()
        self.ranges = [{"name": name, "start": hex(lo), "endExclusive": hex(hi),
                        "sha256": digest(image[lo - BASE:hi - BASE])}
                       for name, lo, hi in (("configuration-prefix", CONFIG_START, CONFIG_STOP),
                                            ("GetMicrosecondTimerReal", REAL_START, REAL_END))]
        self.original_iats = {hex(addr): bytes(image[addr - BASE:addr - BASE + 8]).hex()
                              for addr in IATS}
        u = self.u = unicorn.Uc(unicorn.UC_ARCH_X86, unicorn.UC_MODE_64)
        u.ctl_set_cpu_model(x.UC_CPU_X86_HASWELL)
        u.mem_map(BASE, size)
        u.mem_write(BASE, image)
        for addr, target in IATS.items():
            u.mem_write(addr, struct.pack("<Q", target))
        # All native instruction writes must remain in private stack/config.
        u.mem_protect(BASE, size, unicorn.UC_PROT_READ | unicorn.UC_PROT_EXEC)
        u.mem_map(HEAP, HEAP_SIZE, unicorn.UC_PROT_READ | unicorn.UC_PROT_WRITE)
        u.mem_map(STACK, STACK_SIZE, unicorn.UC_PROT_READ | unicorn.UC_PROT_WRITE)
        u.mem_map(STUBS, 0x1000)
        u.mem_write(STUBS, b"\xcc" * 0x1000)
        u.mem_protect(STUBS, 0x1000, unicorn.UC_PROT_READ | unicorn.UC_PROT_EXEC)
        self.baseline = u.context_save()
        self.current, self.trace, self.api_calls = None, [], []
        self.completed, self.kind, self.instruction_limit = False, None, 0
        u.hook_add(unicorn.UC_HOOK_CODE, self.code_hook)
        u.hook_add(unicorn.UC_HOOK_MEM_WRITE, self.write_hook)

    def q(self, address: int) -> int:
        return int.from_bytes(self.u.mem_read(address, 8), "little")

    def finish_api(self, result: int) -> None:
        rsp = self.u.reg_read(self.x.UC_X86_REG_RSP)
        self.u.reg_write(self.x.UC_X86_REG_RIP, self.q(rsp))
        self.u.reg_write(self.x.UC_X86_REG_RSP, rsp + 8)
        self.u.reg_write(self.x.UC_X86_REG_RAX, result & MASK64)

    def write_hook(self, _u, _access, address, size, _value, _user) -> None:
        if not (STACK <= address and address + size <= STACK + STACK_SIZE) and not (
                HEAP <= address and address + size <= HEAP + 0x38):
            raise RuntimeError(f"Native write escapes private stack/config: {address:x}/{size}")

    def output_pointer(self) -> int:
        pointer = self.u.reg_read(self.x.UC_X86_REG_RCX)
        if not STACK <= pointer <= STACK + STACK_SIZE - 8:
            raise RuntimeError("Controlled WinAPI output pointer escapes private stack")
        return pointer

    def code_hook(self, _u, address, _size, _user) -> None:
        if ((self.kind == "config" and address == CONFIG_STOP) or
                (self.kind == "real" and address == RETURN)):
            self.completed = True
            self.u.emu_stop()
            return
        self.trace.append(hex(address))
        if len(self.trace) > self.instruction_limit:
            raise RuntimeError("Native instruction limit exceeded")
        c = self.current
        if address == QPF and self.kind == "config":
            pointer = self.output_pointer()
            writes = c["qpfResult"] != 0
            if writes:
                self.u.mem_write(pointer, struct.pack("<Q", c["frequency"] & MASK64))
            self.api_calls.append({"api": "QueryPerformanceFrequency", "result": c["qpfResult"],
                                   "writesOutput": writes,
                                   "outputBitsHex": f"{c['frequency'] & MASK64:016x}" if writes else None})
            self.finish_api(c["qpfResult"])
        elif address == QPC and self.kind == "real":
            pointer = self.output_pointer()
            if c["qpcSucceeds"]:
                self.u.mem_write(pointer, struct.pack("<Q", c["qpcBits"]))
            self.api_calls.append({"api": "QueryPerformanceCounter", "result": int(c["qpcSucceeds"]),
                                   "writesOutput": c["qpcSucceeds"],
                                   "outputBitsHex": f"{c['qpcBits']:016x}" if c["qpcSucceeds"] else None})
            self.finish_api(int(c["qpcSucceeds"]))
        elif address == TICKS and self.kind == "real":
            self.api_calls.append({"api": "GetTickCount", "resultDword": c["tickDword"]})
            self.finish_api(c["tickDword"])
        elif not ((self.kind == "config" and CONFIG_START <= address < CONFIG_STOP) or
                  (self.kind == "real" and REAL_START <= address < REAL_END)):
            raise RuntimeError(f"Uncaptured native dependency at {address:x}")

    def begin(self, kind: str, control: dict, config: bytes | None = None) -> int:
        self.u.context_restore(self.baseline)
        self.u.mem_write(HEAP, config if config is not None else b"\xa5" * 0x38)
        self.u.mem_write(STACK, b"\xa5" * STACK_SIZE)
        rsp = STACK + 0xF008  # Windows x64 function-entry alignment, caller home area available.
        self.u.mem_write(rsp, struct.pack("<Q", RETURN))
        self.u.reg_write(self.x.UC_X86_REG_RSP, rsp)
        self.u.reg_write(self.x.UC_X86_REG_RCX, HEAP)
        self.u.reg_write(self.x.UC_X86_REG_MXCSR, MXCSR)
        self.current, self.kind = control, kind
        self.completed, self.trace, self.api_calls = False, [], []
        self.instruction_limit = LIMITS["configurationInstructions" if kind == "config" else "realInstructions"]
        if kind == "real":
            # QPC's local output is the caller home slot at entry RSP+8.
            self.u.mem_write(rsp + 8, struct.pack("<Q", control["scratchSeed"]))
        return rsp

    def execute(self, start: int) -> dict:
        self.u.emu_start(start, 0, timeout=LIMITS["emulationTimeoutMicrosecondsPerCall"],
                         count=self.instruction_limit)
        if not self.completed:
            raise RuntimeError(f"Native slice did not reach its stop: {self.u.reg_read(self.x.UC_X86_REG_RIP):x}")
        return {"instructionCount": len(self.trace) - len(self.api_calls),
                "hookSteps": len(self.trace), "trace": list(self.trace),
                "apiCalls": list(self.api_calls), "mxcsrBefore": MXCSR,
                "mxcsrAfter": self.u.reg_read(self.x.UC_X86_REG_MXCSR)}

    def configuration(self, c: dict) -> tuple[dict, bytes]:
        self.begin("config", c)
        evidence = self.execute(CONFIG_START)
        data = bytes(self.u.mem_read(HEAP, 0x38))
        raw_result, flag = struct.unpack_from("<II", data)
        branch = "fallback" if raw_result != 1 else "double" if flag == 1 else "integer"
        if len(evidence["apiCalls"]) != 1 or evidence["apiCalls"][0]["api"] != "QueryPerformanceFrequency":
            raise RuntimeError("Configuration prefix did not make exactly one controlled QPF call")
        return {"id": c["id"], "method": "original-16dd60-prefix-before-16dde2",
                "control": {"qpfResult": c["qpfResult"], "frequencyKnown": c["qpfResult"] != 0,
                            "frequencyBitsHex": f"{c['frequency'] & MASK64:016x}",
                            "frequencySignedDecimal": words(c["frequency"])["signedDecimal"]},
                "native": {"qpfResult": raw_result, "branch": branch,
                           "frequencyKnown": raw_result == 1,
                           "frequencyBitsHex": data[8:16][::-1].hex() if raw_result == 1 else None,
                           "branchDword": flag if raw_result == 1 else None,
                           "divisorBitsHex": data[0x18:0x20][::-1].hex() if branch == "double" else None,
                           "integerDivisorDecimal": str(int.from_bytes(data[0x10:0x18], "little"))
                           if branch == "integer" else None}, **evidence}, data

    def real(self, c: dict, prepared: bytes, branch: str) -> dict:
        rsp = self.begin("real", c, prepared)
        evidence = self.execute(REAL_START)
        if self.u.reg_read(self.x.UC_X86_REG_RSP) != rsp + 8:
            raise RuntimeError("Original Real did not restore its stack")
        expected_api = "GetTickCount" if branch == "fallback" else "QueryPerformanceCounter"
        if len(evidence["apiCalls"]) != 1 or evidence["apiCalls"][0]["api"] != expected_api:
            raise RuntimeError("Real slice did not make its one branch-specific controlled API call")
        defined = branch == "fallback" or c["qpcSucceeds"]
        result = words(self.u.reg_read(self.x.UC_X86_REG_RAX))
        row = {"id": c["id"], "configurationId": c["configurationId"],
               "input": {"qpcBitsHex": f"{c['qpcBits']:016x}" if branch != "fallback" else None,
                         "qpcSignedDecimal": words(c["qpcBits"])["signedDecimal"] if branch != "fallback" else None,
                         "qpcSucceeds": c["qpcSucceeds"] if branch != "fallback" else None,
                         "rawQpcKnown": branch != "fallback" and c["qpcSucceeds"],
                         "tickDword": c["tickDword"], "scratchSeedHex": f"{c['scratchSeed']:016x}"},
               "defined": defined, "result": result if defined else None, **evidence}
        if not defined:
            row.update(reason="QPC failed without writing its output; original ignores the return BOOL",
                       diagnosticRax=result, diagnosticOnly=True)
        if "sequenceLabel" in c:
            row["sequenceLabel"] = c["sequenceLabel"]
        return row


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve()
    evidence_root = (WORKSPACE / "godot-client/.cache/native-clock-real-oracle").resolve()
    output.relative_to(evidence_root)
    if output.name != "result.json" or output.exists() or not output.parent.is_dir():
        raise RuntimeError("Require a fresh wrapper-owned result.json evidence path")
    # Refuse accidental direct use without the wrapper's exact safety contract.
    if os.environ.get("NATIVE_CLOCK_REAL_ORACLE_BOUNDED") != "35s-512KiB-v1":
        raise RuntimeError("Use the reviewed bounded Node wrapper")
    started = time.monotonic()
    inputs = source_rows()
    dependencies = dependency_rows()
    if BINARY.stat().st_size > LIMITS["binaryBytes"]:
        raise RuntimeError("Original binary exceeds bound")
    binary = BINARY.read_bytes()
    if digest(binary) != BINARY_SHA256:
        raise RuntimeError("Original binary SHA256 differs")
    configurations, cases = matrix()
    report = {"version": 1, "success": False, "method": "original-instructions-unicorn",
              "binarySha256": BINARY_SHA256, "limits": LIMITS, "inputs": inputs,
              "dependencies": dependencies, "configurations": [], "rows": [],
              "cpu": {"architecture": "x86_64", "model": "Haswell", "mxcsr": MXCSR, "controlled": True},
              "scope": "Original 16dd60 preparation prefix and 16e110 instructions with controlled WinAPI results. "
                       "No full constructor/thread, live WinAPI equivalence, cached timer phase, or runtime clock admission.",
              "serverConnections": 0, "keyReads": 0, "profileReads": 0, "gpu": False,
              "userProcessActions": 0, "nativeBuilds": 0}
    try:
        oracle = Oracle(binary)
        report.update(runtime=oracle.versions, nativeRanges=oracle.ranges,
                      originalIatBytes=oracle.original_iats)
        prepared = {}
        for c in configurations:
            if time.monotonic() - started > LIMITS["wallSeconds"]:
                raise RuntimeError("Oracle wall bound exceeded")
            row, data = oracle.configuration(c)
            report["configurations"].append(row)
            prepared[c["id"]] = data, row["native"]["branch"]
        for case in cases:
            if time.monotonic() - started > LIMITS["wallSeconds"]:
                raise RuntimeError("Oracle wall bound exceeded")
            data, branch = prepared[case["configurationId"]]
            report["rows"].append(oracle.real(case, data, branch))
        report["success"] = True
    except Exception as error:
        # Unsupported instructions/dependencies are rejected evidence, never a
        # reason to substitute formula-produced expected rows.
        report["error"] = f"{type(error).__name__}: {error}"
    report["guards"] = {"changedInputs": changed(inputs), "changedDependencies": changed(dependencies),
                        "binaryUnchanged": digest(BINARY.read_bytes()) == BINARY_SHA256}
    report["success"] = bool(report["success"] and not report["guards"]["changedInputs"]
                             and not report["guards"]["changedDependencies"]
                             and report["guards"]["binaryUnchanged"])
    report["elapsedSeconds"] = time.monotonic() - started
    encoded = (json.dumps(report, indent=2, allow_nan=False) + "\n").encode("utf-8")
    if len(encoded) > LIMITS["resultBytes"]:
        raise RuntimeError("Oracle JSON result exceeds512KiB; no truncated result accepted")
    with output.open("xb") as handle:
        handle.write(encoded)
    print(json.dumps({"success": report["success"], "configurations": len(report["configurations"]),
                      "rows": len(report["rows"]), "definedRows": sum(r["defined"] for r in report["rows"]),
                      "output": str(output), "sha256": digest(encoded), "error": report.get("error")}))
    if not report["success"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
