"""Read-only complete mesh InternalControl052520 -> generic051c50 composed
with original vector/scalar samplers and actual AsPartTriMesh08c4e0 leaf.
Synthetic runtime Part/controller storage; no GPU, resource loader, constructor,
scene scheduler or color-space conversion is claimed by this oracle.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
node,part,controllers,values,vtable=[m.heap+n*0x1000 for n in range(1,6)]
ranges=[(0x140052520,0x14005256e),(0x140051c50,0x140051e59),(0x1400512c0,0x140051466),(0x140051750,0x140051b0e),(0x14008c4e0,0x14008c4e4)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected mesh control dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(time,weight,scale):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(part,vtable);m.wq(vtable+0x58,0x14008c4e0);m.wq(node+0x78,controllers);m.wi(node+0x80,2);m.wq(node+0x88,values)
 pool=[0,1,.2,.4,.8,.8,.4,.2,1,.25];u.mem_write(values,struct.pack('<10f',*pool))
 for i,(offset,columns,index)in enumerate([(128,3,2),(168,1,8)]):u.mem_write(controllers+i*12,struct.pack('<iHHHBB',offset,2,0,index,columns,0))
 for offset,value in [(124,77.5),(140,88.5),(168,1)]:m.wf(part+offset,value)
 m.wq(0x1412e00a0,0);m.wf(0x14128e218,scale)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wf(rsp+0x28,weight)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,node),(UC_X86_REG_RDX,part)]:u.reg_write(reg,value)
 for reg,value in [(UC_X86_REG_XMM2,-.25),(UC_X86_REG_XMM3,time)]:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 u.emu_start(0x140052520,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 assert m.rf(part+124)==77.5 and m.rf(part+140)==88.5
 return dict(time=time,weight=weight,scale=scale,color=[m.rf(part+128+i*4)for i in range(3)],alpha=m.rf(part+168))
rows=[run(t,w,s)for t,w,s in itertools.product([-1,0,.25,1,2],[-.5,0,.25,1,1.5],[.3,1,7])]
out=m.root/'backups/animations/native-mesh-selfillum-observations.json'
out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2))
print(json.dumps(dict(output=str(out),cases=len(rows))))
