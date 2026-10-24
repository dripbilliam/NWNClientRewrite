"""Read-only bounded original floaty option initialization around its verified
Enable FloatyTextFeedback string reference. No live process access or writes.
"""
import sys,json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile,capstone
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);start=0x1406b7d2b;offset=pe.get_offset_from_rva(start-pe.OPTIONAL_HEADER.ImageBase);decoder=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);decoder.detail=True;rows=[]
for i in decoder.disasm(data[offset:offset+0x230],start):
 row=dict(address=hex(i.address),instruction=i.mnemonic+' '+i.op_str)
 for op in i.operands:
  if op.type==capstone.x86_const.X86_OP_MEM and op.mem.base==capstone.x86_const.X86_REG_RIP:
   target=i.address+i.size+op.mem.disp
   try:
    at=pe.get_offset_from_rva(target-pe.OPTIONAL_HEADER.ImageBase);text=data[at:at+128].split(b'\0')[0]
    if text and all(32<=b<127 for b in text):row['string']=text.decode('ascii')
   except Exception:pass
 rows.append(row)
out=root/'backups/animations/native-floaty-options-instructions.json';out.write_text(json.dumps(dict(target=digest,limits=__doc__,instructions=rows),indent=2)+'\n');print(json.dumps(rows,indent=2))
