"""Original SetCharges/GetUses, Get/SetItemCharges command wrappers,
ClearAction46, and complete item EventHandler(event11). Synthetic typed VM,
canonical object/owner/client/repository lookup and lower ownership,
presentation and destructor boundaries. No live process or install writes.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
item,owner,holder,node,props,app,rules,base,repo,internal,linked,ids,clientList,clients,clientObjects,clientV,vt,command,clock=[m.heap+n*0x2000 for n in range(1,20)]
q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
def propout():return [dict(type=int.from_bytes(u.mem_read(props+i*48,2),'little'),costValue=int.from_bytes(u.mem_read(props+i*48+6,2),'little'),remaining=si(props+i*48+12),usesPerDay=u.mem_read(props+i*48+16,1)[0]) for i in range(len(properties))]
def hook(u,a,n,_):
 global pushed
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286160:wi(y,55);finish(1)
 elif a==0x140286110:wi(y,c.get('value',0));finish(1)
 elif a==0x140286410:pushed=y&0xffffffff;finish(1)
 elif a==0x14055b6c0:calls.append(['item',y&0xffffffff]);finish(item if c.get('present',True) else 0)
 elif a==0x14055b960:finish(app)
 elif a==0x1405570b0:calls.append(['enqueue',si(rsp+0x30),w&0xffffffff,si(rsp+0x28)&0xffffffff,z&0xffffffff,None]);assert q(rsp+0x38)==0;finish()
 elif a==0x14046c440 and kind=='set':calls.append(['setCharges',y&0xffffffff,z&0xffffffff])
 elif a==0x14046cf20:calls.append(['activeChanged',y&0xffffffff]);finish()
 elif a==0x14055b810:finish(0)
 elif a==0x14055f720:finish(0)
 elif a==0x140378f80:calls.append(['removeSpellActions']);finish()
 elif a==0x14039be00:calls.append(['pendingEquipment']);finish()
 elif a==m.stop+0x20:calls.append(['animation',y&65535]);finish()
 elif a==m.stop+0x28:finish(c.get('lock',0x7f000000))
 elif a==m.stop+0x30:calls.append(['setLock',y&0xffffffff]);finish()
 elif a==0x14029ca00:calls.append(['base']);finish(0 if c.get('missingBase') else base)
 elif a==0x14055b8e0:calls.append(['clients']);finish(clientList)
 elif a==0x1404ba840:
  index=(x-clients)//0x100;calls.append(['clientObject',index]);finish(0 if index in c.get('missingClients',[]) else clientObjects+index*0x100)
 elif a==0x140465f80:calls.append(['closeContainer',y&0xffffffff,z&0xffffffff]);finish()
 elif a==0x14055b4c0:
  id=y&0xffffffff;calls.append(['object',id]);finish(owner if id==77 and c.get('owner',True) else holder if id==88 and c.get('holder',False) else 0)
 elif a in [m.stop+0x40,m.stop+0x48,m.stop+0x50,m.stop+0x58]:
  name={m.stop+0x40:'asCreature',m.stop+0x48:'asItem',m.stop+0x50:'asPlaceable',m.stop+0x58:'asStore'}[a];calls.append([name]);finish(0 if name=='asCreature' and x==holder and not c.get('holderCreature',True) else x)
 elif a==0x1403d7490:calls.append(['removeCreatureItem',z&0xffffffff,w&0xffffffff,si(rsp+0x28),si(rsp+0x30)]);finish()
 elif a==0x14055b850:finish(app)
 elif a==0x1401690b0:wi(ids,c.get('repository',[1,55])[(y-linked)//0x20]);finish(ids)
 elif a==0x140169110:
  old=q(y);index=(old-linked)//0x20+1;wq(y,linked+index*0x20 if index<len(c.get('repository',[1,55])) else 0);finish()
 elif a==0x140296470:
  id=y&0xffffffff;calls.append(['object',id]);wq(z,item+0x48 if id==55 and c.get('repoMatches',True) else 0);finish(0)
 elif a==0x14046b250:calls.append(['removeRepositoryItem']);finish()
 elif a==0x1404fb7c0:calls.append(['inStore',y&0xffffffff]);finish(c.get('inStore',1))
 elif a==0x1404fc870:calls.append(['removeStoreItem']);finish()
 elif a==0x14046c520:calls.append(['setPossessor',y&0xffffffff,z&0xffffffff,w&0xffffffff,si(rsp+0x28)]);finish()
 elif a==0x1403901b0:calls.append(['conversation',y&0xffffffff]);finish(clock if c.get('dialog') else 0)
 elif a==0x1403731d0:calls.append(['removeDialogItem',y&0xffffffff]);finish()
 elif a==0x14046b1d0:calls.append(['removeFromArea']);finish()
 elif a==m.stop+0x60:calls.append(['destroy',y&0xffffffff]);finish()
 elif a==0x140c10368:finish(m.heap+0x90000)
 elif a==0x140c10370:finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14046c440,0x14046c516),(0x140469170,0x1404692a9),(0x140542250,0x140542361),(0x1405281d0,0x140528247),(0x1403870b0,0x1403877dd),(0x140466f70,0x140467fdb)]):raise AssertionError(f'Uncaptured item lifecycle dependency {a:x} {kind} {c}')
 # GetNext returns the next ID pointer in RAX and advances the linked cursor.
 if a==0x140169110:
  index=(q(y)-linked)//0x20 if q(y) else -1
  if index>=0:wi(ids,c.get('repository',[1,55])[index]);u.reg_write(UC_X86_REG_RAX,ids)
u.hook_add(UC_HOOK_CODE,hook)
def run(case,ownerKind):
 global c,kind,calls,properties,pushed
 c=case;kind=ownerKind;calls=[];pushed=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));wq(0x1412df970,app);wq(app+8,app);wq(app+8+8,app);wq(0x1412df8f8,rules);wq(rules+0x20,rules)
 properties=c.get('properties',[dict(type=15,costValue=c.get('cost',1),remaining=c.get('remaining',1),usesPerDay=c.get('daily',1))]);wq(item+0x368,props);wi(item+0x370,len(properties))
 for i,p in enumerate(properties):u.mem_write(props+i*48,struct.pack('<HHHH',p['type']&65535,0,0,p['costValue']&65535));wi(props+i*48+12,p['remaining']);u.mem_write(props+i*48+16,bytes([p['usesPerDay']&255]))
 wi(item+0x388,c.get('charges',42));wi(item+0x454,c.get('stackSize',257));wi(item+0x144,c.get('plot',0));wi(item+0x50,55);wi(command+12,99)
 wi(item+0x48+0xf0,c.get('destroyable',1));wi(item+0x3c8,77);wi(item+0x464,88);wi(base+0x80,c.get('container',0));wq(item,vt);wq(vt,m.stop+0x60)
 for off,addr in [(0x60,m.stop+0x40),(0x70,m.stop+0x48),(0x98,m.stop+0x50),(0xd0,m.stop+0x58),(0x100,m.stop+0x20),(0x190,m.stop+0x28),(0x188,m.stop+0x30)]:wq(vt+off,addr)
 wq(owner,vt);wq(holder,vt);u.mem_write(owner+12,bytes([c.get('type',5)]));wq(owner+0x3d0,repo);wq(owner+0x540,repo);wi(owner+0x4f8,c.get('hasInventory',1));wq(repo+0x10,internal);wq(internal,linked if c.get('repository',[1,55]) else 0)
 wq(clientList,clientV);wi(clientList+8,len(c.get('openIds',[])))
 for i,id in enumerate(c.get('openIds',[])):
  client=clients+i*0x100;wq(clientV+i*8,client);wi(clientObjects+i*0x100+8,100+i);wq(client+0x98,client+0x40);wq(client+0x40+0x18,client+0x60);wi(client+0x60,id)
 wq(command,vt);wi(node,46);wi(node+0x9c,c.get('interruptible',1));wi(command+0x828,41);wi(command+0x73c,42);wi(command+0x740,43);wi(command+0xc4,44);wi(command+0xc8,45);wi(command+0x81c,46)
 start={'charges':0x14046c440,'uses':0x140469170,'set':0x140542250,'get':0x1405281d0,'clear':0x1403870b0,'destroy':0x140466f70}[kind]
 x,y,z=(item,c.get('value',0),c.get('update',1)) if kind=='charges' else (item,c.get('index',0),0) if kind=='uses' else (command,node,c.get('head',0)) if kind=='clear' else (item+0x48,11,0) if kind=='destroy' else (command,0,0)
 rsp=m.stack+0x1fc08;wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[x,y,z,0]):u.reg_write(r,v&0xffffffffffffffff)
 u.emu_start(start,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,pushed=pushed,calls=calls,properties=propout(),charges=si(item+0x388),clearFields=[si(command+off) for off in [0x828,0x73c,0x740,0xc4,0xc8,0x81c]])
chargecases=[dict(value=v,update=update,properties=[dict(type=typ,costValue=cost,remaining=remaining,usesPerDay=255) for typ,cost,remaining in itertools.product([1,15],range(1,15),[0,-1])]) for v,update in itertools.product([-1,0,1,2,3,4,5,6,249,250,251,0x7fffffff],[0,1,-1])]
usecases=[dict(cost=cost,remaining=r,daily=d,charges=ch,stackSize=stack,index=index) for cost,r,d,ch,stack,index in itertools.product(range(1,15),[0,1,-1],[0,1,255],[-1,0,1,5,250],[0,1,256,257],[0,256])]
setcases=[dict(value=v,plot=plot,present=present) for v,plot,present in itertools.product([-1,0,1,250,251],[0,1,-1],[False,True])]
clearcases=[dict(interruptible=i,head=head,lock=lock) for i,head,lock in itertools.product([0,1,-1],[0,1,2],[0x7f000000,99])]
destroycases=[dict(type=typ,destroyable=d,container=container,hasInventory=hi,inStore=store,repository=repo,repoMatches=match,openIds=[55,66,55],missingClients=[2]) for typ,d,container,hi,store,repo,match in itertools.product([5,6,9,14,10],[0,1],[0,1],[0,1],[0,1],[[],[1,55],[55,1]],[False,True])]
destroycases += [dict(owner=False,holder=holder,holderCreature=creature,dialog=dialog) for holder,creature,dialog in itertools.product([False,True],[False,True],[False,True])]
out=m.root/'backups/animations/native-item-cast-lifecycle-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,charges=[run(c,'charges') for c in chargecases],uses=[run(c,'uses') for c in usecases],set=[run(c,'set') for c in setcases],get=[run(c,'get') for c in [dict(present=False),dict(charges=-1),dict(charges=999)]],clear=[run(c,'clear') for c in clearcases],destroy=[run(c,'destroy') for c in destroycases]))+'\n');print(json.dumps(dict(charges=len(chargecases),uses=len(usecases),set=len(setcases),clear=len(clearcases),destroy=len(destroycases),output=str(out))))
