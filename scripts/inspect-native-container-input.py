"""Read-only full decoded container handler and next/previous page owners.
Scalar codec, canonical lookups/casts, old closure, retained owner setter
and LUO clear are captured boundaries; no original client packet/layout claim.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
messagePtr,clientPtr,primaryPtr,alternatePtr,oldPtr,targetPtr,actorPtr,appPtr,repoPtr=[m.heap+n*0x1000 for n in range(1,10)]
def role(ptr):return 'old' if ptr==oldPtr else 'target'
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140476130:calls.append(['readObjectId']);m.finish(c.get('id',200));return
 if a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0));return
 if a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0));return
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(actorPtr if c.get('controlled',True) else 0);return
 if a in [0x14055b850,0x14055b810]:m.finish(appPtr);return
 if a==0x140296470:
  oid=y&0xffffffff;label='old' if oid==c.get('previous',100) else 'target';calls.append(['lookup',oid]);m.wq(z,oldPtr if label=='old' else targetPtr);m.finish(c.get(label+'Status',0));return
 if a in [m.stop+0x10,m.stop+0x18]:calls.append(['asItem' if a==m.stop+0x10 else 'asPlaceable',role(x)]);m.finish(x if c.get(role(x)+'Cast',True) else 0);return
 if a in [0x140465f80,0x1404b1e10]:calls.append(['closeItem' if a==0x140465f80 else 'closePlaceable',role(x),y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1404be930:calls.append(['setOwner',z&0xffffffff,w&0xffffffff]);m.wi(x,z);m.wi(x+4,w);u.mem_write(x+8,b'\0');m.finish();return
 if a in [0x1404be8a0,0x1404bec00] and c['mode']=='input':calls.append(['step',1 if a==0x1404be8a0 else -1]);m.finish();return
 if a==0x14055b890:calls.append(['placeable',y&0xffffffff]);m.finish(targetPtr if c.get('placeable',True) else 0);return
 if a==0x1404c2b40:calls.append(['clearContainer']);m.finish();return
 if not any(lo<=a<hi for lo,hi in [(0x140451810,0x140451b27),(0x1404be8a0,0x1404be930),(0x1404bec00,0x1404bec73)]):raise AssertionError(f'Uncaptured container input dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(clientPtr+0x98,primaryPtr);m.wq(clientPtr+0xa0,alternatePtr);m.wq(primaryPtr,primaryPtr+0x400);m.wi(actorPtr+8,99)
 for ptr in [primaryPtr,alternatePtr]:m.wq(ptr+0x18,ptr+0x200);m.wi(ptr+0x200,c.get('previous',100));m.wi(ptr+0x204,7);u.mem_write(ptr+0x208,bytes([c.get('page',2)]))
 for ptr,label in [(oldPtr,'old'),(targetPtr,'target')]:
  vt=ptr+0x500;m.wq(ptr,vt);m.wq(vt+0x70,m.stop+0x10);m.wq(vt+0x98,m.stop+0x18);u.mem_write(ptr+0xc,bytes([c.get(label+'Type',9)]));m.wi(ptr+0x3c8,c.get('possessor',99));m.wq(ptr+0x3d0,repoPtr if c.get('repository',True) else 0)
 m.wq(targetPtr+0x540,repoPtr if c.get('repository',True) else 0);u.mem_write(repoPtr,bytes([c.get('width',7),c.get('height',15)]));m.wi(repoPtr+4,c.get('boundary',35))
 owner=(alternatePtr if c.get('alternate',False) else primaryPtr)+0x200;rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,messagePtr if c['mode']=='input' else owner);u.reg_write(UC_X86_REG_RDX,clientPtr);u.reg_write(UC_X86_REG_R8,c.get('subtype',1))
 try:u.emu_start(0x140451810 if c['mode']=='input' else 0x1404be8a0 if c['direction']==1 else 0x1404bec00,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,owner=dict(id=m.si(owner)&0xffffffff,field4=m.si(owner+4),field8=u.mem_read(owner+8,1)[0]))
inputs=[run(dict(mode='input',previous=previous,oldType=oldType,oldStatus=oldStatus,targetType=targetType,targetStatus=targetStatus,controlled=controlled)) for previous,oldType,oldStatus,targetType,targetStatus,controlled in itertools.product([100,0x7f000000],[5,6,9],[0,1],[5,6,9],[0,1],[False,True]) if controlled or targetType!=6 or targetStatus!=0]
inputs += [run(dict(mode='input',**{key:value})) for key,values in {'overflow':[1,2],'underflow':[1,2],'subtype':[0,2,3,255],'oldCast':[False],'repository':[False],'possessor':[101,0x7f000000],'id':[0,0x7f000000]}.items() for value in values]
pages=[run(dict(mode='page',direction=direction,page=page,placeable=placeable,repository=repository,alternate=alternate)) for direction,page,placeable,repository,alternate in itertools.product([-1,1],[0,1,2,3,255],[False,True],[False,True],[False,True])]
pages += [run(dict(mode='page',direction=direction,page=page,width=width,height=height,boundary=boundary)) for direction,page,(width,height,boundary) in itertools.product([-1,1],[0,1,255],[(7,5,35),(255,255,1),(1,1,2)])]
out=m.root/'backups/animations/native-container-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,inputs=inputs,pages=pages),indent=2)+'\n');print(json.dumps(dict(output=str(out),inputs=len(inputs),pages=len(pages))))
