"""Read-only original AddOpenDoorAction/AddCloseDoorAction instruction capture.
Allocator and linked-list insertion are captured provider boundaries; record
initialization, commandability gate, group wrap and parameter writes execute
the unchanged installed instructions. No game code/assets are emitted.
"""
from pathlib import Path
import sys,hashlib,struct,json,ctypes
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
raw=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(raw).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
for a,n in [(heap,0x10000),(stack,0x20000),(stop,0x1000)]:u.mem_map(a,n)
actor,record,linked=heap,heap+0x1000,heap+0x2000
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def finish(value=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,value)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    if a==0x140c10324:assert u.reg_read(UC_X86_REG_RCX)==0xa0;finish(record)
    elif a==0x140169030:
        assert u.reg_read(UC_X86_REG_RCX)==linked and u.reg_read(UC_X86_REG_RDX)==record
        captured.append(bytes(u.mem_read(record,0xa0)));finish()
    elif not (0x14048dc70<=a<0x14048ddc4 or 0x14048d750<=a<0x14048d8a4):raise RuntimeError(f'Uncaptured dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);observations=[]
for opening,address in [(True,0x14048dc70),(False,0x14048d750)]:
  for commandable in [0,1,2,-1]:
    for group in [0,65534]:
      captured=[];u.mem_write(heap,bytes(0x10000));wq(actor+0x100,linked);wi(actor+0xec,commandable);u.mem_write(actor+0x18,struct.pack('<H',group))
      rsp=stack+0x1fe08;wq(rsp,stop)
      for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,actor),(UC_X86_REG_RDX,0xf1234567),(UC_X86_REG_R8,0xfffffffe)]:u.reg_write(reg,value)
      u.emu_start(address,stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==stop
      row=dict(open=opening,commandable=commandable,initialGroup=group,result=u.reg_read(UC_X86_REG_RAX),nextGroup=int.from_bytes(u.mem_read(actor+0x18,2),'little'))
      if captured:
        b=captured[0];row.update(action=struct.unpack_from('<I',b)[0],group=struct.unpack_from('<H',b,0x98)[0],count=struct.unpack_from('<H',b,0x9a)[0],types=list(struct.unpack_from('<II',b,4)),target=struct.unpack_from('<I',b,0x38)[0],run=struct.unpack_from('<i',b,0x40)[0])
        assert row['action']==(20 if opening else 21) and row['count']==2 and row['types']==[3,1] and row['target']==0xf1234567 and row['run']==-2
      assert bool(captured)==(commandable!=0);observations.append(row)
# Independent Windows CRT C-locale checks. This verifies the parser provider,
# not the game's process-global locale or NaN payload/FP exception state.
c=ctypes.CDLL('ucrtbase.dll');c._create_locale.argtypes=[ctypes.c_int,ctypes.c_char_p];c._create_locale.restype=ctypes.c_void_p
locale=c._create_locale(0,b'C');assert locale
c._atof_l.argtypes=[ctypes.c_char_p,ctypes.c_void_p];c._atof_l.restype=ctypes.c_double
texts=['','bad','12.5junk','  -1.25e2x','1e+','0x1.8p2','0x1','0x1p','0x.8p-2','inf','infinity','nan','-nan(ind)','1.#INF','1e999','1e-999','-0','\xa01.5','0.1','16777217','0x1.000001p0','0x1p-1075']
floats=[]
for text in texts:
    value=c._atof_l(text.encode('latin1'),locale)
    try:bits=struct.pack('<f',value).hex()
    except OverflowError:bits=struct.pack('<f',float('-inf') if value<0 else float('inf')).hex()
    floats.append(dict(text=text,double=str(value),float32LE=bits))
c._free_locale.argtypes=[ctypes.c_void_p];c._free_locale(locale)
out=root/'backups/animations/native-door-queue-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,queue=observations,cLocaleFloatProvider=floats),indent=2)+'\n')
print(json.dumps(dict(queueCases=len(observations),floatCases=len(floats),output=str(out))))
