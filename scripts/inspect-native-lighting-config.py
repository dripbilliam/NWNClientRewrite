"""Read-only bounded assembly investigation of graphics config registration.

Full decompilation of1406ae3b0 exceeds Ghidra's response buffer. Decode its
observed body and retain only context around established setting-label xrefs.
No runtime execution, tests, native binary edits or original DB changes.
"""
from pathlib import Path
import hashlib,json,struct,sys
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86 import X86_OP_MEM,X86_REG_RIP
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True
def bytes_at(address,n):return pe.get_data(address-base,n)
def string_at(address):
 try:
  value=bytes_at(address,180).split(b'\0',1)[0]
  if not value or not all(32<=c<127 for c in value):return None
  return value.decode('ascii')
 except Exception:return None
def instruction(ins):
 result=dict(address=hex(ins.address),instruction=ins.mnemonic+' '+ins.op_str)
 refs=[]
 for op in ins.operands:
  if op.type==X86_OP_MEM and op.mem.base==X86_REG_RIP:
   a=ins.address+ins.size+op.mem.disp;refs.append(dict(address=hex(a),string=string_at(a)))
 if refs:result['ripReferences']=refs
 return result
lo,hi=0x1406ae3b0,0x1406bb186
instructions=list(cs.disasm(bytes_at(lo,hi-lo),lo))
sites={
 0x1406b18dc:'graphics.lighting.enhanced',
 0x1406b19db:'graphics.experimental.enable-fragment-lighting',
 0x1406b1aa9:'graphics.general.shader-quality',
 0x1406b1cb3:'graphics.lighting.cutoff-range-multiplier',
 0x1406b1e78:'graphics.lighting.max-intensity',
 0x1406b1f5e:'graphics.lighting.intensity-at-range',
}
contexts=[]
for site,label in sites.items():
 index=next(i for i,x in enumerate(instructions)if x.address==site)
 contexts.append(dict(label=label,labelReference=hex(site),procedure=hex(lo),instructions=[instruction(x)for x in instructions[max(0,index-160):index+90]]))
output=root/'runtime-logs/native-render-parity/lighting-config-registration-assembly.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(dict(build='89.8193.37-17',sha256=digest,scope=__doc__,contexts=contexts),indent=2)+'\n')
print(json.dumps(dict(output=str(output),contexts=len(contexts),instructions=sum(len(x['instructions'])for x in contexts))))
