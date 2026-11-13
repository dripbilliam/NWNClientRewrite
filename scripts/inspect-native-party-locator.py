"""Original party tick854320 and angular GUI state-time pipeline.
Camera yaw and object lookup are explicit providers for the tick. Its finite
atanf instruction body also executes unchanged. Angular status1eb510, PlayStateAnimation1fb350, Gob::PlayAnimation
52580 and Gob::Animate4dbd0 execute unchanged for fixed GUI model/scale1.
Model lookup/storage, interface dispatch, allocation, node/event publication
and scene work are captured boundaries. No process, GPU or server is used.
"""
import importlib.util,itertools,json,math,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
def bits(v):return int.from_bytes(struct.pack('<f',v),'little')
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
gob,model,root,vt,runlist,handles,clip,gui=[m.heap+n*0x2000 for n in range(8)]
def listptrs():return [m.q(runlist+i*8) for i in range(m.si(gob+0xe8))]
def writelist(values):
 for i,v in enumerate(values):m.wq(runlist+i*8,v)
 m.wi(gob+0xe8,len(values))
def timehook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140c9a9fc:m.finish(0 if string(x).lower()==string(y).lower() else 1)
 elif a==0x140050f80:m.finish(clip if string(y).lower()=='angle' else 0)
 elif a in [0x140050ed0,0x1402e9a80]:u.reg_write(UC_X86_REG_XMM0,bits(1));m.finish()
 elif a==0x140c10324:
  ptr=m.heap+0x40000+allocation*0x100;allocation+=1;m.finish(ptr)
 elif a==0x140c10360:m.finish()
 elif a==0x140052b30:
  values=listptrs()
  if y in values:values.remove(y)
  writelist(values);m.finish()
 elif a==0x140051b90:
  values=listptrs();values.insert(z&0xffffffff,y);writelist(values);m.finish()
 elif a==0x140047000:u.mem_write(x,(string(y).replace('%s',string(z))).encode()+b'\0');m.finish()
 elif a==0x14008c080:
  # Captured CAurObject interface dispatch to the unchanged Gob clock.
  u.reg_write(UC_X86_REG_RIP,0x14004dbd0)
 elif a==0x14004fe90:
  samples.append(dict(previous=xmm(UC_X86_REG_XMM2),time=xmm(UC_X86_REG_XMM3),timeBits=u.reg_read(UC_X86_REG_XMM3)&0xffffffff));m.finish()
 elif a==m.stop+0x10:m.finish()
 elif a==m.stop+0x20:m.finish(1)
 elif a in [m.stop+0x30,m.stop+0x40,m.stop+0x50]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1401eb510,0x1401eb52f),(0x1401fb350,0x1401fb3f8),(0x140052580,0x140052a23),(0x14004dbd0,0x14004e9de),(0x14004fce0,0x14004fe89)]):raise AssertionError(f'Uncaptured original angular-time dependency {a:x}')
handle=u.hook_add(UC_HOOK_CODE,timehook)
times=[]
for angle in [-1080,-720,-540,-360.1,-360,-359.9,-270,-180,-90,-1,-.0001,-0.0,0,.0001,1,90,180,270,359.9,360,360.1,540,720,1080]:
 allocation=0;samples=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(0x14141e310,bytes(8));m.wq(0x1412e00a0,0);m.wi(0x1412e009c,0)
 m.wq(gob,vt);m.wq(root,vt);m.wq(gob+0x68,model);u.mem_write(model+0x92,b'\1');m.wq(gob+0xe0,runlist);m.wq(gob+8,handles);m.wi(gob+0x14,16);m.wq(gob+0x90,root);m.wq(gui+0x10,gob)
 m.wq(vt+0x30,0x140052580)
 for off,target in [(0x298,0x10),(0x260,0x20),(0x2b8,0x30),(0xd0,0x40),(0x2c8,0x50)]:m.wq(vt+off,m.stop+target)
 u.mem_write(clip+0x10,b'angle\0');m.wf(clip+0x90,12);m.wf(clip+0x94,0);m.wq(clip+0x50,clip+0x500)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,gui);u.reg_write(UC_X86_REG_XMM1,bits(angle))
 u.emu_start(0x1401eb510,m.stop,count=100000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(samples)==1
 times.append(dict(angle=angle,stored=m.rf(gui+0x80),sample=samples[0]))
u.hook_del(handle)
panel,member,client,module,camera,actor,remote,vt,entries=[m.heap+n*0x2000 for n in range(9)]
def tickhook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1406abea0:m.finish(client)
 elif a==0x1406ac1a0:m.finish(actor if case['actor'] else 0)
 elif a==0x140800c90:m.finish(remote if case['present'] else 0)
 elif a==0x14022f5d0:u.reg_write(UC_X86_REG_XMM0,bits(case['yaw']));m.finish()
 elif a==0x1401eb510:
  calls.append(['angle',xmm(UC_X86_REG_XMM1),u.reg_read(UC_X86_REG_XMM1)&0xffffffff]);m.finish()
 elif a==m.stop+0x10:m.finish(y)
 elif a==m.stop+0x20:calls.append(['animation',string(y),xmm(UC_X86_REG_XMM2),u.reg_read(UC_X86_REG_R9)&0xffffffff]);m.finish()
 elif a==0x14008c080:calls.append(['advance',xmm(UC_X86_REG_XMM1)]);m.finish()
 elif a==0x1401e5b50:m.finish()
 elif not (0x140854320<=a<=0x1408546b6 or 0x140c94418<=a<=0x140c945f8):raise AssertionError(f'Uncaptured original party tick dependency {a:x}')
u.hook_add(UC_HOOK_CODE,tickhook)
ticks=[]
for position,yaw,same_area,present,actor_present,was_unknown in itertools.product([[0,0],[0,10],[10,0],[0,-10],[-10,0],[5,9],[-5,9],[-5,-9],[5,-9]],[-180,-90,0,90,180],[False,True],[False,True],[False,True],[0,1]):
 case=dict(position=position,yaw=yaw,sameArea=same_area,present=present,actor=actor_present,unknown=was_unknown,cached=37.5);calls=[]
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,m.heap+0x30000);m.wq(client+0xe8,camera);m.wq(client+0xf8,module);m.wq(camera,vt);m.wq(vt+0x48,m.stop+0x10);m.wq(vt+0x30,m.stop+0x20);m.wi(module+0x118,55)
 m.wq(panel+0x1190,entries);m.wi(panel+0x1198,1);m.wq(entries,member);m.wi(member+0x328,43);m.wi(member+0x35c,55 if same_area else 56);m.wi(member+0x32c,was_unknown);m.wi(member+0x334,1);m.wf(member+0x330,37.5);m.wq(member+0x220,camera)
 for index,value in enumerate(position):m.wf(remote+0x38+index*4,value)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel)
 try:u.emu_start(0x140854320,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 ticks.append(dict(case=case,calls=calls,unknown=m.si(member+0x32c)))
out=m.root/'backups/animations/native-party-locator-v3.json';assert not out.exists(),'Preserve prior observations'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,times=times,ticks=ticks),indent=2));print(json.dumps(dict(output=str(out),times=len(times),ticks=len(ticks),target=m.digest)))
