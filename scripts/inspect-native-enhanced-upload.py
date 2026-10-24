"""Static native enhanced-light upload investigation, not code execution.

Read the pinned PE's export/unwind tables and disassemble selected known light
owners (including bone-palette transport). Export JMP thunks are followed once. Unwind ranges are physical code
ranges, not proof of a complete logical CFG; leaf functions without unwind
metadata have explicitly bounded instruction windows. No tests or game launch.
"""
from pathlib import Path
import bisect,hashlib,json,struct,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86 import X86_OP_IMM,X86_OP_MEM,X86_REG_RIP

data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
if digest!='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a':raise RuntimeError('Native build changed')
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
exports={base+e.address:e.name.decode('ascii','replace') for e in pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name}
entries=sorted((e.struct for e in pe.DIRECTORY_ENTRY_EXCEPTION),key=lambda e:e.BeginAddress)
starts=[e.BeginAddress for e in entries]
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True

def read(address,size):return pe.get_data(address-base,size)
def instruction(ins):
 result=dict(address=hex(ins.address),instruction=ins.mnemonic+' '+ins.op_str)
 refs=[]
 for operand in ins.operands:
  if operand.type==X86_OP_IMM and ins.mnemonic in ('call','jmp'):
   refs.append(dict(kind='direct-control',address=hex(operand.imm),export=exports.get(operand.imm)))
  elif operand.type==X86_OP_MEM and operand.mem.base==X86_REG_RIP:
   target=ins.address+ins.size+operand.mem.disp
   ref=dict(kind='rip-relative-memory',address=hex(target))
   try:
    raw=read(target,8)
    if operand.size==4:ref['float32Interpretation']=struct.unpack('<f',raw[:4])[0]
    elif operand.size==8:ref['float64Interpretation']=struct.unpack('<d',raw)[0]
   except Exception:pass
   refs.append(ref)
 if refs:result['references']=refs
 return result

owners=[]
targets={0x1400bf3e0:'color_pow (called by GetColorSpaceFromSRGB at1400bebb6)',
 0x1400bf190:'RenderInterface::SetLightProperties (SetLightGL property4 at140080e97)',
 0x1400beb90:'RenderInterface::GetColorSpaceFromSRGB (SetLightGL call140080e4e)',
 0x1400beb50:'Four-component conversion target (SetUniforms calls1400b9d1e/55/8c/c3)',
 0x1400bf000:'RenderInterface::SetBoneMatrix (ExecuteSkinGPU call1400dee43)',
 0x14022e8f0:'Matrix helper (SetBoneMatrix call1400b69c0; transpose semantics inspected in assembly)',
 0x1400b3c00:'GLRender::GetGlobalShaderParamf',
 0x1400b3c10:'GLRender::GetGlobalShaderParami'}
for address,label in targets.items():
 first=next(cs.disasm(read(address,16),address),None);target=address;thunk=None
 if first and first.mnemonic=='jmp' and first.operands[0].type==X86_OP_IMM:
  target=first.operands[0].imm;thunk=instruction(first)
 index=bisect.bisect_right(starts,target-base)-1
 if index>=0 and target-base<entries[index].EndAddress:
  entry=entries[index];lo=base+entry.BeginAddress;hi=base+entry.EndAddress
  scope='PE unwind physical range; logical non-contiguous/indirect CFG completeness unestablished'
 else:
  lo=target;hi=target+256;scope='Leaf window, capped at256bytes and firstret; not a recovered function body'
 instructions=[]
 for ins in cs.disasm(read(lo,hi-lo),lo):
  instructions.append(instruction(ins))
  if scope.startswith('Leaf') and ins.mnemonic=='ret':break
 owners.append(dict(requestedAddress=hex(address),label=label,export=exports.get(address),thunk=thunk,
  resolvedAddress=hex(target),physicalRange=dict(start=hex(lo),endExclusive=hex(hi)),coverage=scope,instructions=instructions))
output=root/'runtime-logs/native-render-parity/enhanced-upload-assembly.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(dict(build='89.8193.37-17',sha256=digest,scope=__doc__,owners=owners),indent=2,allow_nan=False)+'\n')
print(json.dumps(dict(output=str(output),owners=[dict(label=x['label'],address=x['resolvedAddress'],instructions=len(x['instructions']))for x in owners])))
