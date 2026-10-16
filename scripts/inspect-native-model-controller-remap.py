"""Complete ReadBinaryNode14007b6c0..14007b9e1 executes with actual subtype
query leaves14008c2e0/360/300. Compares its controller relocation results, not
the entire binary/resource loader. Heap, copies and scratch storage captured;
synthetic nodes have no children. Metadata/value bytes must be retained.
"""
import importlib,json,struct,itertools
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager,node,disk,owner,resource=[m.heap+n*0x1000 for n in range(1,6)]
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c4f024:m.finish()
 elif a==0x140c4f038:
  ptr=m.heap+0x10000+allocation*0x10000;allocation+=1;u.mem_write(ptr,bytes(y));m.finish(ptr)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif not(0x14007b6c0<=a<0x14007b9e1 or 0x14008c2e0<=a<0x14008c2f4 or 0x14008c360<=a<0x14008c374 or 0x14008c300<=a<0x14008c314):raise RuntimeError(f'Unexpected controller relocation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
offsets=[-2147483648,-1,0,7,8,20,36,71,72,75,76,115,116,127,128,227,228,275,276,327,328,355,356,391,392,435,436,2147483647]
def run(flags):
 global allocation
 allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(node+0x98,flags);m.wi(disk+0x54,0x200);m.wi(disk+0x58,len(offsets));m.wi(disk+0x60,0x800);m.wi(disk+0x64,3)
 for i,offset in enumerate(offsets):u.mem_write(resource+0x200+i*12,struct.pack('<iHHHBB',offset,2,4,5,17,0xa5))
 for i,value in enumerate([1.25,-2.5,3.75]):m.wf(resource+0x800+i*4,value)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,resource);m.wq(rsp+0x30,0)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,manager),(UC_X86_REG_RDX,node),(UC_X86_REG_R8,disk),(UC_X86_REG_R9,owner)]:u.reg_write(reg,value)
 u.emu_start(0x14007b6c0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 data=m.q(node+0x78);return dict(flags=flags,offsets=offsets,controllers=[list(struct.unpack('<iHHHBB',u.mem_read(data+i*12,12)))for i in range(len(offsets))],values=[m.rf(m.q(node+0x88)+i*4)for i in range(3)])
rows=[run(flags)for flags in [0,1,2,3,4,5,7,0x20,0x21,0x23,0x25,0x71,0x81,0x121,0x221,0xffffffff]]
out=m.root/'backups/animations/native-model-controller-remap-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),controllers=len(rows)*len(offsets))))
