"""Execute original clear-view search7cc070 and prediction7cc730.
Synthetic object/render accessors, CHitInfo bookkeeping and scene ray results
are explicit boundaries; actual search/prediction/quaternion math execute from
the pinned original PE. Capture ordered rays, results and state, no live edits.
"""
import sys,importlib,json,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
g=importlib.import_module('inspect-native-camera');w=g.w;m=g.m;u=g.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(g.hook_handle)
scene,svt=g.area+0x400,g.area+0x600
item={};rays=[]
ranges=[(0x1407cc070,0x1407cc557),(0x1407cc730,0x1407ccaff)]

def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb60:m.finish(g.target if item.get('present',True) else 0);return
 if a in [m.stop+0x518,m.stop+0x540,m.stop+0x558]:m.finish(g.target);return
 if a==m.stop+0x1b8:g.rf(m.rf(g.behavior+0x5c));return
 if a==m.stop+0x1c0:g.rf(m.rf(g.behavior+0x48));return
 if a in [0x1400c0c40,0x1400d3090]:
  # Capture query inputs; dependency/output lists remain empty in synthetic scene.
  u.mem_write(x,bytes(0x80));m.wi(x,y);m.wq(x+8,z);m.wi(x+0x20,k);m.finish(x);return
 if a==m.stop+0x559:
  hit=m.q(u.reg_read(UC_X86_REG_RSP)+0x28)
  blocked=bool(item['mask']&(1<<len(rays)))
  rays.append(dict(start=g.vec(y),end=g.vec(z),blocked=blocked,query=m.si(hit),mask=f'{m.q(hit+8):016x}'))
  m.finish(int(blocked));return
 if any(lo<=a<hi for lo,hi in ranges):return
 g.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)

def run(c):
 global item,rays
 item=c;rays=[];g.setup(c)
 m.wq(g.target+0x00,g.vt);m.wq(g.vt+0x18,m.stop+0x518);m.wq(g.vt+0x140,m.stop+0x540);m.wq(g.vt+0x58,m.stop+0x558)
 g.put(g.target+0x2b4,g.vec(g.target+0x44));m.wq(g.gamevt+0xb8,m.stop+0x1b8);m.wq(g.gamevt+0xc0,m.stop+0x1c0)
 m.wq(g.area+0x248,scene);m.wq(scene,svt);m.wq(svt+0x58,m.stop+0x559)
 g.put(g.module+0x10c,c.get('focus',[1,1,1]));g.put(g.module+0x118,[0,0,c.get('height',1.7)]);g.put(g.module+0x148,[c.get('tilt',0),c.get('turn',0),c.get('tiltDelta',0),c.get('turnDelta',0),c.get('speed',0)])
 # Object center and render position occupy the same native38 vector here.
 out=g.tmp+0x100;g.put(out,[-1234,-1234]);m.wi(g.module+0x140,1)
 try:result=w.call(0x1407cc070,[g.module,0,out,out+4],[c['dt']])
 except Exception:
  print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)),rays=rays)),flush=True);raise
 return dict(case=c,result=result,yaw=m.rf(g.behavior+0x54),selected=g.vec(out,2),focus=g.vec(g.module+0x10c),manualLatch=m.si(g.module+0x13c),turning=m.si(g.module+0x138),rays=rays)

if __name__=='__main__':
 rows=[]
 for dt,facing,mask in itertools.product([0,.001,.016,.1],[-170,0,45,179],range(16)):
  rows.append(run(dict(dt=dt,facing=facing,mask=mask,yaw=35,pitch=50,distance=20,oldYaw=30,oldPitch=45,turn=75,tilt=-75,turnDelta=2,tiltDelta=-3,speed=7.5)))
 rows.append(run(dict(dt=.016,mask=0,present=False)))
 out=m.root/'backups/animations/native-camera-clear-view-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))

