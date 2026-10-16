"""Read-only event11 branches for placeables, waypoints and stores, full
placeable CloseInventory and GetItemCount. Inventory GUI, body-bag, area,
scheduler, animation and virtual destructor calls are captured boundaries.
These observations establish their ordering/gates, not lower loot/GUI parity.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actorPtr,appPtr,areaPtr,vtPtr,clientsPtr,listPtr,eventPtr,repoPtr,nodesPtr=[m.heap+n*0x1000 for n in range(1,10)]
clientPtrs=[m.heap+0x10000+n*0x1000 for n in range(3)]
ranges=[(0x1404b1fa0,0x1404b2197),(0x1404b3db0,0x1404b3e3b)]
def hook(u,a,n,_):
 if a in [m.stop,end]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404b1fa0 and c['mode']=='event':calls.append(['close']);m.finish();return
 if a==0x14049c170:calls.append(['bag']);m.finish();return
 if a in [0x1404b6930,0x14050a470]:calls.append(['removeArea']);m.wi(x+0xa0,0x7f000000);m.finish();return
 if a==0x140494e80:calls.append(['area']);m.finish(areaPtr if m.si(x+0xa0)==88 else 0);return
 if a==0x140364cc0:calls.append(['removeObject',y&0xffffffff]);m.finish();return
 if a==0x14049ae60:calls.append(['setArea',None]);m.wi(x+0xa0,0x7f000000);m.finish();return
 if a==m.stop+0x100:calls.append(['destroy',y&0xffffffff]);m.finish();return
 if a==0x14055b8e0:calls.append(['clients']);m.finish(listPtr);return
 if a==0x1404ba840:
  i=clientPtrs.index(x);calls.append(['controlled',i]);m.finish(x+0x400 if c['controlled'][i] else 0);return
 if a==0x14055b390:
  i=(y&0xffffffff)-100;calls.append(['client',i]);m.finish(clientPtrs[i]+0x100 if c['live'][i] else 0);return
 if a in [0x14055b810,0x14055b960]:m.finish(appPtr);return
 if a==0x1404ccd90:calls.append(['status',(y-clientPtrs[0]-0x100)//0x1000,z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1404be9a0:calls.append(['setOpen',(x-clientPtrs[0]-0x500)//0x1000,y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1404be930:calls.append(['clear',(y-clientPtrs[0]-0x100)//0x1000,z&0xffffffff,w&0xffffffff]);m.wi(x,z);m.wi(x+4,0);m.finish();return
 if a==0x1404d9c30:calls.append(['gui',(y-clientPtrs[0]-0x100)//0x1000,z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x140c10324:m.finish(eventPtr);return
 if a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x);return
 if a==0x1405570b0:calls.append(['event',w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish();return
 if a==m.stop+0x108:calls.append(['animation',y&0xffffffff]);m.finish();return
 if a in [0x140c10370,0x140c10360]:m.finish();return
 if a==0x1404693e0:
  i=(y-nodesPtr)//0x20;calls.append(['item',i]);m.finish(m.heap+0x20000+i*0x100 if c['items'][i] is not None else 0);return
 if a==0x140169110:m.wq(y,m.q(m.q(y)));m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges) and not start<=a<end:raise AssertionError(f'Uncaptured world event dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,start,end
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(actorPtr,vtPtr);m.wq(vtPtr,m.stop+0x100);m.wq(vtPtr+0x100,m.stop+0x108);m.wi(actorPtr+8,99);m.wi(actorPtr+0xa0,88 if c.get('area') else 0x7f000000);m.wi(actorPtr+0xf0,c.get('destroyable',1));m.wi(actorPtr+0x4f8,c.get('hasInventory',1));m.wi(actorPtr+0x508,c.get('count',0))
 rsp=m.stack+0x1f808;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actorPtr)
 if c['mode']=='event':
  frame=m.stack+0x10000;u.reg_write(UC_X86_REG_RBP,frame)
  start,end={'placeable':(0x1404b3898,0x1404b38cb),'waypoint':(0x140509c32,0x140509c62),'store':(0x1404fb4ca,0x1404fb50f)}[c['kind']]
  u.reg_write(UC_X86_REG_RDI,actorPtr);u.reg_write(UC_X86_REG_R12,actorPtr);u.reg_write(UC_X86_REG_RSI,actorPtr);u.reg_write(UC_X86_REG_R13,c['event']);u.reg_write(UC_X86_REG_RAX,c['event']);m.wi(frame+0x128,c['event'])
 elif c['mode']=='close':
  start,end=0x1404b1fa0,0x1404b2197;m.wq(listPtr,clientsPtr);m.wi(listPtr+8,len(c['controlled']))
  for i,ptr in enumerate(clientPtrs[:len(c['controlled'])]):
   m.wq(clientsPtr+i*8,ptr);m.wi(ptr+0x408,100+i);m.wq(ptr+0x98,ptr+0x500);m.wq(ptr+0x500+0x18,ptr+0x600);m.wi(ptr+0x600,c['owners'][i]);m.wq(ptr+0x100+0x98,ptr+0x500);m.wi(ptr+0x604,c['open'][i])
   # A separate current-client inventory can differ from enumeration's record.
   if c['liveOwners'][i]!=c['owners'][i]:m.wq(ptr+0x100+0x98,ptr+0x700);m.wq(ptr+0x700+0x18,ptr+0x800);m.wi(ptr+0x800,c['liveOwners'][i]);m.wi(ptr+0x804,c['open'][i])
 else:
  start,end=0x1404b3db0,0x1404b3e3b;u.reg_write(UC_X86_REG_RDX,c['filter']&0xffffffff);m.wq(actorPtr+0x540,repoPtr if c['repo'] else 0);m.wq(repoPtr+0x10,repoPtr+0x100);m.wq(repoPtr+0x100,nodesPtr if c['items'] else 0)
  for i,value in enumerate(c['items']):m.wq(nodesPtr+i*0x20,nodesPtr+(i+1)*0x20 if i+1<len(c['items']) else 0);m.wi(m.heap+0x20000+i*0x100+0x448,value or 0)
 try:u.emu_start(start,m.stop,count=20000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP) in [end,m.stop]
 return dict(case=c,calls=calls,count=m.si(actorPtr+0x508),areaId=m.si(actorPtr+0xa0)&0xffffffff,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
events=[run(dict(mode='event',kind=kind,event=event,destroyable=destroyable,area=area)) for kind,event,destroyable,area in itertools.product(['placeable','waypoint','store'],[0,10,11,12],[0,1,2,-1],[False,True])]
closes=[]
for count,hasInventory,controlled,owners,live,liveOwners,opened in itertools.product([0,1,2,3,-1],[0,1,2],[[False,True],[True,True]],[[99,99],[88,99]],[[False,False],[True,True]],[[99,99],[88,99]],[[0,1],[2,0]]):closes.append(run(dict(mode='close',count=count,hasInventory=hasInventory,controlled=controlled,owners=owners,live=live,liveOwners=liveOwners,open=opened)))
counts=[run(dict(mode='count',hasInventory=hasInventory,filter=filter,repo=repo,items=items)) for hasInventory,filter,repo,items in itertools.product([0,1,2],[-1,0,1,2],[False,True],[[],[0],[1],[None,0,2,1]])]
out=m.root/'backups/animations/native-world-destroy-events-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,events=events,closes=closes,counts=counts),indent=2)+'\n');print(json.dumps(dict(output=str(out),events=len(events),closes=len(closes),counts=len(counts))))
