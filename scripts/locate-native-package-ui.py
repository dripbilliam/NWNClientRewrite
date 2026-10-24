"""Read-only RIP-relative package/reference candidates; owner analysis required."""
from pathlib import Path
import sys,json,hashlib,struct
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);targets={0x140de67e0:'SpellPref2DA',0x140e7bb70:'package-panel-source',0x140de66d0:'invalid-package-fallback',0x140de6718:'no-valid-package',0x140e65b08:'CG_PACKAGE'};rows=[]
for section in pe.sections:
 if not section.Characteristics&0x20000000:continue
 raw=section.get_data();base=pe.OPTIONAL_HEADER.ImageBase+section.VirtualAddress
 for rex in [b'\x48\x8d',b'\x4c\x8d']:
  offset=0
  while True:
   offset=raw.find(rex,offset)
   if offset<0:break
   if offset+7<=len(raw)and raw[offset+2]&0xc7==5:
    target=base+offset+7+struct.unpack_from('<i',raw,offset+3)[0]
    if target in targets:
     address=base+offset;rva=address-pe.OPTIONAL_HEADER.ImageBase;owner=next((e.struct.BeginAddress for e in pe.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=rva<e.struct.EndAddress),None);rows.append(dict(address=hex(address),target=hex(target),label=targets[target],owner=hex(pe.OPTIONAL_HEADER.ImageBase+owner)if owner is not None else None))
   offset+=1
out=root/'backups/animations/native-package-reference-candidates-v1.json';out.write_text(json.dumps(dict(target=digest,candidates=rows),indent=2)+'\n');print(json.dumps(rows))
