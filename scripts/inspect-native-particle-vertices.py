"""Unchanged shared RenderStandard/Linked/MotionBlur CPU draw owner
1400643b0 ->140062900..14006416c, actual vector/quaternion/tint/clamp/fast_rsqrt
and embedded CRT SSE float trig. Material/GPU allocation/state/shader calls,
source scale, scene light color and IEEE floorf are captured boundaries.
Reads the generated original 24-byte vertex stream; no proprietary assets or
GPU code copied. This verifies draw inputs, not pixels or shader parity.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,source,instance,sourceinstance,vt,camera,material,scene=[m.heap+n*0x1000 for n in range(9)]
stream,vertices=m.heap+0x70000,m.heap+0x80000
ranges=[(0x140062900,0x14006416c),(0x1400643b0,0x1400643b5),(0x14022db30,0x14022dbf2),(0x14022ab00,0x14022ac34),(0x14022fba0,0x14022fbfa),(0x14022b150,0x14022b1b0),(0x14022fd20,0x14022fd61),(0x14022fa30,0x14022fac4),(0x14022fad0,0x14022fb01),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f)]
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def float_result(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,_):
 global committed,soft,drawn
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:calls.append(['source',c['factor']]);float_result(c['factor'])
 elif a==0x140082630:m.finish()
 elif a in [0x1400be9e0,0x1400bea90,0x1400bf0e0,0x1400beff0,0x1400bf0b0,0x140082b80]:m.finish()
 elif a==0x1400bdaf0:m.finish(stream)
 elif a==0x1400bd890:m.finish(vertices)
 elif a==0x1400bd5d0:committed=y;m.finish()
 elif a==0x1400bebf0:m.finish(m.heap+0x60000)
 elif a==0x1400bf260:soft=m.xmm(UC_X86_REG_XMM1);m.finish()
 elif a==0x1400beed0:drawn=z;m.finish()
 elif a==0x14007ee50:calls.append(['tint',read(z)]);vector(y,c['tint']);m.finish(y)
 elif a==0x140c7ed44:float_result(math.floor(m.xmm(UC_X86_REG_XMM0)))
 elif a==0x140c7d6d8:float_result(math.sqrt(m.xmm(UC_X86_REG_XMM0)))
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected native draw dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
threshold=m.rf(0x140d810b0)
def run(case):
 global c,calls,committed,soft,drawn
 c=case;calls=[];committed=drawn=0;soft=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wi(0x1413012e8,0);m.wq(0x141301318,stream);m.wi(0x14128e38c,4096);m.wq(0x141301320,m.heap+0x60000);m.wq(0x141301328,m.heap+0x60000);m.wq(0x1412e0318,camera);m.wi(0x1415d8224,0);m.wq(0x14140ac50,scene);m.wq(scene+0x158,m.heap+0x65000)
 m.wq(emitter+8,node);m.wq(emitter+0x50,source if c['source']else 0);m.wq(source,vt);m.wq(vt+0x2d0,m.stop+0x10);m.wq(source+0x1a8,sourceinstance if c['sourceInstance']else 0);m.wq(emitter+0x100,instance if c['instance']else 0);m.wq(emitter+0x1b8,material)
 vector(emitter+0x1e0,[1,2,3]);vector(emitter+0x1d0,[.5,.5,.5,.5]);vector(camera+0xbc,c['camera']);m.wf(source+0x108,c['opacity']);m.wf(instance+0xc8,c['fade']);m.wf(sourceinstance+0xc8,c['sourceFade']);m.wf(instance+0x50,c['height']);m.wf(sourceinstance+0x50,c['height']);m.wf(instance+0x70,c['elevationOpacity']);m.wf(sourceinstance+0x70,c['elevationOpacity'])
 m.wi(node+0x174,c['flags']);m.wi(node+0xac,c['grid'][0]);m.wi(node+0xb0,c['grid'][1]);m.wi(node+0x168,c['twoSided']);m.wi(emitter+0x1a8,c['mode']);m.wi(emitter+0x68,c['blend']);u.mem_write(emitter+0x1cc,struct.pack('<H',c['ageMode']))
 vector(emitter+0x88,c['colorStart']);vector(emitter+0x7c,c['colorEnd'])
 for off,value in [(0xac,c['life']),(0x9c,c['fps']),(0xa4,c['frameStart']),(0xa0,c['frameEnd']),(0x70,c['alphaStart']),(0x6c,c['alphaEnd']),(0xc4,c['sizes'][0]),(0xc8,c['sizes'][1]),(0xcc,c['sizes'][2]),(0xd0,c['sizes'][3])]:m.wf(emitter+off,value)
 active=m.heap+0x9000;m.wq(emitter+0x188,active);m.wi(emitter+0x190,c['count'])
 particles=[]
 for i in range(c['count']):
  ptr=m.heap+0x10000+i*0x100;m.wq(active+i*8,ptr);vector(ptr+0x10,[1+i,2+i*2,3-i]);vector(ptr+0x64,[-1+i,1+i*2,2-i]);vector(ptr+0x34,[.5,-.5,.5,.5]);vector(ptr+0x4c,[0,0,1]);m.wf(ptr+0x1c,c['rotation']+i*.125);m.wf(ptr+0x74,c['age']+i*.125);m.wf(ptr+0x48,c['frameTime']);m.wi(ptr+0x44,c['initialFrame']);u.mem_write(ptr+0x70,bytes([c['stopped']]));particles.append(ptr)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter)
 try:u.emu_start(0x1400643b0,m.stop,count=150000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,committed=committed,drawn=drawn,soft=soft,words=list(struct.unpack('<'+'I'*(committed*6),u.mem_read(vertices,committed*24))),particles=[dict(frame=m.si(ptr+0x44),frameTime=m.rf(ptr+0x48))for ptr in particles])
def profile(**kw):
 c=dict(mode=0,count=2,source=1,factor=.75,sourceInstance=0,instance=0,opacity=.8,fade=1,sourceFade=1,height=0,elevationOpacity=.6,camera=[.5,.5,.5,.5],flags=0,grid=[1,1],twoSided=0,blend=0,ageMode=1,life=1,fps=10,frameStart=0,frameEnd=7,initialFrame=0,frameTime=0,colorStart=[.8,.4,.1],colorEnd=[.1,.5,.9],alphaStart=.9,alphaEnd=.1,sizes=[2,.5,0,0],tint=[.5,1.5,2],rotation=.25,age=.4,stopped=0);c.update(kw);return c
rows=[run(profile(mode=mode,flags=flags,stopped=stopped,ageMode=ageMode,grid=grid))for mode,flags,stopped,ageMode,grid in itertools.product(range(7),[0,8,512,520],[0,1],[0,1],[[1,1],[4,2]])]
rows.extend(run(profile(**kw))for kw in [dict(count=0),dict(count=1,mode=3),dict(life=0),dict(life=-1),dict(source=0),dict(instance=1,fade=.5),dict(sourceInstance=1,sourceFade=.5),dict(instance=1,height=10),dict(instance=1,height=0),dict(count=3,sizes=[2,.5,3,.25]),dict(sizes=[2,2,3,3],colorEnd=[.8,.4,.1],alphaEnd=.9),dict(frameStart=7,frameEnd=0,initialFrame=7,grid=[4,2]),dict(fps=0,grid=[0,2]),dict(frameStart=3,frameEnd=3,initialFrame=3,grid=[4,2]),dict(age=1.25,grid=[4,2]),dict(age=-.25,grid=[4,2]),dict(mode=4,camera=[.5,.5,-.5,.5]),dict(mode=0,camera=[1,0,0,0]),dict(mode=5,grid=[4,2],rotation=0),dict(colorStart=[-1,3,.5],colorEnd=[2,-1,1.5],alphaStart=3,alphaEnd=-1),dict(blend=1,twoSided=1)])
out=m.root/'backups/animations/native-particle-vertices-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,elevationThreshold=threshold,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
