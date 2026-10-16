"""Complete original moveParticleStandard140068010 with actual quaternion
product/vector rotation/RotationArc helpers. Client scene wind/intersection,
CHitInfo clear/ignore-list ownership and IEEE sqrt are captured lower providers.
Synthetic particle profiles verify all flag/response branches, not real scene
geometry collision, actual wind manager, outer frame or rendered acceptance.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,gob,hit,scene,vt,active=[m.heap+n*0x1000 for n in range(7)]
ranges=[(0x140068010,0x1400687f9),(0x14022b0c0,0x14022b0e6),(0x14022ab00,0x14022ac34),(0x14022ae90,0x14022b0bb),(0x14022b180,0x14022b1b0),(0x14022e1c0,0x14022e2ed),(0x14022db30,0x14022dbf2)]
def vector(a,values):
 for i,v in enumerate(values):m.wf(a+i*4,v)
def read(a,n=3):return[m.rf(a+i*4)for i in range(n)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1400c5a90:calls.append(['clearHit']);vector(hit+0x5c,[0,0,0]);m.finish()
 elif a==0x1400c9b90:
  calls.append(['wind',read(z),m.xmm(UC_X86_REG_XMM3)]);vector(y,[.01,-.02,.03]);m.finish(y)
 elif a==0x140c4f024:calls.append(['resetIgnored']);m.finish()
 elif a==0x140060f30:calls.append(['ignore',names[y]]);m.finish()
 elif a==m.stop+0x10:
  calls.append(['collide',read(y),read(z)]);vector(hit+0x5c,c['normal'])
  if c['collision']:vector(w,[.5,.75,1])
  m.finish(c['collision'])
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected movement dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names
 c=case;calls=[];names={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter+8,node);m.wi(node+0x174,c['flags']);u.mem_write(node+0x158,b'x'if c['chunk']else b'\0');m.wq(emitter+0x1f0,hit);m.wq(hit+0x10,m.heap+0x8000);m.wi(hit+0x18,1);m.wi(hit+0x1c,16)
 m.wq(0x14140ac50,scene);m.wq(scene,vt);m.wq(vt+0x58,m.stop+0x10);m.wq(emitter+0x50,gob if c['source']else 0)
 for off,values in [(0x1e0,[4,-3,2]),(0x19c,[3,-2,1]),(0x10c,[2,-1,.5]),(0x118,[.5,.5,.5,.5]),(0x1d0,c['quaternion']),(0x178,[1,0,0,0])]:vector(emitter+off,values)
 vector(gob+0xa8,[4.5,-3.5,2.5]);vector(gob+0xb4,[1,0,0,0]);m.wf(emitter+0xb0,.2);m.wf(emitter+0x78,c['bounce']);m.wf(emitter+0xc4,.3)
 m.wq(emitter+0x188,active);m.wi(emitter+0x190,c['count']);particles=[]
 for i in range(c['count']):
  p=m.heap+0x10000+i*0x100;particles.append(p);m.wq(active+i*8,p);vector(p+0x10,[.5+i,.75-i,1+i]);vector(p+0x58,[.3,-.2,.1]);m.wf(p+0x20,.4);vector(p+0x24,[.25,.5,.75]);vector(p+0x34,[1,0,0,0]);vector(p+0x64,[-1,-2,-3]);vector(p+0x4c,[0,0,1]);u.mem_write(p+0x70,bytes([int(i==2)]))
  chunk=m.heap+0x20000+i*0x100;names[chunk]=i;m.wq(p+0x78,chunk if i%2==0 else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'))
 try:u.emu_start(0x140068010,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,reference=read(emitter+0x10c),referenceQuaternion=read(emitter+0x118,4),particles=[dict(position=read(p+0x10),velocity=read(p+0x58),inheritedSpeed=m.rf(p+0x20),quaternion=read(p+0x34,4),trail=read(p+0x64),direction=read(p+0x4c),stopped=u.mem_read(p+0x70,1)[0])for p in particles])
flags=[0,4,16,64,256,1024,320,1088,1280,1364];q=[math.cos(.3),0,math.sin(.3),0]
rows=[run(dict(flags=flag,source=source,delta=delta,bounce=bounce,collision=collision,chunk=chunk,normal=normal,count=3,quaternion=q))for flag,source,delta,(bounce,collision,normal),chunk in itertools.product(flags,[0,1],[0,.1,1.25],[(.5,0,[0,0,1]),(0,1,[0,0,1]),(.5,1,[.2,.4,.8])],[0,1])]
rows.extend([run(dict(flags=flag,source=source,delta=.1,bounce=.5,collision=0,chunk=0,normal=[0,0,1],count=0,quaternion=q))for flag,source in itertools.product(flags,[0,1])])
rows.extend([run(dict(flags=16,source=1,delta=.1,bounce=0,collision=1,chunk=chunk,normal=normal,count=3,quaternion=q))for chunk,normal in itertools.product([0,1],[[0,0,-1],[0,0,0]])])
out=m.root/'backups/animations/native-particle-movement-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
