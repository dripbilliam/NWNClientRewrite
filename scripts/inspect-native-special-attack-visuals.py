"""Execute unchanged original special-attack gate/load/play instructions.

Controlled class/feat, constructor and Gob-vtable boundaries are captured. This
does not execute complete original combat callers, actual models, GPU rendering,
scene/clock ownership or destruction. The original executable is read-only.
"""
from pathlib import Path
import sys,json,struct,hashlib,itertools
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
assert len(sys.argv)==2
output=Path(sys.argv[1]).resolve()
assert output.is_relative_to(root/'godot-client/reports') and not output.exists()
original=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(original).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=original);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
actor,descriptor,gob,actor_vt,gob_vt,effect_vt=heap,heap+0x2000,heap+0x4000,heap+0x6000,heap+0x7000,heap+0x8000
entries=[(0x1407fdca0,0x1407fdd57),(0x140803c50,0x140803f1d),(0x1408074b0,0x1408075c8)]
def wq(a,n):u.mem_write(a,struct.pack('<Q',n))
def rq(a):return int.from_bytes(u.mem_read(a,8),'little')
def reg(r):return u.reg_read(r)
def text(a):
 b=bytearray()
 while len(b)<256 and u.mem_read(a+len(b),1)[0]:b.append(u.mem_read(a+len(b),1)[0])
 assert len(b)<256
 return b.decode('ascii')
def ret(value=None):
 if value is not None:u.reg_write(UC_X86_REG_RAX,value)
 sp=reg(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,rq(sp));u.reg_write(UC_X86_REG_RSP,sp+8)
def slot(address):
 for i in range(4):
  if rq(actor+0x1e0+i*8)==address:return i
 return None
def hook(_u,address,_size,_data):
 global allocated
 if address==stop:u.emu_stop();return
 if address==0x1407f0f60:
  assert reg(UC_X86_REG_RCX)==descriptor
  ret(case['classes'][reg(UC_X86_REG_RDX)&255]['type']);return
 if address==0x1407f1080:
  assert reg(UC_X86_REG_RCX)==descriptor
  ret(case['classes'][reg(UC_X86_REG_RDX)&255]['level']&255);return
 if address==0x140296910:
  assert reg(UC_X86_REG_RDX)==213
  offset=reg(UC_X86_REG_RCX)-descriptor;assert offset in (0x118,0x128)
  ret(int(213 in case['feats'][0 if offset==0x118 else 1]));return
 if address==0x1400931f0:
  assert reg(UC_X86_REG_R8)==0
  calls.append(dict(operation='create',resource=text(reg(UC_X86_REG_RCX)),name=text(reg(UC_X86_REG_RDX))))
  address=heap+0x10000+allocated*0x100;allocated+=1;wq(address,effect_vt);ret(address);return
 if address==0x1407630a0:assert reg(UC_X86_REG_RCX)==actor;ret(gob);return
 if address==0x1407630d0:assert reg(UC_X86_REG_RCX)==actor;ret(case['animation']);return
 if address==stop+16:
  assert reg(UC_X86_REG_RCX)==gob and reg(UC_X86_REG_RDX)==254
  ret(case['partFE']);return
 if address==stop+32:
  assert reg(UC_X86_REG_RCX)==actor and reg(UC_X86_REG_RDX)&255==255 and reg(UC_X86_REG_R8)==1
  ret(gob);return
 if address==stop+48:
  assert reg(UC_X86_REG_RDX)==gob
  calls.append(dict(operation='attach',slot=slot(reg(UC_X86_REG_RCX)),part=text(reg(UC_X86_REG_R8)),flags=reg(UC_X86_REG_R9)));ret(1);return
 if address==stop+64:
  # Assembly at807522/807529 preserves the real model receiver. Recovered
  # pseudocode's apparent null receiver is a decompiler artifact.
  model_slot=slot(reg(UC_X86_REG_RCX));assert model_slot is not None
  calls.append(dict(operation='play',slot=model_slot,clip=text(reg(UC_X86_REG_RDX)),speed=struct.unpack('<f',struct.pack('<I',reg(UC_X86_REG_XMM2)&0xffffffff))[0],flags=reg(UC_X86_REG_R9),time=struct.unpack('<f',bytes(u.mem_read(reg(UC_X86_REG_RSP)+0x28,4)))[0]));ret(1);return
 if address==0x140115890:calls.append(dict(operation='warning'));ret(0);return
 if not any(lo<=address<=hi for lo,hi in entries):raise RuntimeError(f'Unexpected original dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def execute(entry,value,slots=0):
 global allocated,calls
 calls=[];allocated=4
 u.mem_write(heap,bytes(0x100000));u.mem_write(stack,bytes(0x20000))
 wq(actor,actor_vt);wq(actor+0x3b0,descriptor);wq(gob,gob_vt)
 wq(actor_vt+0x140,stop+32);wq(gob_vt+0x70,stop+16);wq(effect_vt+0x98,stop+48);wq(effect_vt+0x30,stop+64)
 u.mem_write(descriptor+0x69,bytes([len(case.get('classes',[]))]))
 for i in range(4):
  if slots&(1<<i):wq(heap+0x10000+i*0x100,effect_vt);wq(actor+0x1e0+i*8,heap+0x10000+i*0x100)
 sp=stack+0x1fe08;wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,value&0xffffffff)
 u.emu_start(entry,stop+1,count=100000);assert reg(UC_X86_REG_RIP)==stop
 return dict(result=reg(UC_X86_REG_RAX)&0xffffffff,calls=calls,slots=[rq(actor+0x1e0+i*8)!=0 for i in range(4)])
gates=[]
classes=[[],[dict(type=5,level=1)],[dict(type=5,level=19)],[dict(type=5,level=20)],[dict(type=0,level=40)],[dict(type=5,level=21),dict(type=5,level=10)],[dict(type=5,level=10),dict(type=5,level=21)]]
for group,feats,mode in itertools.product(classes,[[[],[]],[[213],[]],[[],[213]],[[213],[213]]],[0,1,2,-1]):
 case=dict(classes=group,feats=feats,mode=mode);r=execute(0x1407fdca0,mode);gates.append(dict(input=case,result=r['result']))
loads=[]
for kind,slots,animation,part in itertools.product(range(4),[0,1,2,3,4,8,15],[0,199,200,201,202,203,204,205,206,263,264,265,65535],[0,1]):
 case=dict(kind=kind,slots=slots,animation=animation,partFE=part);r=execute(0x140803c50,kind,slots);loads.append(dict(input=case,calls=r['calls'],slots=r['slots']))
plays=[]
for kind,slots in itertools.product([0,1,2,3,4,255],range(16)):
 case=dict(kind=kind,slots=slots);r=execute(0x1408074b0,kind,slots);plays.append(dict(input=case,calls=r['calls']))
result=dict(success=True,target=digest,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope=__doc__,functions=[dict(address=hex(lo),end=hex(hi),sha256=hashlib.sha256(bytes(u.mem_read(lo,hi-lo+1))).hexdigest()) for lo,hi in entries],gates=gates,loads=loads,plays=plays,limitations=['Controlled class/feat, constructor and Gob vtable boundaries; complete callers/models/lifetimes not executed.','Only valid0..3 loader inputs are executed; unsupported loader kind may dereference an absent slot after logging.','Gate mode1 uses the last matching class level and a byte conversion; no class/feat semantic name is inferred from these raw cases alone.'])
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(success=True,gates=len(gates),loads=len(loads),plays=len(plays),report=str(output))))
