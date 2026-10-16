"""Untouched AddCounterSpellActions37e460; AIActionCounterSpell block
3b6b02..3b6f55 (profiling excluded); ClearAction50 full owner3870b0.
Area/creature lookup, action allocation/clear, movement, round initiative,
combat state/mode and orientation are captured lower boundaries.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,area,otherArea,rules,app,node,head,linked,frame,vt=[m.heap+n*0x1000 for n in range(1,12)]
def hook(u,a,n,_):
 global targetAreaCalls,lock
 if a in [m.stop,0x1403b6cc6]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b3d0:m.finish((actor if y==99 else target) if c.get('targetExists',True) else 0)
 elif a==0x140494e80:
  if x==actor:m.finish(0 if c.get('actorNoArea') else area)
  else:
   targetAreaCalls+=1;m.finish(0 if c.get('targetNoArea') or c.get('vanishArea') and targetAreaCalls==2 else otherArea if c.get('otherArea') else area)
 elif a==0x1401690b0:m.finish(head)
 elif a==0x140490b80:calls.append(['clear',m.si(head+0x9c)]);m.finish()
 elif a==0x14048d3f0:
  params=[]
  for i in range(12):
   kind=w&0xffffffff if i==0 else m.si(rsp+0x30+(i-1)*16);ptr=m.q(rsp+0x28+i*16)
   if not kind:break
   params.append([kind,m.si(ptr)&0xffffffff if kind==3 else m.si(ptr)])
  calls.append(['queue',y&0xffffffff,z&65535,params]);m.finish()
 elif a==0x1404953b0:calls.append(['dead','actor' if x==actor else 'target']);m.finish(c.get('dead',0) if x==actor else c.get('targetDead',0))
 elif a==0x140495620:calls.append(['dying','actor' if x==actor else 'target']);m.finish(c.get('dying',0) if x==actor else c.get('targetDying',0))
 elif a==0x14037cc30:calls.append(['activity',y&0xffffffff]);m.finish()
 elif a==0x1403837d0:calls.append(['broadcastState']);m.finish()
 elif a==0x14039f100:calls.append(['initiative']);m.finish()
 elif a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y&65535]);m.finish()
 elif a==0x14037fae0:calls.append(['move',y&65535,list(struct.unpack('<3f',u.mem_read(z,12))),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.rf(rsp+0x38)]);m.finish()
 elif a==0x14037fc80:calls.append(['wait',y&65535]);m.finish()
 elif a==m.stop+0x10:calls.append(['animation',y&65535]);m.finish()
 elif a==m.stop+0x20:lock=y&0xffffffff;calls.append(['lock',lock]);m.finish()
 elif a==m.stop+0x30:calls.append(['lockGet']);m.finish(lock)
 elif a==m.stop+0x40:m.finish(target)
 elif a in [0x14055b810,0x14055f720]:m.finish(0)
 elif a==0x14055b850:m.finish(app)
 elif a==0x140296470:m.wq(z,target if c.get('targetExists',True) else 0);m.finish(0 if c.get('targetExists',True) else 1)
 elif not any(lo<=a<hi for lo,hi in [(0x14037e460,0x14037e71c),(0x1403b6b02,0x1403b6f5b),(0x1403870b0,0x1403877dd)]):raise AssertionError(f'Uncaptured counter action dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,operation):
 global c,calls,targetAreaCalls,lock
 c=case;calls=[];targetAreaCalls=0;lock=c.get('lock',0x7f000000);u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wf(rules+0x18,10)
 for obj,id in [(actor,99),(target,100)]:m.wq(obj,vt);m.wi(obj+8,id)
 for offset,fn in [(0x100,m.stop+0x10),(0x188,m.stop+0x20),(0x190,m.stop+0x30),(0x60,m.stop+0x40)]:m.wq(vt+offset,fn)
 m.wi(actor+0x8d4,c.get('flags',65535));m.wi(area+0x140,1);m.wi(otherArea+0x140,2);m.wi(actor+0x6f4,98);u.mem_write(actor+0x6ef,bytes([c.get('mode',0)]));m.wi(actor+0x81c,7);m.wi(actor+0xc4,4);m.wi(actor+0xc8,5)
 u.mem_write(target+0xa4,struct.pack('<3f',c.get('distance',2),0,0));m.wi(node,50);m.wq(node+0x38,c.get('id',100));u.mem_write(node+0x98,struct.pack('<H',7));m.wi(node+0x9c,c.get('nodeReady',1))
 m.wq(actor+0x100,linked);m.wq(linked,linked+0x100 if c.get('head') is not None else 0);m.wi(head,c.get('head',0) or 0);m.wi(head+0x9c,c.get('headReady',0))
 values=(c.get('ids',[])+[0x7f000000]*10)[:10]
 for i,id in enumerate(values):m.wi(target+0x310+i*4,id)
 m.wi(target+0x338,c.get('count',len(c.get('ids',[]))))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if operation=='execute':
  u.reg_write(UC_X86_REG_RSP,m.stack+0x1f000);u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RDI,actor);u.reg_write(UC_X86_REG_R12,node);u.reg_write(UC_X86_REG_R15,0);u.emu_start(0x1403b6b02,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x1403b6cc6;result=u.reg_read(UC_X86_REG_RBX)&0xffffffff
 else:
  u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c.get('id',100) if operation=='queue' else node);u.reg_write(UC_X86_REG_R8,c.get('isHead',1));u.emu_start(0x14037e460 if operation=='queue' else 0x1403870b0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,calls=calls,result=result,target=m.si(actor+0x6f4)&0xffffffff,headReady=m.si(head+0x9c),lock=lock,consumed=m.si(actor+0x81c),time=[m.si(actor+0xc4),m.si(actor+0xc8)],ids=[m.si(target+0x310+i*4)&0xffffffff for i in range(10)],count=m.si(target+0x338))
queues=[run(dict(id=id,flags=flags,head=head,headReady=headReady),'queue') for id,flags,head,headReady in itertools.product([99,100,0x7f000000],[0,2],[None,15,46,50],[0,1,2])]
queues += [run({key:True},'queue') for key in ['targetExists','actorNoArea','targetNoArea','vanishArea']]+[run({'targetExists':False},'queue')]
actions=[run(dict(dead=dead,dying=dying,targetDead=targetDead,targetDying=targetDying,mode=mode,distance=distance,flags=flags),'execute') for dead,dying,targetDead,targetDying,mode,distance,flags in itertools.product([0,1],[0,1],[0,1],[0,1],[0,4],[2,10,10.000001],[0,2])]
actions += [run({key:True},'execute') for key in ['otherArea','targetNoArea']]+[run(dict(targetExists=False),'execute')]
clears=[run(dict(ids=ids,count=count,nodeReady=ready,isHead=head,targetExists=exists),'clear') for ids,count,ready,head,exists in itertools.product([[],[99],[99,98,99]],[-1,0,1,3],[0,1],[0,1,2],[False,True])]
out=m.root/'backups/animations/native-counterspell-actions-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,queues=queues,actions=actions,clears=clears))+'\n');print(json.dumps(dict(queues=len(queues),actions=len(actions),clears=len(clears),output=str(out))))
