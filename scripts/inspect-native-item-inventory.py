"""Read-only full original item OpenInventory/CloseInventory and event10.
Base rules, clients, GUI setters, old-container closure, allocation and
scheduler enqueue are captured boundaries. No pickup or packet codec claim.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
itemPtr,clientPtr,primaryPtr,alternatePtr,basePtr,oldPtr,vtPtr,controlledPtr,eventPtr,appPtr=[m.heap+n*0x1000 for n in range(1,11)]
def guiName(ptr):return 'primary' if ptr in [primaryPtr,primaryPtr+0x200] else 'alternate'
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14029ca00:calls.append(['baseInfo',y&0xffffffff]);m.finish(basePtr);return
 if a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(clientPtr if c.get('client',True) else 0);return
 if a in [0x14055b810,0x14055b850,0x14055b960]:m.finish(appPtr);return
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(controlledPtr if c.get('controlled',True) else 0);return
 if a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,oldPtr);m.finish(c.get('status',0));return
 if a in [m.stop+0x10,m.stop+0x18]:calls.append(['asItem' if a==m.stop+0x10 else 'asPlaceable']);m.finish(oldPtr if c.get('cast',True) else 0);return
 if a==0x140465f80 and c['mode']=='open' or a==0x1404b1e10:calls.append(['closeItem' if a==0x140465f80 else 'closePlaceable',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1404be930:calls.append(['setOwner',guiName(x),z&0xffffffff,w&0xffffffff]);m.wi(x,z);m.wi(x+4,w);u.mem_write(x+8,b'\0');m.finish();return
 if a==0x1404be9a0:calls.append(['setOpen',guiName(x),y&0xffffffff,z&0xffffffff]);m.wi(x+8,y);m.finish();return
 if a==0x1404ccd90:calls.append(['status',z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1404d9c30:calls.append(['gui',z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x140c10324:m.finish(eventPtr);return
 if a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x);return
 if a==0x1405570b0:calls.append(['event',w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish();return
 if not any(lo<=a<hi for lo,hi in [(0x14046ad80,0x14046afa5),(0x140465f80,0x140466136),(0x140466f70,0x140467fdb),(0x140495130,0x14049514c),(0x140420350,0x140420358)]):raise AssertionError(f'Uncaptured item inventory dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(0x1412df8f8,appPtr);m.wq(appPtr+0x20,appPtr)
 m.wi(itemPtr+0x40,7);m.wi(itemPtr+0x50,100);m.wi(itemPtr+0x3c8,c.get('possessor',99));m.wi(itemPtr+0x364,c.get('count',0));m.wi(basePtr+0x80,c.get('container',1));m.wq(clientPtr+0x98,primaryPtr);m.wq(clientPtr+0xa0,alternatePtr);m.wi(controlledPtr+8,99)
 for ptr,label in [(primaryPtr,'primary'),(alternatePtr,'alternate')]:
  m.wq(ptr+0x18,ptr+0x200);m.wi(ptr+8,c.get('openFlag',0));m.wi(ptr+0x10,99 if label=='primary' else c.get('alternateOwner',101));m.wi(ptr+0x200,c.get(label+'Id',0x7f000000));m.wi(ptr+0x204,c.get('field4',1));u.mem_write(ptr+0x208,b'\x07')
 m.wq(oldPtr,vtPtr);m.wq(vtPtr+0x70,m.stop+0x10);m.wq(vtPtr+0x98,m.stop+0x18);u.mem_write(oldPtr+0xc,bytes([c.get('type',9)]))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,itemPtr if c['mode']!='event' else itemPtr+0x48);u.reg_write(UC_X86_REG_RDX,99 if c['mode']!='event' else 10);u.reg_write(UC_X86_REG_R8,c.get('closeGUI',1) if c['mode']!='event' else 99);u.reg_write(UC_X86_REG_R9,0 if c['mode']!='event' else eventPtr);u.mem_write(eventPtr,bytes([c.get('event',22),0])+bytes(0x46))
 try:u.emu_start({'open':0x14046ad80,'close':0x140465f80,'event':0x140466f70}[c['mode']],m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,count=m.si(itemPtr+0x364),guis=[dict(field8=m.si(ptr+8),id=m.si(ptr+0x200)&0xffffffff,field4=m.si(ptr+0x204),field8owner=u.mem_read(ptr+0x208,1)[0]) for ptr in [primaryPtr,alternatePtr]])
opens=[run(dict(mode='open',container=container,client=client,possessor=possessor,primaryId=primaryId,alternateId=alternateId,count=count,openFlag=flag)) for container,client,possessor,primaryId,alternateId,count,flag in itertools.product([0,1,2],[False,True],[99,101,102],[100,200,0x7f000000],[100,200,0x7f000000],[0,1,-1],[0,2])]
opens += [run(dict(mode='open',primaryId=200,**{key:value})) for key,values in {'status':[1,2],'controlled':[False],'cast':[False],'type':[6,5,14]}.items() for value in values]
closes=[run(dict(mode='close',container=container,client=client,primaryId=primaryId,alternateId=alternateId,count=count,field4=flag,closeGUI=closeGUI)) for container,client,primaryId,alternateId,count,flag,closeGUI in itertools.product([0,1,2],[False,True],[100,200],[100,200],[0,1,2,-1],[0,1],[0,1,2])]
events=[run(dict(mode='event',event=event)) for event in [0,22,23,25,42,255]]
hps=[]
for base,temp,flag,maximum in itertools.product([0,1,32767,32768,65535],[0,1,32767,65535],[0,1,2,-1],[False,True]):
 calls=[];rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);m.wi(itemPtr+0xe0,base);m.wi(itemPtr+0xe4,base);m.wi(itemPtr+0xe8,temp);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,itemPtr);u.reg_write(UC_X86_REG_RDX,flag&0xffffffff);u.emu_start(0x140420350 if maximum else 0x140495130,m.stop,count=20);value=u.reg_read(UC_X86_REG_RAX)&65535;hps.append(dict(base=base,temp=temp,flag=flag,maximum=maximum,result=value if value<32768 else value-65536))
out=m.root/'backups/animations/native-item-inventory-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,opens=opens,closes=closes,events=events,hps=hps),indent=2)+'\n');print(json.dumps(dict(output=str(out),opens=len(opens),closes=len(closes),events=len(events),hps=len(hps))))
