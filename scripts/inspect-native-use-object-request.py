"""Read-only full client InputMessage dispatched to subtype11 and full
NWScript ActionInteractObject owner. Decoded scalar/client/cast/VM reads,
lookup, ActionManager, AddUseObjectAction and scheduler are captured boundaries.
No client packet serialization or original radial sender flag claim.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
messagePtr,clientPtr,objPtr,actorPtr,vtPtr,guiPtr,commandPtr,placeablePtr,appPtr,eventPtr=[m.heap+n*0x1000 for n in range(1,11)]
def hook(u,a,n,_):
 global overflowIndex,boolIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(objPtr if c.get('object',True) else 0);return
 if a==m.stop+0x10:calls.append(['asCreature']);m.finish(actorPtr if c.get('creature',True) else 0);return
 if a==0x1402d9460:overflowIndex+=1;calls.append(['overflow']);m.finish(int(c.get('overflow',0)==overflowIndex));return
 if a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0));return
 if a==0x140476130:calls.append(['readObjectId']);m.finish(c.get('targetId',100));return
 if a==0x1402d9600:value=[c.get('popup',0),c.get('notify',0)][boolIndex];boolIndex+=1;calls.append(['readBool']);m.finish(value);return
 if a==0x14037cbc0:calls.append(['actionManager',99,y&0xffffffff]);m.finish();return
 if a==0x1404ab5b0:calls.append(['use',m.si(x+8)&0xffffffff,y&0xffffffff]);m.finish(c.get('addResult',1));return
 if a==0x140c10324:m.finish(eventPtr);return
 if a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x);return
 if a==0x14055b960:m.finish(appPtr);return
 if a==0x1405570b0:calls.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish();return
 if a==0x140286160:calls.append(['popObject']);m.wi(y,c.get('targetId',100));m.finish(c.get('pop',1));return
 if a==0x14055b890:calls.append(['placeable',y&0xffffffff]);m.finish(placeablePtr if c.get('target',True) else 0);return
 if a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actorPtr if c.get('actor',True) else 0);return
 if not any(lo<=a<hi for lo,hi in [(0x1404531b0,0x140455858),(0x14050dec0,0x14050df3a)]):raise AssertionError(f'Uncaptured use-object request dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,overflowIndex,boolIndex
 c=case;calls=[];overflowIndex=boolIndex=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(objPtr,vtPtr);m.wq(vtPtr+0x60,m.stop+0x10);m.wi(actorPtr+8,99);m.wi(actorPtr+0x8ac,c.get('field8ac',0));m.wi(actorPtr+0xa0,c.get('areaId',88));m.wq(clientPtr+0x98,guiPtr);m.wq(guiPtr+0x18,guiPtr+0x100);m.wi(guiPtr+0x104,7);m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wi(commandPtr+0xc,99);m.wi(placeablePtr+8,c.get('targetId',100))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,messagePtr if c['mode']=='input' else commandPtr);u.reg_write(UC_X86_REG_RDX,clientPtr);u.reg_write(UC_X86_REG_R8,11)
 try:u.emu_start(0x1404531b0 if c['mode']=='input' else 0x14050dec0,m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,field4=m.si(guiPtr+0x104))
inputs=[run(dict(mode='input',popup=popup,notify=notify,addResult=addResult,field8ac=field,areaId=area)) for popup,notify,addResult,field,area in itertools.product([0,1,2,-1],[0,1,2,-1],[0,1,2],[0,1],[88,0x7f000000])]
inputs += [run(dict(mode='input',**{key:value})) for key,values in {'object':[False],'creature':[False],'field8ac':[-1],'overflow':[1,2],'underflow':[1],'targetId':[0,0x7f000000,0x80000077]}.items() for value in values]
commands=[run(dict(mode='command',target=target,actor=actor,targetId=id,pop=pop,addResult=addResult)) for target,actor,id,pop,addResult in itertools.product([False,True],[False,True],[0,100,0x7f000000,0x80000077],[0,1],[0,1,2])]
out=m.root/'backups/animations/native-use-object-request-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,inputs=inputs,commands=commands),indent=2)+'\n');print(json.dumps(dict(output=str(out),inputs=len(inputs),commands=len(commands))))
