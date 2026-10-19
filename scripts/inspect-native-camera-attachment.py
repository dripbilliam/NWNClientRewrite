"""Execute original attachment7cf6f0, lookup thunks6abb60/6d81f0,
SetFollow5b4c0 and Follow constructor53da0 with synthetic client/render objects.
Object-table lookup, AsObject/render accessors, dependency/safe-pointer
bookkeeping, behavior installation/destruction, active-PC lookup and render
invalidation are captured boundaries. No live process changes or asset copies.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
c=importlib.import_module('inspect-native-camera-commands');w=c.w;m=c.m;u=c.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(c.hook_handle)
engine,table,obj,ovt,render,rvt,appearance,pc,oldobj,app=[m.heap+i*0x1000 for i in range(48,58)]
bptr=c.behavior;calls=[];case={}
ranges=[(0x1407cf6f0,0x1407cf9cc),(0x1406abb60,0x1406abb69),(0x1406d81f0,0x1406d8220),(0x14005b4c0,0x14005b543),(0x140053da0,0x140053eaa),(0x1404d0bb0,0x1404d0c46)]
def hook(u,a,n,data):
 global bptr
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140296470:
  calls.append(dict(kind='lookup',id=y&0xffffffff));found=case.get('present',True) and y&0xffffffff==case['targetId'];m.wq(z,obj if found else 0);m.finish(0 if found else 1);return
 if a==0x1404dc490:m.finish(1);return
 if a==m.stop+0x18:m.finish(obj if case.get('asObject',True) else 0);return
 if a==m.stop+0x140:calls.append(dict(kind='render',index=y&255,create=z));m.finish(render if case.get('render',True) else 0);return
 if a==m.stop+0x58:m.finish(obj if case.get('creature',True) else 0);return
 if a==m.stop+0x1c0:c.put(y,case.get('position',[2,3,.5]));m.finish(y);return
 if a==m.stop+0xa0:
  # Execute the real Camera::SetFollow method rather than emulating its defaults.
  u.reg_write(UC_X86_REG_RIP,0x14005b4c0);return
 if a==m.stop+0xe0:bptr=y;m.wq(c.camera+0x458,y);m.finish();return
 if a==m.stop+0xe8:m.finish(bptr);return
 if a==0x140054a90:m.finish(x);return
 if a in [0x1400549e0,0x14004d470]:
  if a==0x14004d470:m.wq(x,y)
  m.finish(x);return
 if a==0x1406ac1a0:m.finish(pc);return
 if a==0x1406abf90:m.finish(oldobj);return
 if a==0x1407ba500:calls.append(dict(kind='return-to-pc'));m.finish();return
 if a==0x1406f4170:m.finish(case.get('clampsEnabled',1));return
 if a==0x1406ab9e0:m.finish(oldobj if y&0xffffffff!=0x7f000000 else 0);return
 if a==0x140810a90:calls.append(dict(kind='invalidate',target=x==obj));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 c.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(item):
 global case,bptr,calls
 case=item;bptr=c.behavior;calls=[];c.setup({});m.wq(w.app,app);m.wq(app+8,engine);m.wi(app+0x28,1);m.wq(engine+0x28,table);m.wq(obj,ovt);m.wq(render,rvt);m.wq(c.camera+0x458,bptr);m.wi(obj+8,item['targetId']);m.wi(pc+8,0xffffffff);m.wq(obj+0x300,appearance);m.wf(appearance+0xe4,item.get('height',1.75));m.wi(c.module+0x124,item.get('oldTarget',0x7f000000));u.mem_write(c.settings+0x1d,bytes([item.get('mode',1)]));c.put(c.module+0x128,item.get('cached',[12.75,35.125,42.5]));
 for off in [0x18,0x140,0x58]:m.wq(ovt+off,m.stop+off)
 m.wq(rvt+0xc0,m.stop+0x1c0);m.wq(c.vt+0xa0,m.stop+0xa0);m.wq(c.vt+0xe0,m.stop+0xe0)
 for address,key in [(0x141427104,'pitchLocked'),(0x141427100,'distanceLocked')]:m.wi(address,item.get(key,0))
 try:w.call(0x1407cf6f0,[c.module,item['targetId'],item.get('findClear',0)])
 except Exception:
  print(json.dumps(dict(case=item,ip=hex(u.reg_read(UC_X86_REG_RIP)),rcx=hex(u.reg_read(UC_X86_REG_RCX)),rdx=hex(u.reg_read(UC_X86_REG_RDX)),follow=hex(bptr),calls=calls)),flush=True);raise
 return dict(case=item,calls=list(calls),targetId=m.si(c.module+0x124)&0xffffffff,findClear=m.si(c.module+0x140),initialTarget=c.vec(c.module+0x10c),defaultOffset=c.vec(c.module+0x118),follow=dict(created=bptr!=c.behavior,focus=c.vec(bptr+0x30),offset=c.vec(bptr+0x3c),distance=m.rf(bptr+0x48),yaw=m.rf(bptr+0x54),pitch=m.rf(bptr+0x5c),spring=m.rf(bptr+0x50),clamps=c.vec(bptr+0x64,9)))
if __name__=='__main__':
 rows=[];packets=[]
 for mode,creature,height,cached,findClear,pitchLock,distLock in itertools.product(range(3),[False,True],[.5,1.75],[[0,0,0],[12.75,35.125,42.5]],[0,1],[0,1],[0,1]):rows.append(run(dict(targetId=0x80000008,mode=mode,creature=creature,height=height,cached=cached,findClear=findClear,pitchLocked=pitchLock,distanceLocked=distLock)))
 for target,old,missing in itertools.product([0xffffffff,0x80000008],[0x7f000000,0xffffffff,0x80000010],['present','asObject','render']):rows.append(run(dict(targetId=target,oldTarget=old,**{missing:False})))
 for target,old in itertools.product([0xffffffff,0x80000008],[0x7f000000,0xffffffff,0x80000010]):rows.append(run(dict(targetId=target,oldTarget=old)))
 for target,clear in itertools.product([0,1,0x80000008,0x7f000000,0xffffffff],[0,1]):
  c.setup({});m.wi(pc+0x48,0);w.call(0x1404d0bb0,[w.message,pc,target,clear]);snap=w.snapshot();packets.append(dict(targetId=target,findClear=bool(clear),body=bytes.fromhex(snap['hex'])[3:].hex()))
 out=m.root/'backups/animations/native-camera-attachment-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows,packets=packets),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),packets=len(packets),output=str(out))))
