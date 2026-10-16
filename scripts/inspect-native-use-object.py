"""Read-only full AddUseObjectAction, AIActionUseObject (Tracy disabled),
ClearAction40 and DestroyEquippedItems. Canonical lookup/casts, life/range,
movement/actions, reputation/lock, GUI, feedback, equipment, timer and event
helpers are captured boundaries; this does not prove their lower owners.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actorPtr,targetPtr,bagPtr,linkedPtr,nodePtr,appPtr,statsPtr,clientPtr,guiPtr,altGuiPtr,vtActorPtr,vtTargetPtr,vtBagPtr,vtLinkedPtr,feedbackPtr,rulesPtr,basePtr,equipPtr=[m.heap+n*0x1000 for n in range(1,19)]
ptrNames={actorPtr:'actor',targetPtr:'target',bagPtr:'bag',linkedPtr:'linked'}
ranges=[(0x1404a9790,0x1404aa8c3),(0x1404ab5b0,0x1404ab6a1),(0x1403870b0,0x1403877dd),(0x14038a7a0,0x14038a804),(0x1404b33f9,0x1404b3435),(0x1404b3878,0x1404b3883)]
def hook(u,a,n,_):
 global rangeIndex,lock,feedbackObject
 if a in [m.stop,0x1404b3883]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 role=ptrNames.get(x,'?')
 if a==0x14055b850:m.finish(appPtr);return
 if a==0x140296470:
  id=y&0xffffffff;calls.append(['lookup',id]);m.wq(z,targetPtr if id==100 else linkedPtr);m.finish(c['lookupStatus'] if id==100 else c.get('linkedStatus',0));return
 if a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(bagPtr if c['bagPresent'] else 0);return
 if a==m.stop+0x100:calls.append(['asObject',role]);m.finish(x if c.get('asObject',True) else 0);return
 if a==m.stop+0x108:
  calls.append(['asCreature',role]);valid=c['actorCreature'] if x==actorPtr else c.get('linkedCreature',True) if x==linkedPtr else c['type']==5 if x==targetPtr else False;m.finish(x if valid else 0);return
 if a==m.stop+0x110:calls.append(['asPlaceable',role]);m.finish(x);return
 if a==m.stop+0x118:calls.append(['asItem',role]);m.finish(x);return
 if a in [0x1404953b0,0x140495620]:calls.append(['dead' if a==0x1404953b0 else 'dying',role]);m.finish(c['dead'] if a==0x1404953b0 else c['dying']);return
 if a==0x140494e80:calls.append(['area',role]);m.finish(appPtr if c['area'] else 0);return
 if a==0x140391310:
  values=c.get('ranges',[c['inRange']]);value=values[min(rangeIndex,len(values)-1)];rangeIndex+=1;calls.append(['inRange',y&0xffffffff,m.xmm(UC_X86_REG_XMM2),w&0xffffffff]);m.finish(value);return
 if a==0x140396480:calls.append(['range',y&0xffffffff]);[m.wf(z+i*4,value) for i,value in enumerate([9,8,7])];m.wf(w,c['range']);m.finish(c.get('rangeResult',1));return
 if a==0x14037cc30:calls.append(['manage',role,y&0xffffffff]);m.finish();return
 if a==0x1403a2650:calls.append(['activity',role,y&0xffffffff,z&0xffffffff]);m.finish();return
 if a in [0x14048cb80,0x14048d3f0]:
  args=[];types=[w&0xffffffff]+[m.si(rsp+0x30+i*16) for i in range(11)];pointers=[m.q(rsp+0x28+i*16) for i in range(12)]
  for kind,ptr in zip(types,pointers):
   if kind==0:break
   args.append([kind,m.si(ptr)])
  calls.append(['front' if a==0x14048d3f0 else 'back',y&0xffffffff,z&65535,args]);m.finish(c.get('addResult',1));return
 if a==0x14037fae0:
  calls.append(['move',y&65535,[m.rf(z+i*4) for i in range(3)],w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.rf(rsp+0x38),m.rf(rsp+0x40),*[m.si(rsp+off) for off in [0x48,0x50,0x58,0x60,0x68,0x70]]]);m.finish(1);return
 if a==m.stop+0x120:lock=y&0xffffffff;calls.append(['lock',lock]);m.finish();return
 if a==m.stop+0x128:m.finish(lock);return
 if a==m.stop+0x130:calls.append(['animation',role,y&0xffffffff]);m.finish();return
 if a==0x1404abcd0:calls.append(['reputation',role,y&0xffffffff,w&0xffffffff]);m.wi(z,777);m.finish(c['reputation']);return
 if a==0x1403d54d0:calls.append(['possessed',role]);m.finish(c['possessed']);return
 if a==0x1402ae870:m.finish(rulesPtr);return
 if a==0x1402a4130:calls.append(['associates']);m.finish(c['associates']);return
 if a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(clientPtr if c['client'] else 0);return
 if a==0x140392ec0:calls.append(['player',role]);m.finish(c['pc']);return
 if a==0x1404b3db0:calls.append(['count',role,y&0xffffffff]);m.finish(c['itemCount']);return
 if a==0x14038d230:calls.append(['evaluateLock',ptrNames[y],z&0xffffffff]);m.finish(c['evaluate']);return
 if a==0x140c10324:m.finish(feedbackPtr);return
 if a==0x1402da770:feedbackObject=z&0xffffffff;m.finish();return
 if a==0x1403a2480:calls.append(['feedback',role,y&0xffffffff,[feedbackObject] if z else None]);m.finish();return
 if a==0x1403d4b90:calls.append(['failedInform',role]);m.finish();return
 if a in [0x1404b6720,0x1404b1e10,0x14046ad80,0x140465f80]:
  label={0x1404b6720:'openPlaceable',0x1404b1e10:'closePlaceable',0x14046ad80:'openItem',0x140465f80:'closeItem'}[a];calls.append([label,role,y&0xffffffff]+([z&0xffffffff] if label.startswith('close') else []));m.finish();return
 if a==0x14055b810:
  if c['mode']=='clear':calls.append(['message'])
  m.finish(appPtr if c.get('message',True) else 0);return
 if a==0x14055f720:m.finish(0);return
 if a==0x140462bd0:
  slot=y&0xffffffff;calls.append(['equipment',slot]);index=slot.bit_length()-1;value=c['equipment'][index] if c['mode']=='destroyEquipment' else c.get('right') if slot==16 else c.get('left');m.finish(0 if value is None else m.heap+0x20000+index*0x100);return
 if a==m.stop+0x138:index=(x-m.heap-0x20000)//0x100;calls.append(['destroy',index,y&0xffffffff]);m.finish();return
 if a==0x1404ccec0:calls.append(['corpseMessage',y&0xffffffff,z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x14038a7a0 and c['mode']!='destroyEquipment':calls.append(['destroyEquipment',role]);m.finish();return
 if a==0x14029ca00:calls.append(['baseInfo',y&0xffffffff]);m.finish(basePtr);return
 if a==0x14055b960:m.finish(appPtr);return
 if a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x);return
 if a==0x1404998a0:calls.append(['script',role,y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1405570b0:calls.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish();return
 if a==0x14016dd40:calls.append(['timer',y&0xffffffff]);m.finish(c['now']);return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured use-object dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,rangeIndex,lock,feedbackObject
 c=case;calls=[];rangeIndex=0;lock=c.get('lock',0x7f000000);feedbackObject=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(0x1404a9e32+0xe35a86,appPtr);m.wq(appPtr+0x10,appPtr);m.wq(0x1412df8f8,rulesPtr);m.wq(rulesPtr+0x20,rulesPtr);m.wi(basePtr+0x80,c.get('container',0))
 for ptr,vt in [(actorPtr,vtActorPtr),(targetPtr,vtTargetPtr),(bagPtr,vtBagPtr),(linkedPtr,vtLinkedPtr)]:
  m.wq(ptr,vt)
  for off,addr in [(0x20,0x100),(0x60,0x108),(0x98,0x110),(0x70,0x118),(0x188,0x120),(0x190,0x128),(0x100,0x130)]:m.wq(vt+off,m.stop+addr)
  m.wi(ptr+0xa0,88);[m.wf(ptr+0xa4+i*4,value) for i,value in enumerate([1,2,3] if ptr!=bagPtr else [2,3,4])]
  for field,name in [(0x264,'usable'),(0x3b4,'trapped'),(0x3d4,'active'),(0x3d8,'trapFaction'),(0x4f8,'hasInventory'),(0x378,'locked'),(0x510,'sourceId')]:m.wi(ptr+field,c.get(name,0))
 m.wi(actorPtr+8,99);m.wi(targetPtr+8,100);m.wi(bagPtr+8,200);m.wi(linkedPtr+8,300);m.wi(actorPtr+0xec,c.get('commandable',1));m.wi(actorPtr+0xc4,10);m.wi(actorPtr+0xc8,2345);m.wq(actorPtr+0xad0,statsPtr);m.wi(statsPtr+0xc4,c.get('actorFaction',1));m.wi(targetPtr+0x4e8,c.get('lootable',0));m.wi(targetPtr+0x4f0,200);m.wi(targetPtr+0xf8,1);u.mem_write(targetPtr+12,bytes([c.get('type',9)]));u.mem_write(bagPtr+12,b'\x09');m.wi(targetPtr+0x40,7);m.wi(targetPtr+0x3c8,c.get('possessor',99))
 m.wq(clientPtr+0x98,guiPtr);m.wq(clientPtr+0xa0,altGuiPtr);m.wq(guiPtr+0x18,guiPtr+0x100);m.wq(altGuiPtr+0x18,altGuiPtr+0x100);m.wi(guiPtr+0x100,c.get('primaryId',0x7f000000));m.wi(altGuiPtr+0x100,c.get('alternateId',0x7f000000));m.wq(linkedPtr+0x950,equipPtr if c.get('hasEquipment',True) else 0);m.wq(actorPtr+0x950,equipPtr if c.get('hasEquipment',True) else 0)
 for index,value in enumerate(c.get('equipment',[None]*18) if c['mode']=='destroyEquipment' else [None]*4+[c.get('right'),c.get('left')]+[None]*12):
  ptr=m.heap+0x20000+index*0x100;m.wq(ptr,vtTargetPtr);m.wq(vtTargetPtr,m.stop+0x138);m.wi(ptr+0x448,value or 0)
 m.wi(nodePtr,40);m.wi(nodePtr+0x38,c.get('targetId',100));m.wi(nodePtr+0x40,c.get('deadline',0));m.wi(nodePtr+0x48,c.get('phase',0));m.wi(nodePtr+0x9c,c.get('ready',1));u.mem_write(nodePtr+0x98,struct.pack('<H',c.get('group',66)&65535))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x800,bytes(0x900));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actorPtr);u.reg_write(UC_X86_REG_RDX,c.get('targetId',100) if c['mode']=='request' else nodePtr);u.reg_write(UC_X86_REG_R8,c.get('head',0))
 if c['mode']=='scriptEvent':u.reg_write(UC_X86_REG_RDI,actorPtr);u.reg_write(UC_X86_REG_R15,c['caller']);m.wi(actorPtr+0x528,0x7f000000);m.wi(actorPtr+0x52c,0x7f000000)
 start={'request':0x1404ab5b0,'execute':0x1404a9790,'clear':0x1403870b0,'destroyEquipment':0x14038a7a0,'scriptEvent':0x1404b33f9 if c.get('event',0)&65535==25 else 0x1404b3417}[c['mode']]
 try:u.emu_start(start,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x1404b3883]
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,phase=m.si(nodePtr+0x48),deadline=m.si(nodePtr+0x40)&0xffffffff,lootable=m.si(targetPtr+0x4e8),selectable=m.si(targetPtr+0xf8),lock=lock,start=[m.si(actorPtr+0xc4),m.si(actorPtr+0xc8)],eventFields=[m.si(actorPtr+offset)&0xffffffff for offset in [0x528,0x52c]])
default=dict(mode='execute',actorCreature=True,type=9,lookupStatus=0,dead=0,dying=0,area=True,inRange=1,range=1.25,bagPresent=False,usable=1,trapped=0,active=1,trapFaction=2,actorFaction=1,reputation=50,hasInventory=1,possessed=0,associates=0,client=True,pc=1,itemCount=1,locked=0,evaluate=1,sourceId=0x7f000000,now=1234)
rows=[]
for phase,now,deadline in itertools.product([1,2,-1],[0,499,500,501,0xffffffff],[0,500,0xfffffff0]):rows.append(run(default|dict(phase=phase,now=now,deadline=deadline)))
for status,cast in itertools.product([0,1,2],[False,True]):rows.append(run(default|dict(lookupStatus=status,asObject=cast)))
for objectType,actor,dead,dying,area,inRange in itertools.product([5,6,9,10],[False,True],[0,1,2],[0,1,2],[False,True],[0,1,2]):rows.append(run(default|dict(type=objectType,actorCreature=actor,dead=dead,dying=dying,area=area,inRange=inRange)))
for lootable,dead,dying,bag,values,actor in itertools.product([0,1,2],[0,1],[0,1],[False,True],[[0],[1],[0,1]],[False,True]):rows.append(run(default|dict(type=5,lootable=lootable,dead=dead,dying=dying,bagPresent=bag,ranges=values,actorCreature=actor)))
for usable,trapped,active,rep,same,actor in itertools.product([0,1,2],[0,1],[0,1],[0,89,90,100],[False,True],[False,True]):rows.append(run(default|dict(usable=usable,trapped=trapped,active=active,reputation=rep,actorFaction=2 if same else 1,actorCreature=actor)))
for inventory,possessed,associates,actor in itertools.product([0,1,2],[0,1,2],[0,1,2],[False,True]):rows.append(run(default|dict(hasInventory=inventory,possessed=possessed,associates=associates,actorCreature=actor)))
for client,inv,itemCount,source,pc,locked,evaluate in itertools.product([False,True],[0x7f000000,100],[0,1],[0x7f000000,300],[0,1,2],[0,1],[0,1]):rows.append(run(default|dict(client=client,primaryId=inv,itemCount=itemCount,sourceId=source,pc=pc,locked=locked,evaluate=evaluate)))
for hasEquipment,right,left,status,linked in itertools.product([False,True],[None,0,1],[None,0,1],[0,1],[False,True]):rows.append(run(default|dict(sourceId=300,hasEquipment=hasEquipment,right=right,left=left,linkedStatus=status,linkedCreature=linked)))
for container,client,possessor,primary,alternate in itertools.product([0,1,2],[False,True],[99,777],[0x7f000000,100],[0x7f000000,100]):rows.append(run(default|dict(type=6,container=container,client=client,possessor=possessor,primaryId=primary,alternateId=alternate)))
for group,rangeValue,rangeResult,now,inRange in itertools.product([0,65534,65535],[0,1.25],[0,1],[0,0xfffffff0],[0,1]):rows.append(run(default|dict(group=group,range=rangeValue,rangeResult=rangeResult,now=now,inRange=inRange)))
requests=[run(default|dict(mode='request',commandable=commandable,targetId=id,addResult=addResult)) for commandable,id,addResult in itertools.product([0,1,2,-1],[0,100,0x7f000000,0x80000077],[0,1,2])]
clears=[run(default|dict(mode='clear',ready=ready,head=head,lock=lock,message=message)) for ready,head,lock,message in itertools.product([0,1,2],[0,1,2],[100,0x7f000000],[False,True])]
equipment=[run(default|dict(mode='destroyEquipment',hasEquipment=present,equipment=values)) for present,values in itertools.product([False,True],[[None]*18,[0]*18,[1]*18,[-1]*18,[None,0,1,2]*4+[0,1],[1 if n%2 else 0 for n in range(18)]])]
events=[run(default|dict(mode='scriptEvent',event=event,caller=caller,usable=usable)) for event,caller,usable in itertools.product([25,42,65561,65578],[0,99,0x7f000000,0x80000077],[0,1,2])]
out=m.root/'backups/animations/native-use-object-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,requests=requests,clears=clears,equipment=equipment,events=events),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows),requests=len(requests),clears=len(clears),equipment=len(equipment),events=len(events))))
