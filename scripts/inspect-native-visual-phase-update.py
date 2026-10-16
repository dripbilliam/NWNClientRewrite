"""Complete unchanged visual phase update140971a80..140971e10. Explicit
synthetic client/model, procedural-program, attachment and positional-audio
responses are lower boundaries. Checks phase/countdown/alias/call sequencing,
not the lower procedural implementations or upper client tick/removal owners.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,client,render,manager,vt,sound=[m.heap+n*0x1000 for n in range(6)]
def string(ptr):
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10370:m.finish()
 elif a==0x1406abb60:calls.append(['client',y]);m.finish(client if c['client']else 0)
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a==m.stop+0x20:calls.append(['play',names[x],string(y),m.xmm(UC_X86_REG_XMM2),w&0xffffffff,m.rf(rsp+0x28)]);m.finish(c['play'])
 elif a==0x14096fa90:calls.append(['stopProgram',y&65535]);m.finish()
 elif a==0x140971960:calls.append(['clearProgram']);m.finish()
 elif a==0x14096c340:calls.append(['programType',y&65535]);m.finish(c['type'])
 elif a==0x14096c8e0:calls.append(['loadProgram',y&65535]);m.finish()
 elif a==0x14096a110:calls.append(['startProgram',y&65535]);m.finish()
 elif a==0x14096c180:calls.append(['detach']);m.finish()
 elif a==0x14096c2e0:calls.append(['currentProgram']);m.finish(c['current'])
 elif a==0x140972090:calls.append(['updateProgram',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1401da020:calls.append(['sound',[m.rf(y+i*4)for i in range(3)],m.xmm(UC_X86_REG_XMM2)]);m.finish()
 elif not 0x140971a80<=a<0x140971e10:raise RuntimeError(f'Unexpected native visual phase dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names
 c=case;calls=[];names={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 # The original global client-manager pointer points to a pointer wrapper.
 m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(client,vt);m.wq(vt+0x18,m.stop+0x10);m.wq(vt+0x30,m.stop+0x20)
 m.wi(effect+0x54,123);u.mem_write(effect+0xfa,bytes([c['phase']]));u.mem_write(effect+0xfc,bytes([c['duration']]));m.wi(effect+0xcc,c['programRemaining']);m.wi(effect+0xd8,c['updateProgram']);m.wi(effect+0x114,c['attached']);u.mem_write(effect+0x10d,b'\x63');m.wi(effect+0xf4,7);m.wi(effect+0xe8,c['retiring']);m.wq(effect+0x118,sound if c['sound']else 0)
 models=[m.heap+0x10000+i*0x1000 for i in range(3)]
 if c['alias']:models[2]=models[0]
 for i in range(3):
  names.setdefault(models[i],i);m.wq(models[i],vt);m.wq(effect+0x88+i*8,models[i]);m.wi(effect+0x5c+i*4,c['modelRemaining'][i]);u.mem_write(effect+0x68+i*2,struct.pack('<H',c['states'][i]));u.mem_write(effect+0xd0+i*2,struct.pack('<H',[10,20,30][i]));m.wi(effect+0xc0+i*4,c['retireRemaining'][i]);m.wi(effect+0xdc+i*4,c['retired'][i]);m.wf(render+0x38+i*4,[1.25,-2,3.5][i])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c['delta'])
 try:u.emu_start(0x140971a80,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,phase=u.mem_read(effect+0xfa,1)[0],type=u.mem_read(effect+0x10d,1)[0],programRemaining=m.si(effect+0xcc)&0xffffffff,modelRemaining=[m.si(effect+0x5c+i*4)&0xffffffff for i in range(3)],states=[int.from_bytes(u.mem_read(effect+0x68+i*2,2),'little')for i in range(3)],retireRemaining=[m.si(effect+0xc0+i*4)&0xffffffff for i in range(3)],retired=[m.si(effect+0xdc+i*4)for i in range(3)],finished=m.si(effect+0xf4),retiring=m.si(effect+0xe8))
def profile(**kw):
 c=dict(client=1,render=1,phase=0,duration=1,programRemaining=100,updateProgram=1,attached=1,type=4,current=20,play=1,modelRemaining=[0,0,0],states=[0,0,0],retireRemaining=[100,200,300],retired=[0,0,0],retiring=0,sound=0,delta=100,alias=0);c.update(kw);return c
rows=[run(profile(phase=phase,delta=delta,programRemaining=remaining,duration=duration,attached=attached))for phase,delta,remaining,duration,attached in itertools.product(range(4),[0,50,100,1000],[0,100,1000],[0,1],[0,1])]
rows.extend(run(profile(delta=delta,modelRemaining=remaining,states=states,duration=duration,sound=sound,alias=alias))for delta,(remaining,states),duration,sound,alias in itertools.product([0,50,100,3000],[([100,200,300],[1,1,1]),([0,100,0],[3,3,3]),([0,0,100],[1,2,3]),([100,100,100],[1,2,3])],[0,1],[0,1],[0,1]))
rows.extend(run(profile(**kw))for kw in [dict(client=0),dict(render=0),dict(phase=2,updateProgram=0),dict(retiring=1,retired=[1,0,1]),dict(modelRemaining=[0xffffffff,0,0],states=[3,0,0]),dict(delta=0xffffffff,retiring=1,modelRemaining=[0xffffffff,0,0],states=[3,0,0])])
out=m.root/'backups/animations/native-visual-phase-update-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
