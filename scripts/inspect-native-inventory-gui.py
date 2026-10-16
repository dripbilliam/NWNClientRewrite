"""Read-only full inventory GUI/LUO constructors, owner setter, SetOpen,
placeable OpenInventory and per-player CloseInventory. List head removal,
entry release, old-owner closure, client/GUI transport, scheduler and animation
are captured boundaries. No inventory content replication or pickup claim.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actorPtr,clientPtr,primaryPtr,alternatePtr,ownerPtr,appPtr,oldPtr,vtPtr,eventPtr=[m.heap+n*0x1000 for n in range(1,10)]
controlledPtr=m.heap+0xa000
ranges=[(0x1404be930,0x1404be996),(0x1404be9a0,0x1404beaab),(0x1404c2dc0,0x1404c2eec),(0x1404c2d80,0x1404c2dbe),(0x1404c2b00,0x1404c2b3e),(0x1404c2b40,0x1404c2ba0),(0x1404c1d50,0x1404c1eb0),(0x1404b7bf0,0x1404b7c79),(0x1404b6720,0x1404b6915),(0x1404b1e10,0x1404b1f9c)]
def hook(u,a,n,_):
 global cursor
 if a in [m.stop,0x1404b3883]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:p=m.heap+cursor;cursor+=(x+15)&~15;u.mem_write(p,bytes([0xa5])*x);m.finish(p);return
 if a==0x1401692a0:
  node=m.q(x);m.wq(x,m.q(node));m.wi(x+0x10,m.si(x+0x10)-1);m.finish(m.q(node+8));return
 if a in [0x140c10360,0x140c10370]:
  if x in entries:calls.append(['release',entries[x]])
  m.finish();return
 if a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(clientPtr if c.get('client',True) else 0);return
 if a==0x1404ba840:calls.append(['controlled']);m.finish(controlledPtr if c.get('controlled',True) else 0);return
 if a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,oldPtr);m.finish(c.get('status',0));return
 if a in [0x14055b850,0x14055b810,0x14055b960]:m.finish(appPtr);return
 if a in [m.stop+0x100,m.stop+0x108]:calls.append(['asItem' if a==m.stop+0x100 else 'asPlaceable']);m.finish(oldPtr);return
 if a in [0x140465f80,0x1404b1e10] and not (a==0x1404b1e10 and c['mode']=='close'):
  calls.append(['closeItem' if a==0x140465f80 else 'closePlaceable',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1404be930 and c['mode'] in ['open','close']:
  calls.append(['setOwner',z&0xffffffff,w&0xffffffff]);m.wi(x,z);m.wi(x+4,w);u.mem_write(x+8,b'\0');m.finish();return
 if a==0x1404be9a0 and c['mode'] in ['open','close']:
  calls.append(['setOpen',y&0xffffffff,z&0xffffffff]);m.wi(x+8,y);m.finish();return
 if a==0x1404d9c30:calls.append(['gui',z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1404ccd90:calls.append(['status',z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x);return
 if a==0x1404998a0:calls.append(['script',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==m.stop+0x110:calls.append(['animation',y&0xffffffff]);m.wi(x+0xd8,y);m.finish();return
 if a==0x1405570b0:calls.append(['event',w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges+[(0x1404b32f1,0x1404b330c),(0x1404b3878,0x1404b3883)]):raise AssertionError(f'Uncaptured inventory GUI dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def gui(ptr,name):
 luo=ptr+0x200;inv=ptr+0x400;m.wq(ptr,luo);m.wq(ptr+0x18,inv);m.wi(ptr+8,c.get('oldOpen',0));m.wi(ptr+0xc,7);m.wi(ptr+0x10,100);m.wi(inv,c.get('primaryId' if name=='primary' else 'alternateId',0x7f000000));m.wi(inv+4,c.get('field4',1));u.mem_write(inv+8,b'\x07');m.wi(luo+0xa8,0);m.wi(luo+0x98,555)
 for i in range(18):m.wi(luo+i*4,200+i);m.wi(luo+0x48+i*4,7+i)
 for offset,label in [(0x90,'list90'),(0xa0,'listA0'),(0xb0,'listB0'),(0xb8,'listB8')]:
  base=ptr+0x500+(offset-0x90)*0x10;m.wq(luo+offset,base);count=c.get('listCount',2);nodes=base+0x500
  m.wq(base,nodes if count else 0);m.wq(base+8,nodes+(count-1)*0x20 if count else 0);m.wi(base+0x10,count)
  for n in range(count):node=nodes+n*0x20;entry=base+0x800+n*0x20;m.wq(node,nodes+(n+1)*0x20 if n+1<count else 0);m.wq(node+8,entry);entries[entry]=f'{name}:{label}:{n}'
def snapshot(ptr):
 luo=m.q(ptr);inv=m.q(ptr+0x18)
 return dict(field8=m.si(ptr+8),fieldC=int.from_bytes(u.mem_read(ptr+0xc,1),'little'),ownerId=m.si(ptr+0x10)&0xffffffff,openInventory=dict(id=m.si(inv)&0xffffffff,field4=m.si(inv+4),field8=u.mem_read(inv+8,1)[0]),lastUpdate=luoSnapshot(luo))
def luoSnapshot(luo):return dict(items=[m.si(luo+i*4)&0xffffffff for i in range(18)],itemFields=[m.si(luo+0x48+i*4) for i in range(18)],field98=m.si(luo+0x98)&0xffffffff,dirtyA8=u.mem_read(luo+0xa8,1)[0],**{label:m.si(m.q(luo+offset)+0x10) for offset,label in [(0x90,'list90'),(0xa0,'listA0'),(0xb0,'listB0'),(0xb8,'listB8')]})
def run(case):
 global c,calls,cursor,entries
 c=case;calls=[];cursor=0x50000;entries={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(clientPtr+0x98,primaryPtr);m.wq(clientPtr+0xa0,alternatePtr);gui(primaryPtr,'primary');gui(alternatePtr,'alternate')
 m.wq(actorPtr,vtPtr);m.wq(vtPtr+0x100,m.stop+0x110);m.wi(actorPtr+8,100);m.wi(controlledPtr+8,100);m.wi(actorPtr+0x4f8,c.get('hasInventory',1));m.wi(actorPtr+0x508,c.get('count',0));m.wq(oldPtr,vtPtr);m.wq(vtPtr+0x70,m.stop+0x100);m.wq(vtPtr+0x98,m.stop+0x108);u.mem_write(oldPtr+12,bytes([c.get('type',9)]))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,primaryPtr)
 mode=c['mode'];start={'owner':0x1404be930,'setOpen':0x1404be9a0,'luoCtor':0x1404c1d50,'guiCtor':0x1404b7bf0,'open':0x1404b6720,'close':0x1404b1e10,'event':0x1404b32f1 if c.get('event')==22 else 0x1404b3302}[mode]
 if mode=='owner':
  owner={'primary':primaryPtr+0x400,'alternate':alternatePtr+0x400,'detached':ownerPtr}[c['owner']];m.wi(owner,c['previous']);u.reg_write(UC_X86_REG_RCX,owner);u.reg_write(UC_X86_REG_RDX,clientPtr if c['client'] else 0);u.reg_write(UC_X86_REG_R8,c['id']);u.reg_write(UC_X86_REG_R9,c['open']&0xffffffff)
 elif mode=='setOpen':u.reg_write(UC_X86_REG_RDX,c['value']&0xffffffff);u.reg_write(UC_X86_REG_R8,c['notify']&0xffffffff)
 elif mode in ['open','close']:m.wi(actorPtr+8,99);u.reg_write(UC_X86_REG_RCX,actorPtr);u.reg_write(UC_X86_REG_RDX,100);u.reg_write(UC_X86_REG_R8,c.get('closeGUI',0)&0xffffffff)
 elif mode=='luoCtor':u.reg_write(UC_X86_REG_RCX,ownerPtr)
 elif mode=='event':u.reg_write(UC_X86_REG_RDI,actorPtr);u.reg_write(UC_X86_REG_R15,c['caller']);m.wi(actorPtr+0x520,0x7f000000);m.wi(actorPtr+0x524,0x7f000000)
 try:u.emu_start(start,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x1404b3883]
 result=dict(case=c,calls=calls,primary=snapshot(primaryPtr),alternate=snapshot(alternatePtr),count=m.si(actorPtr+0x508))
 if mode=='owner':result['owner']=dict(id=m.si(owner)&0xffffffff,field4=m.si(owner+4),field8=u.mem_read(owner+8,1)[0])
 if mode=='luoCtor':result['luo']=luoSnapshot(ownerPtr)
 if mode=='event':result['eventFields']=[m.si(actorPtr+offset)&0xffffffff for offset in [0x520,0x524]]
 return result
constructors=[run(dict(mode=mode)) for mode in ['luoCtor','guiCtor']]
owners=[run(dict(mode='owner',owner=owner,client=client,previous=previous,id=id,open=opened,primaryId=primary,alternateId=alternate,listCount=2)) for owner,client,previous,id,opened,primary,alternate in itertools.product(['primary','alternate','detached'],[False,True],[0x7f000000,99],[0x7f000000,99,100],[0,2],[0x7f000000,99],[0x7f000000,99])]
opens=[run(dict(mode='setOpen',value=value,oldOpen=old,notify=notify,primaryId=previous,type=objectType,status=status,listCount=count)) for value,old,notify,previous,objectType,status,count in itertools.product([0,1,2,-1],[0,1,2],[0,1,2],[0x7f000000,88],[6,9,7],[0,1],[0,2])]
placeableOpens=[run(dict(mode='open',hasInventory=has,client=client,primaryId=previous,controlled=controlled,type=objectType,status=status,count=count)) for has,client,previous,controlled,objectType,status,count in itertools.product([0,1,2],[False,True],[0x7f000000,99,88],[False,True],[6,9,7],[0,1],[0,1,-1])]
closes=[run(dict(mode='close',hasInventory=has,count=count,closeGUI=closeGUI,client=client,primaryId=previous,field4=field4)) for has,count,closeGUI,client,previous,field4 in itertools.product([0,1,2],[0,1,2,-1],[0,1,2],[False,True],[99,88],[0,1,2])]
events=[run(dict(mode='event',event=event,caller=caller)) for event,caller in itertools.product([22,23],[0,100,0x7f000000,0x80000077])]
out=m.root/'backups/animations/native-inventory-gui-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,constructors=constructors,owners=owners,opens=opens,placeableOpens=placeableOpens,closes=closes,events=events),indent=2)+'\n');print(json.dumps(dict(output=str(out),constructors=len(constructors),owners=len(owners),opens=len(opens),placeableOpens=len(placeableOpens),closes=len(closes),events=len(events))))
