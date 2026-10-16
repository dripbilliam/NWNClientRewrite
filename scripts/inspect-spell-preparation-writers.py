"""Read-only raw instruction-pattern candidates in the already mapped client
message-writer region. Containing unwind entries are candidates, not semantic
proof; inspect complete disassembly/callers before assigning any meaning.
"""
import hashlib,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backups/research-python'))
import pefile
p=Path(__file__).resolve().parents[2]/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe';data=p.read_bytes();assert hashlib.sha256(data).hexdigest()=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;start,end=0x7b0000,0x7c3000
all_text='--all-text' in sys.argv
if all_text:
 section=next(s for s in pe.sections if s.Name.rstrip(b'\0')==b'.text');start,end=section.VirtualAddress,section.VirtualAddress+section.Misc_VirtualSize
raw=pe.get_data(start,end-start)
patterns=[('R8B16',bytes.fromhex('41b010')),('R8B17',bytes.fromhex('41b011'))] if all_text else [('R8B13',bytes.fromhex('41b00d')),('R8B16',bytes.fromhex('41b010')),('R8D16',bytes.fromhex('41b810000000')),('R8B17',bytes.fromhex('41b011')),('DL6',bytes.fromhex('b206'))]
for label,needle in patterns:
 offset=0
 while (offset:=raw.find(needle,offset))>=0:
  rva=start+offset;entry=next((e.struct for e in pe.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=rva<e.struct.EndAddress),None)
  print(f'RAW {label} CANDIDATE {base+rva:x} UNWIND {base+entry.BeginAddress:x}:{base+entry.EndAddress:x}' if entry else f'NO UNWIND {base+rva:x}');offset+=1
