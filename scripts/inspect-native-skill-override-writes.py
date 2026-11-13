"""Read-only PE instruction candidates for the as-yet-unidentified stats110 owner.

Candidate address decoding is not a containing-function or data-owner proof.
Only operand writes with a literal110 displacement are listed for further REA.
"""
from pathlib import Path
import argparse,hashlib,json,struct,sys
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile,capstone
from capstone.x86 import X86_OP_MEM
p=argparse.ArgumentParser();p.add_argument('--report',required=True);a=p.parse_args();out=Path(a.report)
if out.exists():raise SystemExit('Refusing to overwrite candidate dossier')
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True
rows={}
for sec in pe.sections:
 if not sec.Characteristics&0x20000000:continue
 raw=sec.get_data();needle=b'\x10\x01\x00\x00';i=raw.find(needle)
 while i>=0:
  for start in range(max(0,i-12),i):
   ins=next(cs.disasm(raw[start:i+8],base+sec.VirtualAddress+start,count=1),None)
   if not ins or ins.disp_offset!=i-start or ins.disp_size!=4 or not ins.operands:continue
   op=ins.operands[0]
   if op.type!=X86_OP_MEM or op.mem.disp!=0x110 or not op.access&capstone.CS_AC_WRITE:continue
   # A possible instruction may start inside another. REA must confirm it.
   rows[ins.address]=dict(address=hex(ins.address),instruction=ins.mnemonic+' '+ins.op_str,baseRegister=ins.reg_name(op.mem.base),size=op.size)
  i=raw.find(needle,i+1)
out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(dict(binarySha256=digest,scope=__doc__,candidates=list(rows.values())),indent=2)+'\n')
print(json.dumps(dict(candidateCount=len(rows),report=str(out))))
