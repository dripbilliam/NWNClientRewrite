"""Original EffectAppear482 constructor, apply, queue, action body and clear52.
VM/base-effect/allocation/action list/timer/virtual-method boundaries captured.
Native selectors, timing threshold, commandability, flags and return values run.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,actor,effect,ints,app,node,vt,frame=[m.heap+n*0x1000 for n in range(1,9)]
def hook(u,a,n,_):
 global output,lock
 if a in [m.stop,0x1403ac7d0]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286110:m.wi(y,c.get('value',1));m.finish(1)
 elif a==0x140286330:output=dict(type=int.from_bytes(u.mem_read(effect+8,2),'little'),creator=m.si(effect+0x18)&0xffffffff,integer=m.si(ints));m.finish(1)
 elif a==0x140c10324:m.finish(effect)
 elif a==0x1404233d0:m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.finish(effect)
 elif a==0x140425110:m.wi(effect+0x18,y);m.finish()
 elif a==0x140423fc0:m.finish(c.get('value',1))
 elif a==m.stop+0x10:m.finish(actor if c.get('type',5)==5 else 0)
 elif a==m.stop+0x20:calls.append(['animation',y&0xffffffff]);m.finish()
 elif a==m.stop+0x30:m.finish(lock)
 elif a==m.stop+0x40:lock=y&0xffffffff;calls.append(['lock',lock]);m.finish()
 elif a==0x140490b80:calls.append(['clear']);m.finish()
 elif a==0x14048cb80:
  calls.append(['queue',y,z&65535,w,m.si(m.q(rsp+0x28))]);u.mem_write(actor+0x1a,struct.pack('<H',9));m.finish()
 elif a==0x14049aff0:calls.append(['interrupt',y&65535,z&0xffffffff]);m.finish()
 elif a==0x14055ba10:m.finish(app)
 elif a==0x140597180:m.wi(y,12);m.wi(z,3456);m.finish()
 elif a==0x140597a20:m.wi(m.q(rsp+0x30),0);m.wi(m.q(rsp+0x38),c.get('elapsed',0));m.finish(0)
 elif a==0x14055b810:m.finish(app)
 elif a==0x14055f720:m.finish(0)
 elif a in [0x140423770,0x140c10360,0x140c10370]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140517750,0x14051782d),(0x1404272c0,0x140427321),(0x14037d090,0x14037d177),(0x1403ac703,0x1403ac7d0),(0x1403870b0,0x1403877dd),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured appear dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,kind):
 global c,calls,output,lock
 c=case;calls=[];output=None;lock=c.get('lock',0x7f000000);u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(command+0xc,99)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x100,m.stop+0x20);m.wq(vt+0x190,m.stop+0x30);m.wq(vt+0x188,m.stop+0x40)
 u.mem_write(actor+0xc,bytes([c.get('type',5)]));m.wi(actor+0xec,c.get('commandable',1));m.wf(actor+0xdc,2);m.wi(actor+0xc4,10);m.wi(actor+0xc8,2345);m.wi(node,52);m.wi(node+0x9c,c.get('ready',1));u.mem_write(node+0x9a,struct.pack('<H',c.get('count',1)));m.wi(node+0x38,c.get('value',63))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if kind=='action':
  u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RSI,actor);m.wq(frame+0x98,node);u.emu_start(0x1403ac703,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==0x1403ac7d0;result=u.reg_read(UC_X86_REG_RDI)&0xffffffff
 else:
  start={'constructor':0x140517750,'apply':0x1404272c0,'queue':0x14037d090,'clear':0x1403870b0}[kind]
  args=[command,482,c.get('argc',1)] if kind=='constructor' else [app,actor,effect,c.get('loading',0)] if kind=='apply' else [actor,c.get('value',63)] if kind=='queue' else [actor,node,c.get('head',1)]
  for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v)
  u.emu_start(start,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,calls=calls,output=output,result=result,speed=m.rf(actor+0xdc),lock=lock,started=[m.si(actor+0xc4),m.si(actor+0xc8)])
constructors=[run(dict(argc=argc,value=value),'constructor') for argc,value in itertools.product([0,1],[-1,0,1,2,99])]
applies=[run(dict(type=type,value=value,commandable=commandable,loading=loading),'apply') for type,value,commandable,loading in itertools.product([5,9],[-1,0,1,2,99],[0,1],[0,1])]
queues=[run(dict(value=value,commandable=commandable),'queue') for value,commandable in itertools.product([-1,0,63,95],[0,1])]
actions=[run(dict(type=type,count=count,value=value,elapsed=elapsed),'action') for type,count,value,elapsed in itertools.product([5,9],[0,1],[-1,63,95],[0,1,1999,2000,2001,0xffffffff])]
clears=[run(dict(ready=ready,head=head,lock=lock),'clear') for ready,head,lock in itertools.product([0,1],[0,1,2],[100,0x7f000000])]
out=m.root/'backups/animations/native-appear-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,constructors=constructors,applies=applies,queues=queues,actions=actions,clears=clears))+'\n');print(json.dumps(dict(counts={k:len(v) for k,v in dict(constructors=constructors,applies=applies,queues=queues,actions=actions,clears=clears).items()},output=str(out))))
