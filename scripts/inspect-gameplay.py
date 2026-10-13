"""Read-only full-function disassembly using PE unwind bounds, including exports."""
import hashlib
import sys
from pathlib import Path
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

binary = Path(__file__).resolve().parents[2] / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data = binary.read_bytes()
assert hashlib.sha256(data).hexdigest() == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
image = pefile.PE(data=data)
base = image.OPTIONAL_HEADER.ImageBase
exports = {e.address + base: e.name.decode('ascii') for e in image.DIRECTORY_ENTRY_EXPORT.symbols if e.name}
decoder = Cs(CS_ARCH_X86, CS_MODE_64)
for argument in sys.argv[1:]:
    bounds = argument.split(':')
    address = int(bounds[0], 16)
    runtime = next((e.struct for e in image.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress <= address-base < e.struct.EndAddress), None)
    if len(bounds) == 2:
        end = int(bounds[1], 16)
        description = 'EXPLICIT RANGE (may include split unwind regions)'
    elif runtime:
        end = runtime.EndAddress + base
        description = 'UNWIND RANGE (not necessarily entire function)'
    else:
        print(f'NO UNWIND RANGE {address:x}; provide an explicit verified end')
        continue
    assert address < end <= address + 0x10000
    print(f'FUNCTION {address:x} END {end:x} {description} {exports.get(address, "")}')
    for ins in decoder.disasm(image.get_data(address-base, end-address), address):
        line = f'{ins.address:x}: {ins.mnemonic} {ins.op_str}'
        if ins.mnemonic in ['call', 'jmp'] and ins.op_str.startswith('0x'):
            line += ' ; ' + exports.get(int(ins.op_str, 16), '')
        if ins.mnemonic == 'lea' and ('rip +' in ins.op_str or 'rip -' in ins.op_str):
            sign = 1 if 'rip +' in ins.op_str else -1
            target = ins.address + ins.size + sign * int(ins.op_str.split('rip ')[1][2:].split(']')[0], 16)
            raw = image.get_data(target-base, 96).split(b'\0', 1)[0]
            if raw and all(32 <= x < 127 for x in raw): line += ' ; ' + raw.decode('ascii')
        print(line)
