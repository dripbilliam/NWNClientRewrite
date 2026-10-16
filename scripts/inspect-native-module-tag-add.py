"""Full original AddToLookupTable47a930, sort-index47d450, GetObjectByTag47d1e0,
GetWaypoint47de70 (game-array/lookup are captured lower boundaries),
CExoString Left16bcb0 and explicit-length assignment03d8c0. Allocation/free,
memcpy and cookie are captured lower boundaries. Not OOM or all lookup APIs.
"""
import importlib.util,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
modulePtr,inputPtr,arrayPtr=[m.heap+n*0x1000 for n in range(1,4)]
appPtr,gameArrayPtr= m.heap+0x9000,m.heap+0xa000

def owning(ptr,value):
 global cursor
 raw=value.encode('cp1252');target=m.heap+cursor;cursor+=(len(raw)+31)&~15;u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)

def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)) if m.q(ptr) else b''

def hook(u,at,n,_):
 global cursor
 if at==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if at==0x14055b850:m.finish(gameArrayPtr);return
 if at==0x140296470:
  record=objects.get(y&0xffffffff)
  if record and record.get('present',True):ptr=m.heap+0xb000+(y&0xffffffff)*16;m.wi(ptr+8,y);u.mem_write(ptr+12,bytes([record.get('objectType',12)]));m.wq(z,ptr);m.finish(0)
  else:m.finish(1)
  return
 if at==0x140c10368:ptr=m.heap+cursor;cursor+=(x+31)&~15;m.finish(ptr);return
 if at==0x140c4f038:assert y<=0x6000;m.finish(arrayPtr);return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if at==0x140c10370:m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=at<hi for lo,hi in [(0x14047a930,0x14047ab3b),(0x14047d450,0x14047d4ed),(0x14047d1e0,0x14047d2cf),(0x14047de70,0x14047dff0),(0x14016bcb0,0x14016bd6c),(0x14003d8c0,0x14003d9ab)]):raise AssertionError(f'Uncaptured tag dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(steps):
 global cursor,objects
 cursor=0x10000;objects={};u.mem_write(m.heap,bytes(0x100000));observations=[];m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr)
 for step in steps:
  objects[step['id']]=step
  owning(inputPtr,step['tag']);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[modulePtr,inputPtr,step['id']]):u.reg_write(reg,value)
  u.emu_start(0x14047a930,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
  entries=[]
  for n in range(m.si(modulePtr+0x328)):
   ptr=m.q(modulePtr+0x320)+n*72;entries.append(dict(tag=bytes(u.mem_read(ptr,65)).split(b'\0')[0].decode('cp1252'),id=m.si(ptr+68)&0xffffffff))
  queries=[]
  for tag,ordinal,kind in [(step['tag'],0,'object'),(step['tag'],1,'object'),(step['tag'],5,'object'),('',0,'object'),(step['tag'],0,'waypoint'),('',0,'waypoint')]:
   owning(inputPtr,tag);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
   for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[modulePtr,inputPtr,ordinal]):u.reg_write(reg,value)
   u.emu_start(0x14047d1e0 if kind=='object' else 0x14047de70,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;queries.append(dict(tag=tag,ordinal=ordinal,kind=kind,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
  observations.append(dict(entries=entries,queries=queries))
 return dict(steps=steps,observations=observations)

rows=[];keys=['','a','A','b','aa','é','€','a\0tail','\0tail','x'*64,'x'*64+'a','x'*64+'b']
for tag in keys:rows.append(run([dict(tag=tag,id=n+1)for n in range(5)]))
rng=random.Random(20261016)
for _ in range(80):rows.append(run([dict(tag=rng.choice(keys),id=n+1,objectType=rng.choice([5,9,12]),present=rng.choice([True,True,False]))for n in range(rng.randrange(1,50))]))
out=m.root/'backups/animations/native-module-tag-add-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),operations=sum(len(r['steps'])for r in rows),output=str(out))))
