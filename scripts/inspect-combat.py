"""Read-only bounded native combat disassembly for the recorded target build."""
import argparse
import hashlib
from functools import lru_cache
from pathlib import Path
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

parser = argparse.ArgumentParser()
parser.add_argument('addresses', nargs='*', help='Hex function addresses, or start:end ranges for verified leaf functions')
parser.add_argument('--data', nargs='+', default=[], help='Hex addresses of native constants to inspect as bytes/u16/i32/f32')
parser.add_argument('--u32-table', nargs='+', default=[], help='Hex address:decimal count of a bounded u32 table')
parser.add_argument('--u8-table', nargs='+', default=[], help='Hex address:decimal count of a bounded byte table')
parser.add_argument('--field', nargs='+', default=[], help='Hex native field displacements to locate in bounded unwind functions')
parser.add_argument('--strings', nargs='+', default=[], help='Hex addresses of null-terminated strings, bounded to 256 bytes')
parser.add_argument('--find-text', nargs='+', default=[], help='Find exact ASCII text in the read-only image and print containing strings (256 bytes maximum)')
args = parser.parse_args()
binary = Path(__file__).resolve().parents[2] / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data = binary.read_bytes()
assert hashlib.sha256(data).hexdigest() == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
image = pefile.PE(data=data)
base = image.OPTIONAL_HEADER.ImageBase
for value in args.strings:
    address = int(value, 16)
    raw = image.get_data(address-base, 256).split(b'\0', 1)[0]
    print(f'STRING {address:x}: {raw.decode("ascii", errors="replace")}')
for value in args.find_text:
    needle, offset = value.encode('ascii'), 0
    while (offset := data.find(needle, offset)) >= 0:
        begin = max(data.rfind(b'\0', max(0, offset-256), offset)+1, offset-256)
        end = data.find(b'\0', offset, offset+256)
        if end < 0:
            end = offset+256
        print(f'TEXT MATCH {base+image.get_rva_from_offset(offset):x}: {data[begin:end].decode("ascii", errors="replace")}')
        offset += len(needle)
for value in args.u8_table:
    address, count = value.split(':')
    address, count = int(address, 16), int(count)
    assert 0 < count <= 256
    print(f'U8 TABLE {address:x}: ' + ', '.join(str(n) for n in image.get_data(address-base, count)))
if args.u32_table:
    import struct
    for value in args.u32_table:
        address, count = value.split(':')
        address, count = int(address, 16), int(count)
        assert 0 < count <= 256
        raw = image.get_data(address-base, count*4)
        print(f'U32 TABLE {address:x}: ' + ', '.join(f'{n:x}' for n in struct.unpack(f'<{count}I', raw)))
if args.data:
    import struct
    for value in args.data:
        address = int(value, 16)
        raw = image.get_data(address-base, 8)
        print(f'DATA {address:x}: {raw.hex()} u16={struct.unpack_from("<H", raw)[0]} i32={struct.unpack_from("<i", raw)[0]} f32={struct.unpack_from("<f", raw)[0]}')
decoder = Cs(CS_ARCH_X86, CS_MODE_64)
runtime_by_begin = {entry.struct.BeginAddress: entry.struct for entry in image.DIRECTORY_ENTRY_EXCEPTION}
if args.field:
    import struct
    wanted = {int(value, 16) for value in args.field}
    section = next(s for s in image.sections if s.Name.rstrip(b'\0') == b'.text')
    code = section.get_data()
    begins = set()
    for value in wanted:
        needle, offset = struct.pack('<I', value), 0
        while (offset := code.find(needle, offset)) >= 0:
            rva = section.VirtualAddress + offset
            runtime = next((entry.struct for entry in image.DIRECTORY_ENTRY_EXCEPTION
                            if entry.struct.BeginAddress <= rva < entry.struct.EndAddress), None)
            if runtime:
                begins.add(runtime.BeginAddress)
            offset += 1
    # These are candidate accesses, not semantic claims or executed paths.
    for begin in sorted(begins):
        runtime = runtime_by_begin[begin]
        for insn in decoder.disasm(image.get_data(begin, runtime.EndAddress-begin), base+begin):
            if any(f' + 0x{value:x}]' in insn.op_str for value in wanted):
                print(f'FIELD CANDIDATE FUNCTION {base+begin:x}: {insn.address:x}: {insn.mnemonic} {insn.op_str}')
@lru_cache(None)
def unwind_root(begin_address):
    """Chained unwind entries split some native bodies into multiple ranges."""
    runtime = runtime_by_begin[begin_address]
    unwind = image.get_data(runtime.UnwindData, 4)
    if (unwind[0] >> 3) & 4:
        chained = runtime.UnwindData + 4 + ((unwind[2] + 1) & ~1) * 2
        begin = image.get_dword_at_rva(chained)
        return unwind_root(begin)
    return runtime.BeginAddress

for value in args.addresses:
    address = int(value.split(':')[0], 16)
    if ':' in value:
        ranges = [(address, int(value.split(':')[1], 16))]
        assert address < ranges[0][1]
    else:
        runtime = next((entry.struct for entry in image.DIRECTORY_ENTRY_EXCEPTION
                        if entry.struct.BeginAddress <= address-base < entry.struct.EndAddress), None)
        if runtime is None:
            raise ValueError(f'{value}: no unwind entry; supply a verified start:end leaf range')
        ranges = sorted((entry.struct.BeginAddress + base, entry.struct.EndAddress + base)
                        for entry in image.DIRECTORY_ENTRY_EXCEPTION
                        if unwind_root(entry.struct.BeginAddress) == unwind_root(runtime.BeginAddress))
    print(f'FUNCTION REQUESTED {address:x} RANGES ' + ', '.join(f'{start:x}:{end:x}' for start, end in ranges))
    for start, end in ranges:
        for instruction in decoder.disasm(image.get_data(start-base, end-start), start):
            line = f'{instruction.address:x}: {instruction.mnemonic} {instruction.op_str}'
            if 'rip +' in instruction.op_str or 'rip -' in instruction.op_str:
                sign = 1 if 'rip +' in instruction.op_str else -1
                target = instruction.address + instruction.size + sign * int(instruction.op_str.split('rip ')[1][2:].split(']')[0], 16)
                try:
                    raw = image.get_data(target-base, 120).split(b'\0', 1)[0]
                    if raw and all(32 <= byte < 127 for byte in raw):
                        line += ' ; ' + raw.decode('ascii')
                except pefile.PEFormatError:
                    # Unwind ranges can contain embedded switch tables which
                    # linear disassembly interprets as instructions. Preserve
                    # the line, flag the unmapped operand, and inspect later
                    # functions; never label it as a verified code path.
                    line += ' ; unmapped RIP-relative operand; may be embedded data'
            print(line)
