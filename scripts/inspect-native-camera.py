"""Execute original camera follow55100, quaternion math and gameplay mode
7d0d00/7d0ab0/7d1c90 against synthetic state. Dependency bookkeeping, scene
lookups, camera virtual getters/setters, clipping and finite CRT math are
captured boundaries. Collision/keyholing and GUI input are not claimed here.
Original executable and Ghidra project remain read-only.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
behavior,cam,target,vt,tvt,module,settings,appearance,area,tmp=[m.heap+i*0x1000 for i in range(40,50)]
gamecam,gamevt=cam+0x400,tvt+0x400
ranges=[(0x14022a000,0x140232000),(0x140055100,0x1400554d0)]
for name in ['mode-chase','mode-topdown','mode-stiff','mouse-yaw','mouse-pitch']:
 d=json.loads((m.root/f'backups/animations/rea-camera-{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def vec(a,n=3):return list(struct.unpack('<'+'f'*n,u.mem_read(a,n*4)))
def put(a,v):u.mem_write(a,struct.pack('<'+'f'*len(v),*v))
def xmm(reg=UC_X86_REG_XMM0):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def rf(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def rd(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<d',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140054ad0:m.finish(1);return
 if a==m.stop+0xc0:put(y,vec(target+0x38));m.finish(y);return
 if a==m.stop+0xc8:put(y,vec(cam+0x100,4));m.finish(y);return
 if a==m.stop+0xb8:put(cam+0x100,vec(z,4));put(y,vec(z,4));m.finish(y);return
 if a==m.stop+0xb0:put(cam+0x38,vec(z));put(y,vec(z));m.finish(y);return
 if a==m.stop+0xe8:m.finish(behavior);return
 if a==m.stop+0x40:m.finish(behavior);return
 if a==m.stop+0x78:put(y,[.1]);put(z,[100]);m.finish();return
 if a==m.stop+0x80:m.finish();return
 if a==m.stop+0x1b0:rf(m.rf(behavior+0x54));return
 if a==m.stop+0x48:put(y,vec(cam+0x100,4));m.finish(y);return
 if a==0x1406ab9b0:m.finish(settings);return
 if a==0x1406ac1a0:m.finish(target);return
 if a==0x1407630d0:m.finish(c.get('animation',4));return
 if a in [0x1407cfe60,0x1407cfdb0]:mouse.append(dict(axis='yaw' if a==0x1407cfe60 else 'pitch',value=xmm(UC_X86_REG_XMM1),impulse=z));m.finish();return
 if a in [0x1407cc5f0,0x1407cc640,0x1407cc6e0]:rf({0x1407cc5f0:25,0x1407cc640:89,0x1407cc6e0:1}[a]);return
 if a==0x140c7b170:
  base=struct.unpack('<d',u.reg_read(UC_X86_REG_XMM0).to_bytes(16,'little')[:8])[0];power=struct.unpack('<d',u.reg_read(UC_X86_REG_XMM1).to_bytes(16,'little')[:8])[0];rd(math.pow(base,power));return
 if a==0x140c7c810:rf(math.pow(xmm(),xmm(UC_X86_REG_XMM1)));return
 if a in [0x140c7a2b0,0x140c7ac70,0x140c79a38,0x140c7d6d8]:
  rf({0x140c7a2b0:math.sin,0x140c7ac70:math.cos,0x140c79a38:math.acos,0x140c7d6d8:math.sqrt}[a](xmm()));return
 if a==0x140c8f29c:rf(math.atan2(xmm(),xmm(UC_X86_REG_XMM1)));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
def quat(yaw,pitch):
 u.reg_write(UC_X86_REG_XMM3,0);w.call(0x14022f6d0,[tmp],[yaw,pitch]);return vec(tmp,4)
def setup(case):
 global c
 c=case;t.reset(dict(format=1));m.wq(behavior,vt);m.wq(behavior+0x18,cam);m.wq(behavior+0x20,target);m.wq(cam,tvt);m.wq(target,vt)
 for off,fn in [(0xc0,0xc0),(0xc8,0xc8)]:m.wq(vt+off,m.stop+fn)
 for off,fn in [(0xb0,0xb0),(0xb8,0xb8),(0xc8,0xc8),(0xe8,0xe8),(0x78,0x78),(0x80,0x80)]:m.wq(tvt+off,m.stop+fn)
 m.wq(vt+0x40,m.stop+0x40);m.wq(gamecam,gamevt)
 for off,fn in [(0xe8,0xe8),(0xb0,0x1b0),(0x48,0x48),(0x78,0x78),(0x80,0x80)]:m.wq(gamevt+off,m.stop+fn)
 put(target+0x38,c.get('target',[2.,3.,.5]));put(behavior+0x30,c.get('focus',[1.,1.,1.]));put(behavior+0x3c,[0,0,c.get('height',1.7)])
 for off,key,default in [(0x48,'distance',20),(0x4c,'speed',0),(0x50,'spring',750),(0x54,'yaw',0),(0x58,'turn',0),(0x5c,'pitch',50),(0x60,'tilt',0),(0x64,'clampYaw',0),(0x68,'minYaw',0),(0x6c,'maxYaw',360),(0x70,'clampPitch',1),(0x74,'minPitch',1),(0x78,'maxPitch',89),(0x7c,'clampDist',1),(0x80,'minDist',1),(0x84,'maxDist',25),(0x88,'turnDelta',0),(0x8c,'tiltDelta',0)]:m.wf(behavior+off,c.get(key,default))
 put(cam+0x100,quat(c.get('oldYaw',c.get('yaw',0)),c.get('oldPitch',c.get('pitch',50))))
 m.wq(module+0xe8,gamecam);m.wq(module+0xf8,area);m.wq(area+0x248,area);m.wq(target+0x300,appearance);m.wf(appearance+0xe4,c.get('height',1.7));m.wf(module+0x2b4,-1);m.wf(settings+300,1)
 m.wi(module+0x25c,c.get('initialize',0));m.wi(module+0x134,c.get('manual',0));m.wi(module+0x13c,c.get('manualLatch',0));m.wi(module+0x138,c.get('turning',0));m.wi(module+0x27c,c.get('wasIdle',0));u.mem_write(module+0x144,bytes([c.get('strafe',0)]));m.wi(target+0x1d4,c.get('strafing',0));m.wi(0x141427100,0);m.wi(0x141427104,0)
 rad=math.radians(c.get('facing',0));put(target+0x44,[-math.sin(rad),math.cos(rad),0]);return c
def frame(c):
 setup(c);w.call(0x140055100,[behavior],[c['dt']]);return dict(case=c,focus=vec(behavior+0x30),position=vec(cam+0x38),quaternion=vec(cam+0x100,4),distance=m.rf(behavior+0x48),yaw=m.rf(behavior+0x54),pitch=m.rf(behavior+0x5c),turn=m.rf(behavior+0x58),tilt=m.rf(behavior+0x60),speed=m.rf(behavior+0x4c))
def mode(c):
 setup(c);w.call([0x1407d0d00,0x1407d0ab0,0x1407d1c90][c['mode']],[module],[c['dt']]);return dict(case=c,turn=m.rf(behavior+0x58),manual=m.si(module+0x134),turning=m.si(module+0x138),manualLatch=m.si(module+0x13c),wasIdle=m.si(module+0x27c),height=m.rf(behavior+0x44),distance=m.rf(behavior+0x48),pitch=m.rf(behavior+0x5c))
def pointer(c):
 global mouse
 setup(c);mouse=[];m.wq(0x1412df8b0,area);m.wi(area+0xb8,c['width']);m.wi(area+0xbc,1080);m.wi(settings+0x120,500);m.wi(settings+0x124,500);m.wi(settings+0x144,1);m.wq(settings+0x30,module)
 w.call(0x1406f1300,[settings,500+c['dx']]);w.call(0x1406f13b0,[settings,580+c['dy']]);return dict(case=c,events=mouse)
if __name__=='__main__':
 print(json.dumps(dict(threshold=m.rf(0x1412973ec),turnMultiplier=m.rf(0x1412973fc),axes=[vec(a)for a in [0x14128f938,0x14128f948,0x14128f958]])),flush=True)
 frames=[];modes=[]
 for dt,yaw,pitch,spring,speed in itertools.product([0,.001,.016,.1],[0,35,179,-179],[1,50,89],[1,5,750],[-7.5,0,7.5]):
  c=dict(dt=dt,yaw=yaw,pitch=pitch,spring=spring,speed=speed,oldYaw=30,oldPitch=45,turn=75,tilt=-75,turnDelta=2,tiltDelta=-3)
  try:frames.append(frame(c))
  except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))),flush=True);raise
 for md,dt,yaw,facing,manual,idle,turning in itertools.product(range(3),[.016,.1],[0,179,-179],[-170,-45,0,45,170],[0,1],[0,1],[0,1]):
  c=dict(mode=md,dt=dt,yaw=yaw,facing=facing,manual=manual,animation=0 if idle else 4,turning=turning)
  try:modes.append(mode(c))
  except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))),flush=True);raise
 pointers=[pointer(dict(width=width,dx=dx,dy=dy))for width,dx,dy in itertools.product([800,1440,1920,3840],[-100,-1,0,1,100],[-100,-1,0,1,100])]
 out=m.root/'backups/animations/native-camera-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,frames=frames,modes=modes,pointers=pointers),indent=2)+'\n');print(json.dumps(dict(frames=len(frames),modes=len(modes),pointers=len(pointers),output=str(out))))
