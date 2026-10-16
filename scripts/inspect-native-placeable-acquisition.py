"""Full AcquireItem1404b11d0 and RemoveItem1404b69d0. Canonical lookup/casts,
source removal, repository membership/add/remove, possession and area removal
are captured lower owners. Pointer replacement/null after merge is exercised;
repository stacking, source child ownership and property loading are separate.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actorPtr,itemPtr,previousPtr,repoPtr,appPtr,refPtr,mergedPtr,vtPtr,infoPtr,sourceRepoPtr=[m.heap+n*0x1000 for n in range(1,11)]
ranges=[(0x1404b11d0,0x1404b134e),(0x1404b69d0,0x1404b6a54)]
def itemid(ptr):return m.si(ptr+0x50)&0xffffffff
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b850:m.finish(appPtr);return
 if a==0x140296470:
  calls.append(['object',y&0xffffffff]);m.wq(z,previousPtr+0x48 if c['sourceType']==6 else previousPtr if c['sourceType'] else 0);m.finish(c.get('lookupStatus',0));return
 if a in [m.stop+0x10,m.stop+0x20]:m.finish(previousPtr);return
 if a==0x1403d7490:calls.append(['removeCreature',itemid(y),z,w,m.si(rsp+0x28),m.si(rsp+0x30)]);m.finish(c.get('remove',1));return
 if a==0x1404b69d0 and mode=='acquire':calls.append(['removePlaceable',itemid(y),z]);m.finish(c.get('remove',1));return
 if a==0x14029ca00:calls.append(['baseInfo']);m.finish(infoPtr);return
 if a==0x14046b250:calls.append(['removeRepository',1 if x==sourceRepoPtr else 0,itemid(y)]);m.finish(c.get('remove',1));return
 if a==0x14046b1d0:calls.append(['removeFromArea',itemid(x)]);m.finish();return
 if a==0x140464200:
  calls.append(['add',itemid(m.q(y)),z&255,w&255,m.si(rsp+0x28),m.si(rsp+0x30)])
  if c.get('replacement')=='null':m.wq(y,0)
  elif c.get('replacement')=='merged':m.wq(y,mergedPtr)
  m.finish(c.get('add',1));return
 if a==0x14046c520:calls.append(['possessor',itemid(x),y&0xffffffff,z,w,m.si(rsp+0x28)]);m.wi(x+0x3c8,y);m.finish();return
 if a==0x140468bd0:calls.append(['contains',itemid(y),z]);m.finish(c.get('contains',1));return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured placeable acquisition dependency {a:x}: {mode}/{c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,operation):
 global c,calls,mode
 c=case;calls=[];mode=operation;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wi(actorPtr+8,99);m.wq(actorPtr+0x540,repoPtr if c.get('repository',True) else 0);m.wi(itemPtr+0x50,100);m.wi(mergedPtr+0x50,101);m.wq(refPtr,itemPtr);source=c.get('sourceId',77);m.wi(itemPtr+0x3c8,c.get('possessor',source));m.wi(mergedPtr+0x3c8,source);m.wq(previousPtr+0x3d0,sourceRepoPtr);m.wi(infoPtr+0x80,c.get('container',1));base=previousPtr+0x48 if c.get('sourceType')==6 else previousPtr;m.wq(base,vtPtr);u.mem_write(base+0xc,bytes([c.get('sourceType',0)]));m.wq(vtPtr+0x60,m.stop+0x10);m.wq(vtPtr+0x70,m.stop+0x20);m.wq(vtPtr+0x98,m.stop+0x10)
 m.wq(0x1412df8f8,appPtr);m.wq(appPtr+0x20,appPtr)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[actorPtr,refPtr,source,c.get('x',255)] if mode=='acquire' else [actorPtr,itemPtr,c.get('clear',0),0]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 m.wi(rsp+0x28,c.get('y',255));m.wi(rsp+0x30,c.get('feedback',1))
 try:u.emu_start(0x1404b11d0 if mode=='acquire' else 0x1404b69d0,m.stop,count=10000)
 except Exception:print(json.dumps(dict(mode=mode,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(mode=mode,case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,item=None if m.q(refPtr)==0 else itemid(m.q(refPtr)),possessors=[m.si(ptr+0x3c8)&0xffffffff for ptr in [itemPtr,mergedPtr]])
rows=[]
for sourceType,lookupStatus,repo,add,replacement in itertools.product([0,5,6,9,14],[0,1,2],[False,True],[0,1,2],['same','null','merged']):rows.append(run(dict(sourceType=sourceType,lookupStatus=lookupStatus,repository=repo,add=add,replacement=replacement),'acquire'))
for sourceType,possessor,x,y,feedback in itertools.product([0,5,6,9],[77,99],[0,255,256,-1],[0,255,257],[0,1,2]):rows.append(run(dict(sourceType=sourceType,possessor=possessor,x=x,y=y,feedback=feedback),'acquire'))
for container,remove in itertools.product([0,1,2],[0,1,2]):rows.append(run(dict(sourceType=6,container=container,remove=remove),'acquire'))
for contains,clear,remove in itertools.product([0,1,2,-1],[0,1,2,-1],[0,1,2]):rows.append(run(dict(contains=contains,clear=clear,remove=remove),'remove'))
out=m.root/'backups/animations/native-placeable-acquisition-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
