"""Original AIUpdate983860 phase/sound/timer coordinator. Time subtraction,
path update, animation stage, camera read, sound API and destruction are captured
lower boundaries. Attachment is tested with an unresolved target only; camera
facing, real target/weapon impact and audio output are not executed.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,vt,app,client,camera,cvt,sound,svt=[m.heap+n*0x1000 for n in range(1,9)]
destroy,setScene,getCamera,destroySound=[m.stop+n*0x10 for n in range(1,5)]
def vector(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def textAt(a):return bytes(u.mem_read(a,32)).split(b'\0')[0].decode('ascii')
def xmm(r):return struct.unpack('<f',struct.pack('<I',u.reg_read(r)&0xffffffff))[0]
def ui(a):return m.si(a)&0xffffffff
def hook(u,a,n,_):
 global destroyed
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10370:m.finish()
 elif a==0x1406ac330:m.finish(m.heap+0x9000)
 elif a==0x140597180:m.wi(y,10);m.wi(z,1000);m.finish()
 elif a==0x140597a20:m.wi(m.q(rsp+0x30),0);m.wi(m.q(rsp+0x38),c['delta']);m.finish()
 elif a==0x140984f00:
  calls.append(['path',ui(actor+0x194)]);m.wi(actor+0x194,c['pathRemaining']);m.wi(actor+0x58,c['pathElapsed'] if c['pathElapsed']>=0 else c['delta']);m.finish()
 elif a==0x1406abea0:m.finish(client)
 elif a==getCamera:calls.append(['camera']);u.mem_write(y,struct.pack('<4f',1,0,0,0));m.finish()
 elif a==0x1407630d0:calls.append(['stage']);m.finish(int.from_bytes(u.mem_read(actor+0x5c,2),'little'))
 elif a==0x140985510:calls.append(['setStage',y&65535]);u.mem_write(actor+0x5c,struct.pack('<H',y&65535));m.finish(1)
 elif a==0x140c10324:assert x==0x10;m.finish(0 if c['soundFailure'] else sound)
 elif a==0x1401d95b0:calls.append(['createSound',textAt(y)]);m.wq(x,svt);m.finish(x)
 elif a==0x1401da060:calls.append(['priority',y&255]);m.finish()
 elif a==0x1401d9e90:calls.append(['3d',y&0xffffffff]);m.finish()
 elif a==0x1401d9f90:calls.append(['loop',y&0xffffffff]);m.finish()
 elif a==0x1401da020:calls.append(['soundPosition',vector(y),xmm(UC_X86_REG_XMM2)]);m.finish()
 elif a==0x1401d9ca0:calls.append(['play']);m.finish()
 elif a==0x1401da320:calls.append(['stop']);m.finish()
 elif a==destroySound:calls.append(['destroySound']);m.finish()
 elif a==0x1401d9c40:calls.append(['oneShot',textAt(y),vector(z),m.si(rsp+0x28)&255,xmm(UC_X86_REG_XMM3)]);m.finish()
 elif a==0x1406abb70:m.finish(m.heap+0xa000)
 elif a==0x140296470:calls.append(['impactLookup']);m.finish(1)
 elif a==setScene:calls.append(['scene',y]);m.finish()
 elif a==destroy:calls.append(['destroy']);destroyed=True;m.finish()
 elif not 0x140983860<=a<0x140984271:raise AssertionError(f'Uncaptured AI dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,destroyed
 c=case;calls=[];destroyed=False;u.mem_write(m.heap,bytes(0x10000));m.wq(0x1412df970,app);m.wq(actor,vt);m.wq(vt,destroy);m.wq(vt+0x138,setScene);m.wq(client+0xe8,camera);m.wq(camera,cvt);m.wq(cvt+0x48,getCamera);m.wq(sound,svt);m.wq(svt,destroySound)
 u.mem_write(actor+0x38,struct.pack('<3f',1,2,3));u.mem_write(actor+0x5c,struct.pack('<H',c['stage']));m.wi(actor+0x50,9);m.wi(actor+0x54,900)
 for off,key in [(0x194,'remaining'),(0x1e8,'tracked'),(0x1ec,'loopStarted'),(0x1f0,'phase'),(0x1e0,'attachOnImpact')]:m.wi(actor+off,c[key])
 m.wi(actor+0x1fc,25);m.wq(actor+0x1d8,sound if c['sound'] else 0)
 if c['loopSound']:u.mem_write(actor+0x1b0,b'loop\0')
 if c['impactSound']:u.mem_write(actor+0x1c1,b'impact\0')
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
 try:u.emu_start(0x140983860,m.stop,count=5000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,state=dict(remaining=ui(actor+0x194),elapsed=ui(actor+0x58),phase=ui(actor+0x1f0),loopStarted=ui(actor+0x1ec),sound=bool(m.q(actor+0x1d8)),stage=int.from_bytes(u.mem_read(actor+0x5c,2),'little'),lastTime=dict(day=ui(actor+0x50),time=ui(actor+0x54)),destroyed=destroyed))
default=dict(remaining=16,delta=16,pathRemaining=0,pathElapsed=-1,phase=0,tracked=1,loopStarted=0,stage=1,sound=0,loopSound=0,impactSound=0,attachOnImpact=1,soundFailure=0)
rows=[run(default|dict(phase=phase,tracked=tracked,remaining=remaining,delta=delta,stage=stage,sound=kind&1,loopSound=kind>>1))for phase,tracked,remaining,delta,stage,kind in itertools.product([0,1,2],[0,1,2],[0,1,16],[0,16,20],[0,1,2],[0,1,2,3])]
rows += [run(default|dict(loopStarted=started,sound=sound,loopSound=loop,impactSound=impact,attachOnImpact=attach,soundFailure=failure,pathRemaining=remaining,pathElapsed=elapsed))for started,sound,loop,impact,attach,failure,remaining,elapsed in itertools.product([0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,123],[0,1,20])]
out=m.root/'backups/animations/native-client-projectile-ai-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
