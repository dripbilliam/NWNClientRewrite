"""Unchanged complete chkParticleLife140065f10, allocator/memcpy and
chunk virtual+90 captured lower boundaries. Synthetic particles/list profiles
only; no installed asset copies. Verifies age/death/recycle ordering, not
birth, movement, GPU draw or whole emitter lifecycle.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,active,free=[m.heap+n*0x1000 for n in range(4)]
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c4f038:
  calls.append(['reserve',y//8]);p=m.heap+0x90000+allocation*0x1000;allocation+=1
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(p)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==m.stop+0x10:
  calls.append(['detach',names[x],y&0xffffffff])
  if case.get('detachLife') is not None:m.wf(emitter+0xac,case['detachLife'])
  m.finish()
 elif not 0x140065f10<=a<0x1400660bf:raise RuntimeError(f'Unexpected native dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,calls,allocation,names
 case=c;calls=[];allocation=0;names={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter+8,node);m.wf(emitter+0xac,c['life']);u.mem_write(node+0x158,b'x'if c['chunk']else b'\0')
 m.wq(emitter+0x188,active);m.wi(emitter+0x190,len(c['ages']));m.wq(emitter+0x130,free);m.wi(emitter+0x138,c['freeCount']);m.wi(emitter+0x13c,c['capacity'])
 for i in range(c['freeCount']):m.wq(free+i*8,m.heap+0x70000+i*0x100)
 particles=[]
 for i,age in enumerate(c['ages']):
  p=m.heap+0x10000+i*0x100;particles.append(p);names[p]=i;m.wq(active+i*8,p);m.wf(p+0x74,age);m.wi(p+0x48,100+i)
  chunk=m.heap+0x50000+i*0x100;names[chunk]=i;m.wq(p+0x78,chunk if i%2==0 else 0);m.wq(chunk,m.heap+0x80000);m.wq(m.heap+0x80000+0x90,m.stop+0x10)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'))
 u.emu_start(0x140065f10,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,active=[names[m.q(active+i*8)]for i in range(m.si(emitter+0x190))],retired=[names.get(m.q(m.q(emitter+0x130)+i*8),-1)for i in range(c['freeCount'],m.si(emitter+0x138))],capacity=m.si(emitter+0x13c),ages=[m.rf(p+0x74)for p in particles],fields48=[m.si(p+0x48)for p in particles])
rows=[run(dict(life=life,delta=delta,ages=ages,chunk=chunk,freeCount=count,capacity=capacity))for life,delta,ages,chunk,(count,capacity)in itertools.product([-1,0,.5,1],[.25,-.75,0],[[],[0],[0,.5,1,1.5],[1.5,1,.5,0]],[0,1],[(0,0),(15,16),(16,16)])]
rows.append(run(dict(life=0,delta=.25,ages=[0]*20,chunk=1,freeCount=0,capacity=0)))
rows.append(run(dict(life=1,delta=.25,ages=[1,1,1],chunk=1,freeCount=0,capacity=0,detachLife=-1)))
out=m.root/'backups/animations/native-particle-lifetime-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
