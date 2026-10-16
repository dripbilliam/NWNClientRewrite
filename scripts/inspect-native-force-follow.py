"""Unchanged VM16714050dc60, force-follow55 owner1403beaa0 and check58
owner1403b1540. Heap/VM/object/cast, action append/front and movement queue
helpers are captured boundaries. Does not establish lower movement/geometry,
Tracy instrumentation, original-process following or network behavior.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,app,server,vm,command,node,vtable=[m.heap+n*0x1000 for n in range(1,9)]
def hook(u,a,n,_):
 global lock
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286160:m.wi(y,100);m.finish(1)
 elif a==0x1402860c0:m.wf(y,c.get('distance',0));m.finish(1)
 elif a==0x140286110:m.wi(y,c.get('flags',0));m.finish(1)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('exists',True) else 0)
 elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(target if c.get('exists',True) else 0)
 elif a==m.stop+0x10:calls.append(['asObject']);m.finish(target if c.get('asObject',True) else 0)
 elif a==m.stop+0x20:m.finish(lock)
 elif a==m.stop+0x30:lock=y&0xffffffff;calls.append(['lock',lock]);m.finish()
 elif a==0x14055b810:calls.append(['message']);m.finish(app if c.get('message',True) else 0)
 elif a==0x14055f720:m.finish(0)
 elif a in [0x14048cb80,0x14048d3f0]:
  args=[];types=[w&0xffffffff]+[m.si(rsp+0x30+i*16) for i in range(11)];pointers=[m.q(rsp+0x28+i*16) for i in range(12)]
  for kind,ptr in zip(types,pointers):
   if kind==0:break
   args.append([kind,m.si(ptr)])
  calls.append(['front' if a==0x14048d3f0 else 'back',y&0xffffffff,z&65535,args]);m.finish(1)
 elif a==0x14037fae0:
  calls.append(['moveFront',y&65535,[m.rf(z),m.rf(z+4),m.rf(z+8)],w&0xffffffff,
   m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.rf(rsp+0x38),m.rf(rsp+0x40),*[m.si(rsp+off) for off in [0x48,0x50,0x58,0x60,0x68,0x70]]]);m.finish(1)
 elif not any(lo<=a<hi for lo,hi in [(0x14050dc60,0x14050debc),(0x1403beaa0,0x1403bf4d1),(0x1403b1540,0x1403b1dba),(0x1403870b0,0x1403877dd)]):raise AssertionError(f'Uncaptured follow dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,lock
 c=case;calls=[];lock=c.get('lock',0x7f000000);u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server+8,server);m.wq(0x1412df910,vm)
 m.wq(actor,vtable);m.wq(vtable+0x190,m.stop+0x20);m.wq(vtable+0x188,m.stop+0x30);m.wi(actor+0xc4,10);m.wi(actor+0xc8,2345);m.wi(node,c.get('action',55));m.wi(node+0x9c,c.get('ready',1))
 m.wi(command+0xc,99);m.wi(actor+8,99);m.wi(target+8,100);m.wq(target,vtable);m.wq(vtable+0x20,m.stop+0x10);m.wi(target+0xa0,88)
 for i,v in enumerate([1,2,3]):m.wf(target+0xa4+i*4,v)
 m.wi(actor+0xec,c.get('commandable',1));m.wi(node+0x38,100);m.wi(node+0x40,c.get('run',1));m.wf(node+0x48,c.get('distance',0));m.wi(node+0x50,c.get('flags',0));u.mem_write(node+0x9a,struct.pack('<H',c.get('count',4)))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x800,bytes(0x900));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['operation']=='command':
  u.reg_write(UC_X86_REG_RCX,command);u.reg_write(UC_X86_REG_RDX,167);u.reg_write(UC_X86_REG_R8,c.get('argc',2));address=0x14050dc60
 elif c['operation']=='clear':
  u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,node);u.reg_write(UC_X86_REG_R8,c['head']);address=0x1403870b0
 else:
  u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,node);address=0x1403beaa0 if c['operation']=='follow' else 0x1403b1540
 u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,lock=lock,started=[m.si(actor+0xc4),m.si(actor+0xc8)])
rows=[run(dict(operation='command',argc=argc,distance=distance,flags=flags,exists=exists,commandable=commandable)) for argc,distance,flags,exists,commandable in itertools.product([1,2,3],[-1,0,.125,5],[-1,0,1],[False,True],[0,1])]
rows += [run(dict(operation='follow',count=count,run=runFlag,distance=distance,flags=flags,exists=exists,asObject=asObject)) for count,runFlag,distance,flags,exists,asObject in itertools.product([2,3,4],[0,1,7],[-1,0,.125,5],[-1,0,1],[False,True],[False,True])]
rows += [run(dict(operation='check',run=runFlag,distance=distance,flags=flags)) for runFlag,distance,flags in itertools.product([0,1,7],[-1,0,.125,5],[-1,0,1])]
rows += [run(dict(operation='clear',action=action,ready=ready,head=head,lock=lock,message=message)) for action,ready,head,lock,message in itertools.product([4,5,48,55,58,60],[0,1],[0,1,2],[100,0x7f000000],[False,True])]
out=m.root/'backups/animations/native-force-follow-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
