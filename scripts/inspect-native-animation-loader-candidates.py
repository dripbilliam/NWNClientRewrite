"""Read-only RIP-relative source-path references for animation loader research.
Instruction byte matches are candidates, not verified functions or semantics.
"""
import sys,importlib,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-message-text').m
targets=[0x140d81eb0,0x140d88f90,0x140d8a370];rows=[]
for section in m.pe.sections:
 if not section.Characteristics&0x20000000:continue
 code=section.get_data();base=m.base+section.VirtualAddress
 for prefix in [b'\x48\x8d',b'\x4c\x8d']:
  start=0
  while (i:=code.find(prefix,start))>=0:
   start=i+1
   if i+7<=len(code)and code[i+2]&0xc7==5:
    target=base+i+7+struct.unpack_from('<i',code,i+3)[0]
    if target in targets:rows.append(dict(address=hex(base+i),target=hex(target)))
out=m.root/'backups/animations/native-animation-loader-candidates.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=rows,output=str(out))))
