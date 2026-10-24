"""Read-only exception-boundary/displacement inventory for ambient owner methods.
Operand displacement matches are candidates, not proof of field semantics.
"""
from pathlib import Path
import sys,hashlib,json
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile,capstone
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True;rows=[]
for entry in pe.DIRECTORY_ENTRY_EXCEPTION:
 lo=base+entry.struct.BeginAddress;hi=base+entry.struct.EndAddress
 if not 0x140875ad0<=lo<0x140878900:continue
 code=pe.get_data(lo-base,hi-lo);hits=[]
 for ins in cs.disasm(code,lo):
  if any(o.type==capstone.x86.X86_OP_MEM and o.mem.disp in [0x1a0,0x1a4,0x1a8,0x1ac,0x1b8,0x1c4]for o in ins.operands):hits.append(dict(address=hex(ins.address),mnemonic=ins.mnemonic,operands=ins.op_str))
 rows.append(dict(start=hex(lo),end=hex(hi),hits=hits))
out=root/'backups/animations/native-ambient-state-candidates.json';out.write_text(json.dumps(dict(target=digest,limits=__doc__,methods=rows),indent=2)+'\n');print(json.dumps(rows,indent=2))
