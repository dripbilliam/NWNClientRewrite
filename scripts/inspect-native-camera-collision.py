"""Execute full original camera collision primary7d2940/stiff7d3840 and
dispatch7d07d0. Synthetic camera/PC accessors, CHitInfo bookkeeping and scene
queries are boundaries. Native prediction, collision ordering, recovery and
Follow mutations execute from the pinned PE. No live process or asset edits.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
g=importlib.import_module('inspect-native-camera');w=g.w;m=g.m;u=g.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(g.hook_handle)
scene,svt=g.area+0x400,g.area+0x600
case={};rays=[]
ranges=[(0x1407d2940,0x1407d3838),(0x1407d3840,0x1407d4339),(0x1407d07d0,0x1407d0854)]
f=lambda v:struct.unpack('<f',struct.pack('<f',v))[0]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1407cebd0:m.finish(case.get('eligible',1));return
 if a==0x1406f4170:m.finish(case.get('clampsEnabled',1));return
 if a==m.stop+0x640:g.put(y,case.get('cameraPosition',[4,-7,8]));m.finish(y);return
 if a==m.stop+0x6b8:g.rf(m.rf(g.behavior+0x5c));return
 if a==m.stop+0x6c0:g.rf(m.rf(g.behavior+0x48));return
 if a in [0x1400c0c40,0x1400d3090]:
  u.mem_write(x,bytes(0x80));m.wi(x,y);m.wq(x+8,z);m.wi(x+0x20,k);m.finish(x);return
 if a==0x1400c1b80:m.finish();return
 if a==m.stop+0x659:
  start,end=g.vec(y),g.vec(z);blocked=bool(case.get('mask',0)&(1<<len(rays)));point=None
  if blocked:
   t=f(case.get('fraction',.5));point=[f(f(v*f(1-t))+f(t*end[i]))for i,v in enumerate(start)];g.put(z,point);g.put(k,point)
  hit=m.q(u.reg_read(UC_X86_REG_RSP)+0x28);rays.append(dict(start=start,end=end,blocked=blocked,point=point,mode=m.si(hit),mask=f'{m.q(hit+8):016x}'));m.finish(int(blocked));return
 if any(lo<=a<hi for lo,hi in ranges):return
 g.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(c,sequence=None):
 global case,rays
 case=c;g.setup(c);u.mem_write(g.settings+0x1d,bytes([c['mode']]));m.wq(g.gamevt+0x40,m.stop+0x640);m.wq(g.gamevt+0xb8,m.stop+0x6b8);m.wq(g.gamevt+0xc0,m.stop+0x6c0);m.wq(g.area+0x248,scene);m.wq(scene,svt);m.wq(svt+0x58,m.stop+0x659)
 g.put(g.module+0x118,[0,0,c.get('height',1.7)]);g.put(g.module+0x148,[c.get('tilt',0),c.get('turn',0),c.get('tiltDelta',0),c.get('turnDelta',0),c.get('moduleSpeed',0)]);m.wi(g.module+0x140,c.get('findClear',0));m.wi(g.module+0x2bc,c.get('flags',0));m.wi(0x14129740c,c.get('enabled',1));m.wi(0x1414272c0,0)
 for cache,focus in [(0x1414272c4,0x1414272c8),(0x1414272d4,0x1414272d8)]:m.wf(cache,c.get('cachedDistance',0));g.put(focus,c.get('cachedFocus',[0,0,0]))
 steps=[]
 for frame in sequence or [{}]:
  case={**c,**frame};rays=[]
  if 'position'in frame:g.put(g.target+0x38,frame['position'])
  try:w.call(0x1407d07d0,[g.module],[case['dt'],case['speed']])
  except Exception:
   print(json.dumps(dict(case=case,ip=hex(u.reg_read(UC_X86_REG_RIP)),rays=rays)),flush=True);raise
  steps.append(dict(frame=frame,speed=g.xmm(),distance=m.rf(g.behavior+0x48),clampDist=m.rf(g.behavior+0x7c),manual=m.si(g.module+0x134),cache=dict(primary=dict(distance=m.rf(0x1414272c4),focus=g.vec(0x1414272c8)),stiff=dict(distance=m.rf(0x1414272d4),focus=g.vec(0x1414272d8))),rays=list(rays)))
 return dict(case=c,steps=steps)
if __name__=='__main__':
 rows=[]
 for mode,dt,speed,mask,cached in itertools.product([0,1,2],[.001,.016,.1],[-7.5,0,7.5],range(16),[0,23]):rows.append(run(dict(mode=mode,dt=dt,speed=speed,mask=mask,cachedDistance=cached,distance=20,pitch=50,yaw=35,oldYaw=30,oldPitch=45,turn=75,tilt=-75,turnDelta=2,tiltDelta=-3)))
 for mode in range(3):
  for extra in [dict(enabled=0),dict(eligible=0),dict(clampsEnabled=0),dict(findClear=1),dict(flags=2),dict(distance=.5),dict(distance=30)]:rows.append(run(dict(mode=mode,dt=.016,speed=-7.5,mask=7,**extra)))
  rows.append(run(dict(mode=mode,dt=.016,speed=0,mask=0,distance=20,pitch=50,yaw=35),[dict(mask=7),dict(mask=0),dict(mask=0),dict(mask=0,position=[3,4,.5]),dict(mask=15),dict(mask=0,speed=7.5)]))
  rows.append(run(dict(mode=mode,dt=.016,speed=0,mask=0,distance=20,pitch=50,yaw=35),[dict(mask=7)]+[dict(mask=0)for _ in range(320)]))
 out=m.root/'backups/animations/native-camera-collision-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),steps=sum(len(r['steps'])for r in rows),output=str(out))))
