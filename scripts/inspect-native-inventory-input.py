"""Read-only full decoded inventory-input, GUI character-owner and page owners.
Scalar codec, GUI reset/open, canonical lookups/casts and encumbrance are
captured boundaries. No packet encoding or native client panel layout claim.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
messagePtr,clientPtr,primaryPtr,alternatePtr,previousPtr,nextPtr,objectPtr,vtPtr,repoPtr,appPtr=[m.heap+n*0x1000 for n in range(1,11)]
def name(ptr):return 'primary' if ptr==primaryPtr else 'alternate'
def hook(u,a,n,_):
 global objectIndex
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1402d9600:calls.append(['readBool']);m.finish(c.get('open',1));return
 if a==0x140476130:calls.append(['readObjectId']);m.finish(c.get('id',99));return
 if a==0x1402d9630:calls.append(['readByte',y,z]);m.finish(c.get('panel',1));return
 if a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0));return
 if a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0));return
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(objectPtr if c.get('controlled',True) else 0);return
 if a==0x1404be9a0:calls.append(['setOpen',name(x),y&0xffffffff,z&0xffffffff]);m.wi(x+8,y);m.finish();return
 if a==0x1404beab0 and c['mode']=='input':calls.append(['setCharacter',name(x),y&0xffffffff]);m.wi(x+0x10,y);m.finish();return
 if a==0x1404beb40 and c['mode']=='input':calls.append(['setPanel',name(x),z&255]);m.finish();return
 if a==0x14055b3d0:
  calls.append(['creature',y&0xffffffff]);ptr=previousPtr if y&0xffffffff==c.get('old',100) else nextPtr;present=c.get('previous',True) if ptr==previousPtr else c.get('next',True);m.finish(ptr if present else 0);return
 if a==0x1403db1e0:calls.append(['encumbrance',m.si(x+8)&0xffffffff,y&0xffffffff]);m.finish();return
 if a==0x14055b4c0:
  calls.append(['object',y&0xffffffff]);objectIndex+=1;m.finish(objectPtr if c.get('object',True) else 0);return
 if a==m.stop+0x10:calls.append(['asCreature']);m.finish(nextPtr if c.get('cast',True) else 0);return
 if a==0x1404c2d80:calls.append(['clearRepository']);m.finish();return
 if not any(lo<=a<hi for lo,hi in [(0x140451db0,0x140452025),(0x1404beab0,0x1404beb3c),(0x1404beb40,0x1404bebfb)]):raise AssertionError(f'Uncaptured inventory input dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,objectIndex
 c=case;calls=[];objectIndex=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(clientPtr+0x98,primaryPtr);m.wq(clientPtr+0xa0,alternatePtr);m.wi(clientPtr+0x54,99)
 for ptr in [primaryPtr,alternatePtr]:m.wq(ptr,ptr+0x200);m.wi(ptr+8,7);u.mem_write(ptr+0xc,bytes([c.get('current',0)]));m.wi(ptr+0x10,c.get('old',100))
 m.wi(previousPtr+8,c.get('old',100));m.wi(nextPtr+8,c.get('id',101));m.wi(previousPtr+0x96c,7);m.wi(nextPtr+0x96c,8);m.wi(objectPtr+8,99);u.mem_write(objectPtr+0xc,bytes([c.get('type',5)]));m.wq(objectPtr,vtPtr);m.wq(vtPtr+0x60,m.stop+0x10);m.wq(nextPtr+0x958,repoPtr if c.get('repository',True) else 0)
 u.mem_write(repoPtr,bytes([c.get('width',10),c.get('height',36)]));m.wi(repoPtr+4,c.get('boundary',60))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,messagePtr if c['mode']=='input' else primaryPtr);u.reg_write(UC_X86_REG_RDX,(clientPtr if c.get('client',True) else 0) if c['mode'] in ['input','panel'] else c.get('id',101));u.reg_write(UC_X86_REG_R8,c.get('subtype',1) if c['mode']=='input' else c.get('panel',1))
 try:u.emu_start({'input':0x140451db0,'character':0x1404beab0,'panel':0x1404beb40}[c['mode']],m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,owners=[m.si(p+0x10)&0xffffffff for p in [primaryPtr,alternatePtr]],dirty=[m.si(p+0x96c) for p in [previousPtr,nextPtr]],panel=u.mem_read(primaryPtr+0xc,1)[0])
inputs=[run(dict(mode='input',subtype=subtype,open=value,id=id,client=client,controlled=controlled)) for subtype,value,id,client,controlled in itertools.product([1,2,0,3,255],[0,1,2,-1],[99,101,0x7f000000],[True,False],[True,False]) if subtype!=2 or client]
inputs += [run(dict(mode='input',subtype=subtype,**{key:value})) for subtype in [1,2] for key in ['overflow','underflow'] for value in [1,2,-1]]
characters=[run(dict(mode='character',old=old,id=id,previous=previous,next=next)) for old,id,previous,next in itertools.product([100,0x7f000000],[100,101,0x7f000000],[False,True],[False,True])]
panels=[run(dict(mode='panel',panel=panel,current=current,object=present,type=type,cast=cast,repository=repo)) for panel,current,present,type,cast,repo in itertools.product([0,1,5,6,255,257],[0,1],[False,True],[4,5,255],[False,True],[False,True])]
panels += [run(dict(mode='panel',width=w,height=h,boundary=b,panel=panel)) for w,h,b,panel in [(255,255,1,0),(255,255,1,1),(255,255,1,255),(1,1,2,0),(7,5,35,0),(10,36,60,5)]]
out=m.root/'backups/animations/native-inventory-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,inputs=inputs,characters=characters,panels=panels),indent=2)+'\n');print(json.dumps(dict(output=str(out),inputs=len(inputs),characters=len(characters),panels=len(panels))))
