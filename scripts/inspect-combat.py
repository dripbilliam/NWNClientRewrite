"""Read-only bounded native combat disassembly for the recorded target build."""
import argparse
import hashlib
import sys
from functools import lru_cache
from pathlib import Path
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
sys.stdout.reconfigure(errors='backslashreplace')

parser = argparse.ArgumentParser()
parser.add_argument('addresses', nargs='*', help='Hex function addresses, or start:end ranges for verified leaf functions')
parser.add_argument('--data', nargs='+', default=[], help='Hex addresses of native constants to inspect as bytes/u16/i32/f32')
parser.add_argument('--u32-table', nargs='+', default=[], help='Hex address:decimal count of a bounded u32 table')
parser.add_argument('--u64-table', nargs='+', default=[], help='Hex address:decimal count of a bounded u64 table (for verified pointer tables)')
parser.add_argument('--u8-table', nargs='+', default=[], help='Hex address:decimal count of a bounded byte table')
parser.add_argument('--field', nargs='+', default=[], help='Hex native field displacements to locate in bounded unwind functions')
parser.add_argument('--strings', nargs='+', default=[], help='Hex addresses of null-terminated strings, bounded to 256 bytes')
parser.add_argument('--find-text', nargs='+', default=[], help='Find exact ASCII text in the read-only image and print containing strings (256 bytes maximum)')
parser.add_argument('--find-export', nargs='+', default=[], help='Find matching named exports in the verified read-only image (maximum 200 per query)')
parser.add_argument('--leaf-cfg', nargs='+', default=[], help='Verified direct-call leaf starts: decode reachable direct branches to returns, bounded to 512 bytes; do not infer starts')
parser.add_argument('--leaf-byte-limit', type=int, default=512, choices=[512,1024,2048,4096], help='Explicit bound for a verified larger leaf CFG (default512, max4096); never infer an entry from this range')
parser.add_argument('--head-block', nargs='+', default=[], help='Verified call/branch targets only: inspect one basic block, bounded128 bytes; not a complete function boundary')
parser.add_argument('--ascii-range', nargs='+', default=[], help='Hex address:decimal length of a bounded null-separated ASCII string pool (maximum4096 bytes)')
parser.add_argument('--references', nargs='+', default=[], help='Hex addresses whose RIP-relative or pointer references should be located; candidate references require instruction verification')
parser.add_argument('--type-vtables', nargs='+', default=[], help='Hex MSVC type-descriptor addresses to locate verified complete-object-locator vtable headers')
args = parser.parse_args()
binary = Path(__file__).resolve().parents[2] / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data = binary.read_bytes()
assert hashlib.sha256(data).hexdigest() == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
image = pefile.PE(data=data)
base = image.OPTIONAL_HEADER.ImageBase
for value in args.type_vtables:
    import struct
    address=int(value,16);needle=struct.pack('<I',address-base);offset=0
    while (offset:=data.find(needle,offset))>=0:
        start=offset-12
        if start>=0 and start+24<=len(data):
            record=struct.unpack_from('<6I',data,start)
            rva=image.get_rva_from_offset(start)
            if record[0]==1 and record[5]==rva:
                locator=base+rva;pointer=struct.pack('<Q',locator);at=0
                while (at:=data.find(pointer,at))>=0:
                    print(f'TYPE VTABLE {base+image.get_rva_from_offset(at)+8:x} LOCATOR {locator:x} TYPE {address:x} OFFSET {record[1]:x}');at+=8
        offset+=4
for value in args.ascii_range:
    address,length=value.split(':');address,length=int(address,16),int(length)
    assert 0<length<=4096
    raw=image.get_data(address-base,length);offset=0
    for piece in raw.split(b'\0'):
        if piece and all(32<=n<127 for n in piece):print(f'ASCII {address+offset:x}: {piece.decode("ascii")}')
        offset+=len(piece)+1
if args.references:
    import struct
    section=next(s for s in image.sections if s.Name.rstrip(b'\0')==b'.text')
    code=section.get_data();origin=base+section.VirtualAddress
    for value in args.references:
        address=int(value,16);low=(address-origin-4)&255
        for offset in range(len(code)-3):
            if (code[offset]+offset)&255!=low:continue
            if origin+offset+4+struct.unpack_from('<i',code,offset)[0]!=address:continue
            rva=section.VirtualAddress+offset
            runtime=next((e.struct for e in image.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=rva<e.struct.EndAddress),None)
            print(f'REFERENCE CANDIDATE {origin+offset:x} -> {address:x} FUNCTION {base+runtime.BeginAddress:x}' if runtime else f'REFERENCE CANDIDATE {origin+offset:x} -> {address:x} NO UNWIND')
        needle=struct.pack('<Q',address);offset=0
        while (offset:=data.find(needle,offset))>=0:
            print(f'POINTER REFERENCE {base+image.get_rva_from_offset(offset):x} -> {address:x}');offset+=8
for value in args.find_export:
    matches = [entry for entry in image.DIRECTORY_ENTRY_EXPORT.symbols
               if entry.name and value.lower() in entry.name.decode('ascii').lower()]
    if len(matches) > 200:
        raise ValueError('Export query is too broad; use a more specific symbol')
    for entry in matches:
        print(f'EXPORT {base+entry.address:x}: {entry.name.decode("ascii")}')
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
if args.u64_table:
    import struct
    for value in args.u64_table:
        address, count = value.split(':')
        address, count = int(address, 16), int(count)
        assert 0 < count <= 256
        raw = image.get_data(address-base, count*8)
        print(f'U64 TABLE {address:x}: ' + ', '.join(f'{n:x}' for n in struct.unpack(f'<{count}Q', raw)))
if args.data:
    import struct
    for value in args.data:
        address = int(value, 16)
        raw = image.get_data(address-base, 8)
        print(f'DATA {address:x}: {raw.hex()} u16={struct.unpack_from("<H", raw)[0]} i32={struct.unpack_from("<i", raw)[0]} f32={struct.unpack_from("<f", raw)[0]}')
decoder = Cs(CS_ARCH_X86, CS_MODE_64)
for value in args.head_block:
    start=int(value,16)
    print(f'CALLER-SUPPLIED TARGET BASIC BLOCK {start:x} (verify provenance; not complete function evidence)')
    for ins in decoder.disasm(image.get_data(start-base,128),start):
        print(f'{ins.address:x}: {ins.mnemonic} {ins.op_str} ; next={ins.address+ins.size:x} bytes={ins.bytes.hex()}')
        if ins.mnemonic.startswith(('j','ret','call')):break
for value in args.leaf_cfg:
    start=int(value,16);pending=[start];visited={}
    while pending:
        at=pending.pop()
        if at in visited:continue
        if not start<=at<start+args.leaf_byte_limit:raise ValueError('Leaf CFG leaves its bounded region; inspect the tail owner separately')
        ins=next(decoder.disasm(image.get_data(at-base,15),at),None)
        if not ins:raise ValueError(f'Cannot decode verified CFG instruction {at:x}')
        visited[at]=ins
        if ins.mnemonic.startswith('ret'):continue
        if ins.mnemonic.startswith('j'):
            if not ins.op_str.startswith('0x'):raise ValueError('Leaf indirect branch requires separate jump-table mapping')
            pending.append(int(ins.op_str,16))
            if ins.mnemonic=='jmp':continue
        pending.append(at+ins.size)
    print(f'LEAF CFG VERIFIED CALL START {start:x} REACHABLE END {max(at+ins.size for at,ins in visited.items()):x}')
    for at,ins in sorted(visited.items()):print(f'{at:x}: {ins.mnemonic} {ins.op_str}')
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
