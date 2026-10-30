"""Run unchanged original special initialization and eye-effect owners offline.

Allocation/string, rule table, model construction and Gob virtual boundaries are
controlled. This is not a running game, original shader or whole caller oracle.
"""
from pathlib import Path
import hashlib,itertools,json,struct,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
assert len(sys.argv)==2
output=Path(sys.argv[1]).resolve()
assert output.is_relative_to(root/'godot-client/reports') and not output.exists()
binary=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(binary).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=binary);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64)
u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x200000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
actor,descriptor,appearance,gob,effect,actorvt,gobvt,effectvt,rules,array,table=[heap+i*0x1000 for i in range(11)]
entries=[(0x140810680,0x140810790),(0x1408033c0,0x140803c32)]
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def rq(a):return int.from_bytes(u.mem_read(a,8),'little')
def reg(r):return u.reg_read(r)
def txt(a):
 if not a:return ''
 b=bytearray()
 while len(b)<128 and u.mem_read(a+len(b),1)[0]:b.append(u.mem_read(a+len(b),1)[0])
 assert len(b)<128
 return b.decode('ascii')
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def ret(v=None):
 if v is not None:u.reg_write(UC_X86_REG_RAX,v)
 sp=reg(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,rq(sp));u.reg_write(UC_X86_REG_RSP,sp+8)
def alloc(size):
 global allocated
 a=heap+0x10000+allocated;allocated+=(size+15)&~15
 assert allocated<0x1e0000
 return a
def string_set(out,value):
 b=value.encode()+b'\0';a=alloc(len(b));u.mem_write(a,b);wq(out,a);u.mem_write(out+8,struct.pack('<II',len(b)-1,len(b)));return out
def hook(_u,address,_size,_data):
 if address==stop:u.emu_stop();return
 if address==0x1407fdca0:
  assert reg(UC_X86_REG_RCX)==actor
  mode=reg(UC_X86_REG_RDX);calls.append(dict(operation='gate',mode=mode));ret(case['gates'][mode]);return
 if address==0x1407630a0:
  assert reg(UC_X86_REG_RCX)==actor
  ret(gob if case.get('present',True) else 0);return
 if address in (0x140803c50,0x1408033c0) and owner=='initialize':
  assert reg(UC_X86_REG_RCX)==actor
  calls.append(dict(operation='load',kind=reg(UC_X86_REG_RDX)&255) if address==0x140803c50 else dict(operation='eyes'));ret();return
 if address==0x140c10370:ret();return
 if address==0x140c10368:ret(alloc(reg(UC_X86_REG_RCX)));return
 if address==0x14003d8c0:
  string_set(reg(UC_X86_REG_RCX),txt(reg(UC_X86_REG_RDX)));ret();return
 if address==0x14016afb0:
  fmt=txt(reg(UC_X86_REG_RDX));assert fmt in ('%s01','%s02')
  string_set(reg(UC_X86_REG_RCX),fmt%txt(reg(UC_X86_REG_R8)));ret();return
 if address==0x1400931f0:
  assert reg(UC_X86_REG_R8)==0
  calls.append(dict(operation='create',resource=txt(reg(UC_X86_REG_RCX)),name=txt(reg(UC_X86_REG_RDX))))
  ret(0 if case.get('failed',False) else effect);return
 if address==0x1401a6c70:
  assert reg(UC_X86_REG_RCX)==table
  column=txt(rq(reg(UC_X86_REG_R8)));row=reg(UC_X86_REG_RDX)
  calls.append(dict(operation='table',row=row,column=column))
  u.mem_write(reg(UC_X86_REG_R9),struct.pack('<f',case['scale']));ret(int(case['scaleFound']));return
 if address==stop+16:
  assert reg(UC_X86_REG_RCX)==effect and reg(UC_X86_REG_RDX)==1
  calls.append(dict(operation='destroy'));ret();return
 if address==stop+32:
  assert reg(UC_X86_REG_RCX)==gob and reg(UC_X86_REG_RDX)&255==255
  ret(gob);return
 if address==stop+48:
  assert reg(UC_X86_REG_RCX)==effect and reg(UC_X86_REG_RDX)==gob
  calls.append(dict(operation='attach',part=txt(reg(UC_X86_REG_R8)),flags=reg(UC_X86_REG_R9)));ret();return
 if address==stop+64:
  assert reg(UC_X86_REG_RCX)==effect
  calls.append(dict(operation='scale',value=struct.unpack('<f',struct.pack('<I',reg(UC_X86_REG_XMM1)&0xffffffff))[0],flags=reg(UC_X86_REG_R8)));ret();return
 if address==stop+80:
  model=reg(UC_X86_REG_RCX)
  slot=next((i for i in range(2) if model==heap+0xc000+i*0x100),None)
  assert model==effect or slot is not None
  value=dict(operation='play',clip=txt(reg(UC_X86_REG_RDX)),speed=struct.unpack('<f',struct.pack('<I',reg(UC_X86_REG_XMM2)&0xffffffff))[0],flags=reg(UC_X86_REG_R9),time=struct.unpack('<f',u.mem_read(reg(UC_X86_REG_RSP)+0x28,4))[0])
  if slot is not None:value['slot']=slot
  calls.append(value);ret();return
 if not any(lo<=address<=hi for lo,hi in entries):raise RuntimeError(f'Unexpected dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def execute():
 global allocated,calls
 allocated=0;calls=[]
 u.mem_write(heap,bytes(0x200000));u.mem_write(stack,bytes(0x20000))
 wq(actor,actorvt);wq(actor+0x300,appearance);wq(actor+0x3b0,descriptor)
 wq(gob,gobvt);wq(effect,effectvt);wq(gobvt+0x10,stop+32)
 wq(effectvt,stop+16);wq(effectvt+0x98,stop+48);wq(effectvt+0x1b0,stop+64);wq(effectvt+0x30,stop+80)
 for i in range(2):
  if case.get('slots',0)&(1<<i):wq(actor+0x1e0+i*8,heap+0xc000+i*0x100);wq(heap+0xc000+i*0x100,effectvt)
 u.mem_write(gob+0xdd,bytes([case.get('style',1)&255]))
 if owner=='eyes':
  u.mem_write(descriptor+0xc6,struct.pack('<H',case['alignment']&65535))
  u.mem_write(appearance+0xcc,struct.pack('<H',case['appearance']&65535))
  u.mem_write(appearance+0xd0,bytes([case['gender']&255,case['phenotype']&255]))
  u.mem_write(actor+0x208,struct.pack('<III',*case['flags']))
  if case['existing']:wq(actor+0x200,effect)
  # Original g_pRules +0x130 -> appearance table array +0x100.
  wq(0x1412df8f8,rules);wq(rules+0x130,array);wq(array+0x100,table)
 sp=stack+0x1fe08;wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,actor)
 u.emu_start(entries[0 if owner=='initialize' else 1][0],stop+1,count=100000)
 assert reg(UC_X86_REG_RIP)==stop
 return dict(calls=calls,flags=list(struct.unpack('<III',u.mem_read(actor+0x208,12))),model=rq(actor+0x200)!=0)
initializers=[];owner='initialize'
for gates,present,style,slots in itertools.product(itertools.product([0,1],[0,1]),[False,True],[0,1,2,3,11,255],range(4)):
 case=dict(gates=list(gates),present=present,style=style,slots=slots)
 initializers.append(dict(input=case,**execute()))
eyes=[];owner='eyes'
for alignment,appearance_id,gender,phenotype in itertools.product([-32768,-1,0,30,31,69,70,100,32767],range(8),[0,1,2],[0,2]):
 case=dict(alignment=alignment,appearance=appearance_id,gender=gender,phenotype=phenotype,flags=[0,0,0],existing=True,failed=False,scale=1.25,scaleFound=True)
 eyes.append(dict(input=case,**execute()))
for alignment,flags,existing,failed,found,scale in itertools.product([0,50,100],[[0,0,0],[1,0,0],[0,1,0],[0,0,1],[2,2,2]],[False,True],[False,True],[False,True],[0.0,0.75]):
 case=dict(alignment=alignment,appearance=4,gender=1,phenotype=2,flags=flags,existing=existing,failed=failed,scale=scale,scaleFound=found)
 eyes.append(dict(input=case,**execute()))
result=dict(success=True,target=digest,scope=__doc__,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),functions=[dict(address=hex(lo),end=hex(hi),sha256=hashlib.sha256(bytes(u.mem_read(lo,hi-lo+1))).hexdigest()) for lo,hi in entries],initializers=initializers,eyes=eyes,limitations=['Controlled model construction/string/rule-table/virtual boundaries; complete renderer/callers/lifetime not executed.','Gate outputs controlled here; independent original gate corpus verifies raw class/feat projection separately.','Original six-second AI trigger and appearance/weapon-class caller evidence are separate static receipts.'])
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(success=True,initializers=len(initializers),eyes=len(eyes),report=str(output))))
