"""Execute original party member-state853720 and leader853980 instructions.
Member lookup, GUI attachment/scene and animation publication are captured
boundaries. No original process, graphics, game state or network is executed.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,member,instance,vtable=m.heap,m.heap+0x4000,m.heap+0x8000,m.heap+0xc000
publish,scene=m.stop+0x100,m.stop+0x200
INVALID=0x7f000000
ptrs=[m.q(0x141297b68+i*8) for i in range(4)]
def cstring(ptr):
 data=bytes(u.mem_read(ptr,64)).split(b'\0',1)[0]
 return data.decode('ascii')
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140851c60:
  calls.append(['lookup',y&0xffffffff]);m.finish(member if present else 0)
 elif a==publish:
  calls.append(['state',cstring(y),u.reg_read(UC_X86_REG_R8)&0xffffffff]);m.finish()
 elif a==0x1401fb630:calls.append(['remove']);m.finish()
 elif a==0x1401fafa0:
  assert z and cstring(z)=='root'
  calls.append(['attach','self' if y==panel+0xf0 else 'member' if y==member+0x88 else hex(y)]);m.finish()
 elif a==scene:calls.append(['scene',y]);m.finish()
 elif not (0x140853720<=a<=0x1408537e2 or 0x140853980<=a<=0x140853a4f):raise AssertionError(f'Uncaptured original party dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset():
 u.mem_write(panel,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(instance,vtable);m.wq(vtable+0x30,publish);m.wq(vtable+0x110,scene)
 m.wq(panel+0x14f0,instance);m.wq(panel+0x100,11);m.wq(member+0x98,22);m.wq(member+0x2a8,instance)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.reg_write(UC_X86_REG_RCX,panel);u.reg_write(UC_X86_REG_RDX,43)
 return rsp
status=[]
for flags,mode,current,present in itertools.product([0,1,2,3,65535],list(range(32))+[255],ptrs,[False,True]):
 calls=[];reset();m.wq(member+0x320,current);u.reg_write(UC_X86_REG_R8,flags);u.reg_write(UC_X86_REG_R9,mode)
 u.emu_start(0x140853720,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 status.append(dict(flags=flags,mode=mode,current=cstring(current),present=present,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,clip=cstring(m.q(member+0x320)),calls=calls))
leader=[]
for old,target,flag,singleton,present in itertools.product([INVALID,42,43],[42,43,44],[0,1,2],[0,1],[False,True]):
 calls=[];reset();m.wi(panel+0x15b0,old);m.wi(panel+0x15b4,42)
 u.reg_write(UC_X86_REG_RDX,target);u.reg_write(UC_X86_REG_R8,flag);u.reg_write(UC_X86_REG_R9,singleton)
 u.emu_start(0x140853980,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 leader.append(dict(old=old,target=target,leader=flag,singleton=singleton,present=present,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,selected=int.from_bytes(u.mem_read(panel+0x15b0,4),'little'),calls=calls))
out=m.root/'backups/animations/native-party-indicators-v1.json';assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,status=status,leader=leader),indent=2));print(json.dumps(dict(output=str(out),status=len(status),leader=len(leader),target=m.digest)))
