"""Complete unchanged visual start140970e20 and cessation140971530,
including all tails missing from Ghidra after free(). Client/model/program,
active-table outputs, camera and audio implementations, heap/string/ref helpers
are explicit synthetic lower boundaries. Checks complete upper phase state and
service sequencing, not the lower services, loader or whole visual acceptance.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,client,render,manager,modelvt,scene,table,sound,soundvt,procedural,procvt,controlled=[m.heap+n*0x1000 for n in range(12)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def cs(ptr):return string(m.q(ptr))
def malloc(size):
 global allocation
 ptr=m.heap+0x80000+allocation*0x100;allocation+=1;return ptr
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(malloc(x))
 elif a==0x140c10324:
  calls.append(['createSound',c['strings']['SoundDuration']['value']if c['strings']['SoundDuration']['found']else'']);m.finish(sound if c['soundAlloc']else 0)
 elif a==0x14018dea0:u.mem_write(x,cs(y).encode()[:15]+b'\0');m.finish(x)
 elif a==0x1401a68f0:
  column=cs(z);entry=c['strings'][column];calls.append(['visualString',y&65535,column]);value=entry['value'];ptr=malloc(len(value)+1);u.mem_write(ptr,value.encode()+b'\0');m.wq(w,ptr);m.wi(w+8,len(value));m.finish(entry['found'])
 elif a in [0x1401a7010,0x1401a6c70]:
  column=cs(z);entry=c['queries'][column];calls.append(['visualInt'if a==0x1401a7010 else'visualFloat',y&65535,column]);m.wi(w,entry['value'])if a==0x1401a7010 else m.wf(w,entry['value']);m.finish(entry['found'])
 elif a==0x1406abb60:calls.append(['client',y]);m.finish(client if c['client']else 0)
 elif a==0x1406abea0:calls.append(['controlled']);m.finish(controlled if c['controlled']else 0)
 elif a==0x1407cbfa0:calls.append(['shakeOnce',y]);m.finish()
 elif a==0x1407cfd00:calls.append(['shakeLoop',y,z]);m.finish()
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a==m.stop+0x20:
  name=string(y);calls.append(['play',names[x],name,m.xmm(UC_X86_REG_XMM2),w&0xffffffff,m.rf(rsp+0x28)]);m.finish(c['plays'][names[x]]if name!='duration'else 0)
 elif a==m.stop+0x30:
  calls.append(['info',names[x],string(y)]);m.wf(z,.05);m.wf(w,c['lengths'][names[x]]);m.finish()
 elif a==0x14096fa90:calls.append(['stopProgram',y&65535]);m.finish()
 elif a==0x140971960:calls.append(['clearProgram']);m.finish()
 elif a==0x14096c340:calls.append(['programType',y&65535]);m.finish(c['types'][str(y&65535)])
 elif a==0x14096c8e0:calls.append(['loadProgram',y&65535]);m.finish()
 elif a==0x14096a110:calls.append(['startProgram',y&65535]);m.finish()
 elif a==0x14096c180:calls.append(['detach']);m.finish()
 elif a==0x1401d9c40:calls.append(['positional',string(y),[m.rf(z+i*4)for i in range(3)],m.xmm(UC_X86_REG_XMM3),m.si(rsp+0x28),m.si(rsp+0x30),u.mem_read(rsp+0x38,1)[0]]);m.finish()
 elif a==0x1401d95b0:m.wq(x,soundvt);m.finish(x)
 elif a in [0x1401d9e90,0x1401da060,0x1401d9f90]:calls.append(['soundSetting',f'setting{a:x}',y&0xffffffff]);m.finish()
 elif a==0x1401d9ca0:calls.append(['playSound']);m.finish()
 elif a==0x1401da320:calls.append(['stopSound']);m.finish()
 elif a==m.stop+0x40:calls.append(['destroySound',y&0xffffffff]);m.finish()
 elif a==m.stop+0x50:calls.append(['detachProcedural',y,z,w]);m.finish()
 elif a==m.stop+0x60:calls.append(['unsceneProcedural',y]);m.finish()
 elif a==m.stop+0x70:calls.append(['destroyProcedural',y&0xffffffff]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not(0x140970e20<=a<0x14097152b or 0x140971530<=a<0x140971955):raise RuntimeError(f'Unexpected native visual control dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names,allocation
 c=case;calls=[];names={};allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(0x1412df8f8,scene);m.wq(scene+0x130,scene+0x500);m.wq(scene+0x500+0x280,table);m.wq(0x1412df8d8,scene+0x700)
 m.wq(client,modelvt);m.wq(modelvt+0x18,m.stop+0x10);m.wq(modelvt+0x30,m.stop+0x20);m.wq(modelvt+0x38,m.stop+0x30);m.wq(sound,soundvt);m.wq(soundvt,m.stop+0x40);m.wq(procedural,procvt);m.wq(procvt+0x98,m.stop+0x50);m.wq(procvt+0x90,m.stop+0x60);m.wq(procvt,m.stop+0x70)
 m.wi(effect+0x54,123);u.mem_write(effect+0xf8,struct.pack('<H',456));m.wi(effect+0xec,c['closed']);m.wi(effect+0xf0,0);m.wi(effect+0xf4,c['finished']);u.mem_write(effect+0xfa,bytes([c['phase']]));u.mem_write(effect+0xfc,bytes([c['duration']]));u.mem_write(effect+0x10c,bytes([c['scope']]));u.mem_write(effect+0x10d,b'\x63');m.wi(effect+0x114,c['attached']);m.wi(effect+0xcc,77);m.wq(effect+0x118,sound if c['sound']else 0);m.wq(effect+0xb8,procedural if c['procedural']else 0)
 for i in range(3):
  model=m.heap+0x10000+i*0x1000;names[model]=i;m.wq(model,modelvt);m.wq(effect+0x88+i*8,model if c['models'][i]else 0);m.wi(effect+0x5c+i*4,[100,200,300][i]);u.mem_write(effect+0x68+i*2,struct.pack('<H',7+i));m.wi(effect+0xc0+i*4,[11,22,33][i]);m.wi(effect+0xdc+i*4,0);u.mem_write(effect+0xd0+i*2,struct.pack('<H',c['programs'][i]));m.wf(render+0x38+i*4,[1.25,-2,3.5][i])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c['requested']&0xffffffff)
 try:u.emu_start(0x140970e20 if c['mode']=='start'else 0x140971530,m.stop,count=200000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,phase=u.mem_read(effect+0xfa,1)[0],type=u.mem_read(effect+0x10d,1)[0],programRemaining=m.si(effect+0xcc)&0xffffffff,modelRemaining=[m.si(effect+0x5c+i*4)&0xffffffff for i in range(3)],states=[int.from_bytes(u.mem_read(effect+0x68+i*2,2),'little')for i in range(3)],retireRemaining=[m.si(effect+0xc0+i*4)&0xffffffff for i in range(3)],retired=[m.si(effect+0xdc+i*4)for i in range(3)],finished=m.si(effect+0xf4),retiring=m.si(effect+0xe8),closed=m.si(effect+0xec),started=m.si(effect+0xf0),sound=int(m.q(effect+0x118)!=0),procedural=int(m.q(effect+0xb8)!=0))
def profile(mode,**kw):
 c=dict(mode=mode,closed=int(mode=='start'),finished=0,scope=0,duration=1,phase=2,attached=1,sound=1,procedural=1,models=[1,1,1],plays=[1,1,1],lengths=[.1,.5,1.25],programs=[10,20,30],types={'10':1,'20':4,'30':4,'65535':0},client=1,render=1,controlled=1,soundAlloc=1,requested=1,queries={'ShakeType':dict(found=1,value=2),'ShakeDuration':dict(found=1,value=1.5),'ShakeDelay':dict(found=1,value=.25)},strings={key:dict(found=1,value=value)for key,value in [('SoundImpact','impact_s'),('SoundDuration','duration_s'),('SoundCessation','cessate_s')]});c.update(kw);return c
rows=[run(profile('start',closed=closed,finished=finished,duration=duration,scope=scope,programs=programs,models=models,plays=plays))for closed,finished,duration,scope,programs,(models,plays)in itertools.product([0,1],[0,1],[0,1],[0,1],[[65535]*3,[10,20,30],[65535,20,30],[65535,65535,30]],[([0,0,0],[0,0,0]),([1,1,1],[1,0,1])])]
rows.extend(run(profile('stop',closed=closed,requested=requested,phase=phase,programs=programs,types=types,models=models,plays=plays))for closed,requested,phase,programs,types,(models,plays)in itertools.product([0,1],[-1,0,1],[0,2],[[65535]*3,[10,20,30],[65535,20,65535]],[{'10':1,'20':4,'30':4,'65535':0},{'10':1,'20':3,'30':4,'65535':0}],[([0,0,0],[0,0,0]),([1,1,1],[1,0,1]),([1,1,0],[0,0,0])]))
extra=[dict(client=0),dict(render=0),dict(controlled=0),dict(soundAlloc=0),dict(sound=0,attached=0,procedural=0),dict(lengths=[3000000,.5,1.25]),dict(queries={key:dict(found=0,value=99)for key in ['ShakeType','ShakeDuration','ShakeDelay']}),dict(queries={'ShakeType':dict(found=1,value=1),'ShakeDuration':dict(found=1,value=10),'ShakeDelay':dict(found=1,value=.5)}),dict(strings={key:dict(found=0,value='ignored')for key in ['SoundImpact','SoundDuration','SoundCessation']})]
rows.extend(run(profile(mode,**kw))for mode,kw in itertools.product(['start','stop'],extra))
out=m.root/'backups/animations/native-visual-phase-control-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
