"""Read-only native character research; never modifies the binary or Ghidra."""
import hashlib
from pathlib import Path
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

binary = Path(__file__).resolve().parents[2] / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data = binary.read_bytes()
assert hashlib.sha256(data).hexdigest() == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
image = pefile.PE(data=data)
base = image.OPTIONAL_HEADER.ImageBase
decoder = Cs(CS_ARCH_X86, CS_MODE_64)
for address in [0x140415640, 0x14040f7f0, 0x1403975e0, 0x1402a4a90, 0x14046dcd0, 0x140393340, 0x14055c300]:
    runtime = next(e.struct for e in image.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress <= address-base < e.struct.EndAddress)
    print(f'FUNCTION {address:x} END {runtime.EndAddress+base:x}')
    for ins in decoder.disasm(image.get_data(address-base, runtime.EndAddress-(address-base)), address):
        line = f'{ins.address:x}: {ins.mnemonic} {ins.op_str}'
        if ins.mnemonic == 'lea' and ('rip +' in ins.op_str or 'rip -' in ins.op_str):
            sign = 1 if 'rip +' in ins.op_str else -1
            target = ins.address + ins.size + sign * int(ins.op_str.split('rip ')[1][2:].split(']')[0], 16)
            raw = image.get_data(target-base, 96).split(b'\0', 1)[0]
            if raw and all(32 <= x < 127 for x in raw): line += ' ; ' + raw.decode('ascii')
        print(line)
for address in [0x140ee45f8, 0x140dd3050]:
    import struct
    print(f'CONSTANT {address:x}: {struct.unpack("<d", image.get_data(address-base,8))[0]}')
