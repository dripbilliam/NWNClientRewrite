"""Read-only RIP-relative references to the pinned original tooltip settings.

These are candidate instruction locations. REA must confirm decoded boundaries
and containing procedures; matching bytes alone do not prove executable flow.
"""
import hashlib,json,re,struct,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
binary=root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
raw=binary.read_bytes();digest=hashlib.sha256(raw).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw,fast_load=True);base=pe.OPTIONAL_HEADER.ImageBase
targets={base+0xe2a1d0:'ui.tooltip-delay',base+0xe2a1e8:'TooltipDelay uSec'}
for address,value in targets.items():
    offset=pe.get_offset_from_rva(address-base)
    assert raw[offset:offset+len(value)+1]==value.encode()+b'\0'
references=[]
for section in pe.sections:
    if not section.Characteristics&0x20000000:continue
    code=section.get_data();origin=base+section.VirtualAddress
    for match in re.finditer(rb'[\x48\x4c]\x8d[\x05\x0d\x15\x1d\x25\x2d\x35\x3d](.{4})',code,re.S):
        address=origin+match.start();target=address+7+struct.unpack('<i',match.group(1))[0]
        if target in targets:references.append(dict(candidate=hex(address),target=hex(target),string=targets[target],bytes=match.group().hex()))
print(json.dumps(dict(schema=1,sha256=digest,references=references,scope='Static candidate references only; confirm instruction boundaries and procedures through REA.'),indent=2))
