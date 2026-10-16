"""Read-only full SpawnBodyBag/LoadBodyBag, actual AsTAG for the fixed bag
literal, and bounded area event17. Construction, counts, appearance, item
transfer, area insertion, strings/GUI and scheduler are captured boundaries.
This does not establish CopyItem or rendered loot/inventory interaction parity.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
sourcePtr,bagPtr,areaPtr,appPtr,sourceVtPtr,bagVtPtr,areaVtPtr,payloadPtr,namePtr=[m.heap+n*0x1000 for n in range(1,10)]
fields=[(0x3a4,4),(0x350,4),(0x3bc,4),(0x3c0,4),(0x3b8,1),(0x3b0,1),(0x3b4,4),(0x3c4,4),(0x3d0,1),(0xfc,4),(0x3a8,1),(0x32c,2),(0xe4,4),(0xe0,4),(0x370,1),(0x4e0,2),(0x4e2,1),(0x500,4),(0x378,4),(0x264,4),(0x4f8,4),(0x3a0,4),(0x3a9,1),(0x5a0,4),(0x514,4),(0x504,4)]
stringOffsets=[0x380,0x580,0x480,0x3e0,0x3f0,0x400,0x410,0x420,0x430,0x440,0x450,0x460,0x470,0x490,0x4a0,0x4b0,0x4c0,0x4d0]
ranges=[(0x14049c170,0x14049c4ae),(0x1404b4080,0x1404b4648),(0x14016ac40,0x14016adf5)]
def cstr(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('ascii') if ptr else ''
def setString(ptr,text):
 global cursor
 data=text.encode('ascii')+b'\0';p=m.heap+cursor;cursor+=len(data)+16;u.mem_write(p,data);m.wq(ptr,p if text else 0);m.wi(ptr+8,len(text));m.wi(ptr+12,len(data) if text else 0)
def hook(u,a,n,_):
 global cursor,lookupIndex,allocations
 if a in [m.stop,end]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [m.stop+0x100,m.stop+0x108,m.stop+0x110,m.stop+0x118,m.stop+0x120,m.stop+0x128,m.stop+0x130]:
  if a==m.stop+0x100:calls.append(['asCreature']);m.finish(sourcePtr if c.get('creature',False) else 0)
  elif a==m.stop+0x108:calls.append(['asPlaceable']);m.finish((bagPtr if c['mode']=='area' else sourcePtr) if c.get('placeable',c['mode']=='area') else 0)
  elif a==m.stop+0x110:calls.append(['asArea']);m.finish(areaPtr if c.get('asArea',True) else 0)
  elif a==m.stop+0x118:calls.append(['destroy',y&0xffffffff]);m.finish()
  elif a==m.stop+0x120:calls.append(['animation',y&0xffffffff]);m.wi(x+0xd8,y);m.finish()
  elif a==m.stop+0x128:calls.append(['portrait',bytes(u.mem_read(y,17)).split(b'\0')[0].decode()]);m.finish()
  else:calls.append(['sourceName']);m.finish(namePtr)
  return
 if a in [0x14055b850,0x14055b960,0x14055b6e0]:m.finish(appPtr);return
 if a==0x140296470:
  calls.append(['object',y&0xffffffff]);present=c.get('area',True) if c['mode']=='spawn' else c.get('found',True);m.wq(z,(areaPtr if c['mode']=='spawn' else bagPtr) if present else 0);lookupIndex+=1;m.finish(c.get('status',0));return
 if a in [0x1403916b0,0x1404b3db0]:calls.append(['count','creature' if a==0x1403916b0 else 'placeable',y&0xffffffff]);m.finish(c.get('count',1));return
 if a==0x140c10324:
  if c['mode']=='spawn':
   allocations+=1;m.finish((bagPtr if c.get('construct',True) else 0) if allocations==1 else (payloadPtr if c.get('payload',True) else 0));return
 if a in [0x140c10368,0x140c10324]:p=m.heap+cursor;cursor+=(x+15)&~15;u.mem_write(p,bytes(x));m.finish(p);return
 if a==0x1404af9c0:calls.append(['construct',y&0xffffffff]);m.finish(bagPtr);return
 if a in [0x140390230,0x1404b3b80]:calls.append(['appearance','creature' if a==0x140390230 else 'placeable']);m.finish(c.get('appearance',13)&65535);return
 if a==0x1404b4080 and c['mode']=='spawn':calls.append(['load',y&65535]);m.finish(c.get('load',1));return
 if a==0x1404b1350:calls.append(['transfer',y&0xffffffff,z&0xffffffff]);m.finish(c.get('transferred',0));return
 if a==0x140169560:u.mem_write(x,bytes(16));m.wi(x+8,0xffffffff);m.finish(x);return
 if a==0x140169600:
  if x in [bagPtr+0x308,bagPtr+0x330]:calls.append(['localized',x-bagPtr,m.si(y+8)&0xffffffff])
  u.mem_write(x,bytes(u.mem_read(y,16)));m.finish(x);return
 if a==0x14018ded0:
  text=cstr(y).encode('ascii')[:16];u.mem_write(x,text+bytes(17-len(text)));m.finish(x);return
 if a==0x14018de80:
  calls.append(['resref',x-bagPtr,bytes(u.mem_read(y,17)).split(b'\0')[0].decode()]);u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a==0x14003d8c0:
  text=bytes(u.mem_read(y,z)).decode('ascii');setString(x,text)
  if x-bagPtr in stringOffsets:calls.append(['string',x-bagPtr,text])
  m.finish(x);return
 if a==0x14047a930:calls.append(['addTag',cstr(m.q(y)),z&0xffffffff]);m.finish();return
 if a==0x1405570b0:
  payload=m.q(rsp+0x38);calls.append(['event',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),None if not payload else dict(id=m.si(payload)&0xffffffff,position=[m.rf(payload+4+i*4) for i in range(3)])]);m.finish();return
 if a==0x1404b1a40:calls.append(['addToArea',m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.si(rsp+0x30)]);m.finish();return
 if a==0x140c10360:
  if c['mode']=='area':calls.append(['release'])
  m.finish();return
 if a in [0x140c10370,0x1401695b0]:m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x140c89e6c:m.finish(int(chr(x&255).isalnum() if x<128 else False));return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if not any(lo<=a<hi for lo,hi in ranges) and not start<=a<end:raise AssertionError(f'Uncaptured body-bag dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,start,end,cursor,lookupIndex,allocations
 c=case;calls=[];cursor=0x40000;lookupIndex=0;allocations=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr)
 for ptr,vt in [(sourcePtr,sourceVtPtr),(bagPtr,bagVtPtr),(areaPtr,areaVtPtr)]:m.wq(ptr,vt)
 m.wq(sourceVtPtr+0x60,m.stop+0x100);m.wq(sourceVtPtr+0x98,m.stop+0x108);m.wq(sourceVtPtr+0x120,m.stop+0x130);m.wq(areaVtPtr+0x50,m.stop+0x110);m.wq(bagVtPtr,m.stop+0x118);m.wq(bagVtPtr+0x100,m.stop+0x120);m.wq(bagVtPtr+0x1a0,m.stop+0x128);m.wq(bagVtPtr+0x98,m.stop+0x108)
 m.wi(sourcePtr+8,99);m.wi(bagPtr+8,777);m.wi(areaPtr+0x140,88);u.mem_write(sourcePtr+12,bytes([c.get('type',9)]));m.wi(sourcePtr+0xa0,88);m.wi(sourcePtr+0x4e8,c.get('lootable',0));m.wi(sourcePtr+0x4ec,7000);m.wi(sourcePtr+0x4f0,0x7f000000);m.wi(bagPtr+0x510,0x7f000000);m.wi(namePtr+8,4242)
 for i,value in enumerate([1.25,-2.5,3.75]):m.wf(sourcePtr+0xa4+i*4,value);m.wf(payloadPtr+4+i*4,value)
 m.wi(payloadPtr,777)
 if c['mode']=='load':
  for offset,width in fields:u.mem_write(bagPtr+offset,bytes([0xa5])*width)
 rsp=m.stack+0x1f808;u.mem_write(rsp-0x800,bytes(0x900));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,bagPtr if c['mode']=='load' else sourcePtr);u.reg_write(UC_X86_REG_RDX,c.get('appearance',13)&65535)
 if c['mode']=='load':start,end=0x1404b4080,0x1404b4648
 elif c['mode']=='spawn':start,end=0x14049c170,0x14049c4ae
 else:
  start,end=0x14035dba0,0x14035dc26;u.reg_write(UC_X86_REG_R14,c['event']);u.reg_write(UC_X86_REG_R15,areaPtr);u.reg_write(UC_X86_REG_RDI,payloadPtr if c['payload'] else 0);u.reg_write(UC_X86_REG_RBP,m.stack+0x10000)
 try:u.emu_start(start,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,end]
 return dict(case=c,calls=calls,fields={str(offset):int.from_bytes(u.mem_read(bagPtr+offset,width),'little') for offset,width in fields},tag=cstr(m.q(bagPtr+0x20)),sourceBagId=m.si(sourcePtr+0x4f0)&0xffffffff,bagSourceId=m.si(bagPtr+0x510)&0xffffffff,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
loads=[run(dict(mode='load',appearance=appearance)) for appearance in [-1,0,13,157,65539,2147483647]]
default=dict(mode='spawn',type=9,creature=False,placeable=True,area=True,asArea=True,count=1,lootable=0,construct=True,appearance=13,load=1,payload=True,transferred=0)
spawns=[]
for objectType,creature,placeable in [(5,True,False),(9,False,True),(9,False,False),(6,False,False)]:
 for hasArea,asArea,count,lootable in itertools.product([False,True],[False,True],[0,1,2],[0,1,2]):spawns.append(run(default|dict(type=objectType,creature=creature,placeable=placeable,area=hasArea,asArea=asArea,count=count,lootable=lootable)))
for creature,construct,load,payload,appearance,transferred in itertools.product([False,True],[False,True],[0,1,2],[False,True],[13,65539],[0,2]):spawns.append(run(default|dict(type=5 if creature else 9,creature=creature,placeable=not creature,lootable=1,construct=construct,load=load,payload=payload,appearance=appearance,transferred=transferred)))
areas=[run(dict(mode='area',event=event,payload=payload,found=found,status=status,placeable=placeable)) for event,payload,found,status,placeable in itertools.product([16,17,18],[False,True],[False,True],[0,1,2],[False,True]) if not (event==17 and payload and not found and status==0)]
out=m.root/'backups/animations/native-body-bag-owners-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,loads=loads,spawns=spawns,areas=areas),indent=2)+'\n');print(json.dumps(dict(output=str(out),loads=len(loads),spawns=len(spawns),areas=len(areas))))
