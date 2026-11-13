"""Bounded, hash-gated original PE data/code reads; no process or network access."""
import hashlib
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backups/research-python"))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

binary, output = map(Path, sys.argv[1:])
digest = hashlib.sha256(binary.read_bytes()).hexdigest()
if digest != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":
    raise ValueError("Original executable digest differs")
if output.exists():
    raise ValueError("Use a new evidence path")
pe = pefile.PE(str(binary), fast_load=True)
base = pe.OPTIONAL_HEADER.ImageBase
def read(address, count):
    return pe.get_data(address - base, count)
def number(address, fmt):
    return struct.unpack(fmt, read(address, struct.calcsize(fmt)))[0]
decoder = Cs(CS_ARCH_X86, CS_MODE_64)
contexts = {}
# Provider-established instruction boundaries, not inferred function starts.
for address, count in [(0x1400d1c8a, 0x70), (0x1400d1e43, 0x70)]:
    contexts[hex(address)] = [f"{hex(i.address)}: {i.mnemonic} {i.op_str}" for i in decoder.disasm(read(address, count), address)]
result = {"binary_sha256": digest, "read_only": True, "process_access": False,
          "lower": number(0x14129748c, "<f"), "upper": number(0x14129749c, "<f"),
          "scale": number(0x140e462b8, "<d"), "contexts": contexts,
          "scope": "Static original vision threshold initializers and bounded focus-light writer contexts. No live state or vision acceptance."}
output.write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result))
