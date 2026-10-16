"""Complete AnimateHierarchy14004fe90..14004ffe8 on synthetic physical
Part/MdlNode trees. Control callbacks, light subtype queries and the owner's
AnimateStaticLight event are captured. Does not prove lower sampling/rendering.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
vt,owner,ownerVt,light=[m.heap+n*0x1000 for n in range(1,5)]
def name(ptr):return names[ptr]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x20:
  calls.append(['control',name(x),name(y),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)]);m.finish()
 elif a==m.stop+0x30:calls.append(['light',name(x)]);m.finish(light if c['light']else 0)
 elif a==m.stop+0x40:calls.append(['AnimateStaticLight',name(u.reg_read(UC_X86_REG_R8))]);m.finish()
 elif not(0x14004fe90<=a<0x14004ffe8):raise RuntimeError(f'Unexpected hierarchy dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names
 c=case;calls=[];names={light:'light'};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(vt+0x48,m.stop+0x30);m.wq(owner,ownerVt);m.wq(ownerVt+0x298,m.stop+0x40);m.wi(light+0x8c,c['lightFlag']);m.wi(0x1412e0098,c['depth'])
 parts=[m.heap+0x10000+i*0x400 for i in range(5)];nodes=[m.heap+0x20000+i*0x400 for i in range(5)]
 for kind,pointers in [('part',parts),('node',nodes)]:
  for i,ptr in enumerate(pointers):names[ptr]=f'{kind}{i}'
 for i,ptr in enumerate(parts):
  m.wq(ptr,vt);m.wq(ptr+0x50,owner);m.wi(ptr+0x30,[0,*c['physicalIds'],3][i]);m.wi(ptr+0x60,c['dirty']if i==0 else c['childDirty'])
 for i,ptr in enumerate(nodes):m.wq(ptr+0x18,m.stop+0x20);m.wi(ptr+0x34,[0,*c['animationIds'],3][i])
 for index,children in [(0,[1,2,3]),(1,[4])]:
  arr=parts[index]+0x200;m.wq(parts[index]+0x38,arr);m.wi(parts[index]+0x40,len(children))
  for j,child in enumerate(children):m.wq(arr+j*8,parts[child])
 for index,children in [(0,[1,2,3]),(c['grandchildAt'],[4])]:
  arr=nodes[index]+0x200;m.wq(nodes[index]+0x68,arr);m.wi(nodes[index]+0x70,len(children))
  for j,child in enumerate(children):m.wq(arr+j*8,nodes[child])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wf(rsp+0x28,.3);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,parts[0]);u.reg_write(UC_X86_REG_RDX,nodes[0]);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',-.25),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',.75),'little'))
 u.emu_start(0x14004fe90,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,depth=m.si(0x1412e0098))
rows=[run(dict(depth=depth,dirty=dirty,childDirty=childDirty,light=lightPresent,lightFlag=lightFlag,physicalIds=physicalIds,animationIds=animationIds,grandchildAt=grandchildAt))for depth,dirty,childDirty,lightPresent,lightFlag,physicalIds,animationIds,grandchildAt in itertools.product([0,998,999,1000],[0,1],[0,1],[0,1],[0,1],[[1,2,1],[5,1,2]],[[2,1,1],[1,2,5]],[1,2])]
out=m.root/'backups/animations/native-model-animation-hierarchy-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
