"""Full unchanged AnimateParticles140061210 and actual AsMdlNodeEmitter.
Global-transform and virtual Update are explicit lower provider boundaries.
Synthetic source/pose/fade/flags profiles verify visibility/time/history/basis
and dispatch sequencing, not model animation matrices or GPU presentation.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,source,instance,sourceinstance,vt=[m.heap+n*0x1000 for n in range(6)]
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def state():return dict(position=read(emitter+0x1e0),quaternion=read(emitter+0x1d0,4),previous=read(emitter+0x19c),previousQuaternion=read(emitter+0x178,4),reference=read(emitter+0x10c),referenceQuaternion=read(emitter+0x118,4),basis=read(emitter+0x140,9),initialized=u.mem_read(emitter+0x208,1)[0])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x10:
  index=len([v for v in calls if v[0]=='transform']);position=[[10,20,30],[-2,4,1]][index];quaternion=[[.5,.25,-.5,.75],[.5,-.5,.5,.5]][index];calls.append(['transform',position,quaternion]);vector(y,position);vector(z,quaternion);m.finish()
 elif a==m.stop+0x20:calls.append(['update',m.xmm(UC_X86_REG_XMM1),state()]);m.finish()
 elif not(0x140061210<=a<0x1400615ec or 0x14008c2e0<=a<0x14008c2f4):raise RuntimeError(f'Unexpected native frame dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global calls
 calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter,vt);m.wq(vt+0x18,m.stop+0x10);m.wq(vt+0x100,m.stop+0x20);m.wq(emitter+8,node);u.mem_write(node+0x98,b'\x05');m.wi(node+0x174,c['flags']);u.mem_write(emitter+0x208,bytes([c['initialized']]))
 m.wq(emitter+0x50,source if c['source']else 0);m.wq(emitter+0x100,instance if c['instance']else 0);m.wq(source+0x1a8,sourceinstance if c['sourceInstance']else 0);m.wf(instance+0xc8,c['fade']);m.wf(sourceinstance+0xc8,c['sourceFade'])
 vector(source+0xa8,[7,8,9]);vector(source+0xb4,[.5,.5,.5,-.5])
 for off,values in [(0x1e0,[1,2,3]),(0x1d0,[1,0,0,0]),(0x19c,[-1,-2,-3]),(0x178,[0,1,0,0]),(0x10c,[4,5,6]),(0x118,[0,0,1,0]),(0x140,list(range(9)))]:vector(emitter+off,values)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'))
 try:u.emu_start(0x140061210,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,state=state())
rows=[run(dict(flags=flags,initialized=init,source=source,instance=instance,sourceInstance=sourceInstance,fade=fade,sourceFade=sourceFade,delta=delta))for flags,init,source,delta,(instance,sourceInstance,fade,sourceFade)in itertools.product([0,64,128,256,1024,320,1088,1280],[0,1],[0,1],[-.25,0,.1,.5,2],[(0,0,1,1),(1,1,1,1),(1,1,.5,1),(1,1,1,.5),(1,1,2,2)])]
out=m.root/'backups/animations/native-particle-frame-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
