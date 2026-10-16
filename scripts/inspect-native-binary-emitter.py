"""Complete unchanged binary node dispatcher14007abe0 and base reader
14007b6c0, selecting emitter flags5. Allocator/memcpy and As-node queries
are captured boundaries. Synthetic scalar/string/controller pools contain no
installed assets. Verifies serialized payload and relocation, not particle
simulation or controller interpolation. Native parse-field assembly supplies
the semantic controller names independently.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
disk,model=m.heap,m.heap+0x4000
def string(a):return bytes(u.mem_read(a,64)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10368,0x140c10324]:
  p=m.heap+0x10000+allocation*0x1000;allocation+=1;m.finish(p)
 elif a==0x140c4f038:
  p=m.heap+0x10000+allocation*0x1000;allocation+=1
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(p)
 elif a in [0x140c10370,0x140c4f024]:m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a in [0x14008c360,0x14008c300]:m.finish(0)
 elif a==0x14008c2e0:m.finish(x)
 elif not(0x14007abe0<=a<0x14007b6bc or 0x14007b6c0<=a<0x14007b9e1):raise RuntimeError(f'Unexpected native dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global allocation
 allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(disk+0x6c,5)
 for i,v in enumerate(case['floats']):m.wf(disk+0x70+i*4,v)
 for off,v in zip([0x7c,0x80,0x84,0x138,0x13c,0x144],case['ints']):m.wi(disk+off,v)
 u.mem_write(disk+0x140,struct.pack('<H',case['order']))
 for off,text in zip([0x88,0xa8,0xc8,0xe8,0x128],case['strings']):u.mem_write(disk+off,text.encode('ascii')+b'\0')
 controls=case['controls'];m.wi(disk+0x54,0x100);m.wi(disk+0x58,len(controls))
 for i,v in enumerate(controls):m.wi(model+0x100+i*12,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,0)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[m.heap+0x9000,disk,m.heap+0x8000,model]):u.reg_write(reg,v)
 u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(0x14007abe0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 node=u.reg_read(UC_X86_REG_RAX)
 return dict(case=case,floats=[m.rf(node+0xa0+i*4)for i in range(3)],ints=[m.si(node+off)for off in [0xac,0xb0,0xb4,0x168,0x16c,0x174]],order=int.from_bytes(u.mem_read(node+0x170,2),'little'),strings=[string(node+off)for off in [0xb8,0xd8,0xf8,0x118,0x158]],controllers=[m.si(m.q(node+0x78)+i*12)for i in range(len(controls))])
controls=list(range(72,220,4))+[228,264,276,324,328,352,356,388,392,432,436,448,452,464,465,466,468,472]
rows=[run(dict(floats=[.5,3.25,-2],ints=[x,y,spawn,two,loop,flags],order=order,strings=['Fountain','Billboard_to_Local_Z','Lighten','synthetic_texture','synthetic_chunk'],controls=controls))for x,y,spawn,two,loop,flags,order in [(1,1,0,0,0,0,0),(4,8,1,1,1,2047,3),(16,32,3,0,1,0x80000000,65535)]]
out=m.root/'backups/animations/native-binary-emitter-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
