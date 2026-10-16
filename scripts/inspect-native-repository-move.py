"""Read-only full repository-move action/request, inventory-message subtype9
and cancellation13. Lower canonical lookups/casts, repository mutations,
encumbrance, GUI messages and action allocation are captured boundaries.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actorPtr,itemPtr,bagPtr,placeablePtr,otherPtr,outsidePtr,nodePtr,clientPtr,primaryPtr,alternatePtr,appPtr,messagePtr,basePtr,bagBasePtr,rulesPtr=[m.heap+n*0x1000 for n in range(1,16)]
roles={actorPtr:'actor',itemPtr:'item',bagPtr:'bag',placeablePtr:'placeable',otherPtr:'other',outsidePtr:'outside'}
repoPtrs={key:m.heap+0x20000+n*0x100 for n,key in enumerate(['actor','bag','placeable','other','outside'])}
def canonical(ptr):return ptr-0x48 if ptr in [itemPtr+0x48,bagPtr+0x48] else ptr
def role(ptr):return roles.get(canonical(ptr),'?')
def guiName(ptr):return 'primary' if ptr==primaryPtr else 'alternate'
def objectPtr(id):
 ptr={99:actorPtr,100:itemPtr+0x48,200:bagPtr+0x48,300:placeablePtr,101:otherPtr,102:outsidePtr}.get(id,0)
 if id in c.get('missing',[]):return 0
 return ptr
def hook(u,a,n,_):
 global readOid,readByte,overflowIndex,addIndex,lock
 if a in [m.stop,0x1404b3883]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b590:calls.append(['controlled',y&0xffffffff]);m.finish(c.get('controlled',1));return
 if a==0x1402ae870:m.finish(rulesPtr);return
 if a==0x1402a4130:calls.append(['associates']);m.finish(c.get('associates',1));return
 if a in [0x1404953b0,0x140495620]:calls.append(['dead' if a==0x1404953b0 else 'dying']);m.finish(c.get('dead' if a==0x1404953b0 else 'dying',0));return
 if a in [0x14037cc30,0x14037cbc0]:calls.append(['activityManager' if a==0x14037cc30 else 'actionManager',y&0xffffffff]);m.finish();return
 if a==0x14055b810:calls.append(['message']);m.finish(messagePtr if c.get('message',True) else 0);return
 if a==0x14055f720:calls.append(['client',y&0xffffffff]);m.finish(clientPtr if c.get('client',True) else 0);return
 if a==0x1404ba8c0:calls.append(['dm']);m.finish(c.get('dm',0));return
 if a==0x14055b6c0:calls.append(['item',y&0xffffffff]);m.finish(itemPtr if c.get('item',True) else 0);return
 if a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(objectPtr(y&0xffffffff));return
 if a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(objectPtr(y&0xffffffff));return
 if a in [m.stop+0x10,m.stop+0x18,m.stop+0x20]:
  label={m.stop+0x10:'asCreature',m.stop+0x18:'asItem',m.stop+0x20:'asPlaceable'}[a];calls.append([label,role(x)]);isItem=x in [itemPtr+0x48,bagPtr+0x48];m.finish(canonical(x) if (label=='asItem' and isItem or label=='asCreature' and role(x) in ['actor','other','outside'] or label=='asPlaceable' and x==placeablePtr) and c.get('cast',True) else 0);return
 if a==0x14029ca00:calls.append(['baseInfo',y&0xffffffff]);m.finish(basePtr if y==7 else bagBasePtr);return
 if a==0x140468bd0:calls.append(['contains',next(k for k,v in repoPtrs.items() if v==x),role(y),z&0xffffffff]);m.finish(c.get('contains',1));return
 if a==0x14046ac90 and c['mode']!='cell':
  calls.append(['move',next(k for k,v in repoPtrs.items() if v==x),z&255,w&255]);result=c.get('move',1)
  if result:u.mem_write(y+0x3d8,bytes([z&255,w&255]))
  m.finish(result);return
 if a==0x140392ec0:calls.append(['playerCharacter']);m.finish(c.get('pc',1));return
 if a==0x140465f80:calls.append(['closeItem',role(x),y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x14046b250:calls.append(['remove',next(k for k,v in repoPtrs.items() if v==x),role(y)]);m.finish(c.get('remove',1));return
 if a==0x140464200:
  addIndex+=1;calls.append(['addItem',next(k for k,v in repoPtrs.items() if v==x),z&255,w&255,m.si(rsp+0x28),m.si(rsp+0x30)]);result=c.get('add',1) if addIndex==1 else c.get('restore',1)
  if result:
   if c.get('nullItem',False) and addIndex==1:m.wq(y,0)
   else:
    ptr=m.q(y);u.mem_write(ptr+0x3d8,bytes([c.get('resultX',z&255),c.get('resultY',w&255)]))
  m.finish(result);return
 if a==0x14046c520:calls.append(['setPossessor',role(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.wi(x+0x3c8,y);m.finish();return
 if a==0x1404656a0:calls.append(['page',y&255,z&255]);m.finish(c.get('page',2));return
 if a==0x1404daa40:calls.append(['selectPanelMessage',z&255]);m.finish();return
 if a==0x1404beb40:calls.append(['setPanel',guiName(x),z&255]);u.mem_write(x+0xc,bytes([z&255]));m.finish();return
 if a in [0x1404da8f0,0x1404da990]:calls.append(['moved' if a==0x1404da8f0 else 'cancel',z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1403db1e0:calls.append(['encumbrance',role(x),y&0xffffffff]);m.finish();return
 if a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);m.finish();return
 if a==0x14048cb80:
  args=[];kind=w&0xffffffff;pointer=m.q(rsp+0x28)
  for i in range(12):
   if kind==0:break
   args.append([kind,(u.mem_read(pointer,1)[0] if kind==6 else m.si(pointer))]);kind=m.si(rsp+0x30+i*16)&0xffffffff;pointer=m.q(rsp+0x38+i*16)
  calls.append(['queue',y&0xffffffff,z&65535,args]);m.finish(c.get('queue',1));return
 if a==0x1402d9460:overflowIndex+=1;calls.append(['overflow']);m.finish(int(c.get('overflow',0)==overflowIndex));return
 if a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0));return
 if a==0x140476130:readOid+=1;calls.append(['readObjectId']);m.finish(100 if readOid==1 else c.get('destination',0x7f000000));return
 if a==0x1402d9630:readByte+=1;calls.append(['readByte']);m.finish(c.get('x',4) if readByte==1 else c.get('y',5));return
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(actorPtr if c.get('clientObject',True) else 0);return
 if a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,0 if c.get('nullLookup',False) else objectPtr(y&0xffffffff));m.finish(c.get('status',0));return
 if a==0x1401690b0:m.finish(m.q(y+8));return
 if a==0x140169110:m.wq(y,m.q(m.q(y)));m.finish();return
 if a==0x140465c10:calls.append(['fit',z&255,w&255]);m.finish(c.get('fit',1));return
 if a==0x1404c6af0:calls.append(['integer',y&0xffffffff]);m.finish(c.get('integer',0));return
 if a==0x1404c6b10:calls.append(['objectId',y&0xffffffff]);m.finish(c.get('eventObject',0x7f000000));return
 if a==0x1404998a0:calls.append(['runEventScript',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x14055b850:m.finish(appPtr);return
 if a==0x140380090 and c['mode']=='input':calls.append(['add',role(x),role(y),z&0xffffffff,w&255,m.si(rsp+0x28)&255]);m.finish(c.get('add',1));return
 if a==m.stop+0x28:lock=y&0xffffffff;calls.append(['lock',lock]);m.finish();return
 if a==m.stop+0x30:m.finish(lock);return
 if not any(lo<=a<hi for lo,hi in [(0x140380090,0x140380196),(0x1403c9960,0x1403ca886),(0x140455f50,0x140456d2c),(0x1403870b0,0x1403877dd),(0x14046ac90,0x14046ad7b),(0x1404b3789,0x1404b37ba),(0x1404b3878,0x1404b3883)]):raise AssertionError(f'Uncaptured repository action dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,readOid,readByte,overflowIndex,addIndex,lock
 c=case;calls=[];readOid=readByte=overflowIndex=addIndex=0;lock=c.get('lock',0x7f000000);u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(0x1412df8f8,rulesPtr);m.wq(rulesPtr+0x20,rulesPtr)
 for ptr,key,oid,typ in [(actorPtr,'actor',99,5),(itemPtr+0x48,'item',100,6),(bagPtr+0x48,'bag',200,6),(placeablePtr,'placeable',300,9),(otherPtr,'other',101,5),(outsidePtr,'outside',102,5)]:
  vt=ptr+0x700;m.wq(ptr,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x70,m.stop+0x18);m.wq(vt+0x98,m.stop+0x20);m.wq(vt+0x188,m.stop+0x28);m.wq(vt+0x190,m.stop+0x30);m.wi(ptr+8,oid);u.mem_write(ptr+0xc,bytes([typ]));
 for key,ptr in [('actor',actorPtr),('bag',bagPtr),('placeable',placeablePtr),('other',otherPtr),('outside',outsidePtr)]:m.wq(ptr+({'bag':0x3d0,'placeable':0x540}.get(key,0x958)),0 if key in c.get('nullRepos',[]) else repoPtrs[key])
 m.wi(actorPtr+0xec,c.get('commandable',1));m.wi(actorPtr+0x908,c.get('associateType',0));m.wi(actorPtr+0x8fc,c.get('master',0x7f000000));m.wi(actorPtr+0x1e8,88);m.wi(itemPtr+0x40,7);m.wi(bagPtr+0x40,8);m.wi(itemPtr+0x3c8,c.get('possessor',300));m.wi(bagPtr+0x3c8,c.get('bagOwner',99));m.wi(itemPtr+0x450,c.get('cursed',0));m.wi(itemPtr+0x454,7);u.mem_write(itemPtr+0x3d8,bytes([2,3]));m.wi(basePtr+0x80,c.get('container',0));m.wi(bagBasePtr+0x80,c.get('bagContainer',1))
 m.wq(clientPtr+0x98,primaryPtr);m.wq(clientPtr+0xa0,alternatePtr);m.wi(clientPtr+0x48,88)
 for ptr,owner in [(primaryPtr,c.get('primaryOwner',0x7f000000)),(alternatePtr,c.get('alternateOwner',101))]:m.wi(ptr+0x10,owner);m.wi(ptr+8,c.get('openFlag',1));u.mem_write(ptr+0xc,bytes([c.get('currentPage',0)]))
 m.wi(nodePtr,13);m.wi(nodePtr+0x38,100);m.wi(nodePtr+0x40,c.get('destination',0x7f000000));m.wi(nodePtr+0x48,c.get('x',4));m.wi(nodePtr+0x50,c.get('y',5));m.wi(nodePtr+0x9c,c.get('ready',1));m.wi(actorPtr+0xc4,10);m.wi(actorPtr+0xc8,2345)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);m.wi(rsp+0x28,c.get('y',5));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,messagePtr if c['mode']=='input' else actorPtr);u.reg_write(UC_X86_REG_RDX,clientPtr if c['mode']=='input' else itemPtr if c['mode']=='request' else nodePtr);u.reg_write(UC_X86_REG_R8,9 if c['mode']=='input' else c.get('destination',0x7f000000) if c['mode']=='request' else c.get('head',1));u.reg_write(UC_X86_REG_R9,c.get('x',4))
 if c['mode']=='cell':
  repo=repoPtrs['actor'];linked=m.heap+0x24000;m.wq(repo+0x10,linked);ids=c.get('ids',[200,100]);m.wq(linked,m.heap+0x25000 if ids else 0)
  for n,oid in enumerate(ids):ptr=m.heap+0x25000+n*0x20;m.wq(ptr,ptr+0x20 if n+1<len(ids) else 0);m.wq(ptr+8,ptr+0x10);m.wi(ptr+0x10,oid)
  u.reg_write(UC_X86_REG_RCX,repo);u.reg_write(UC_X86_REG_RDX,0 if c.get('nullItem',False) else itemPtr);u.reg_write(UC_X86_REG_R8,c.get('x',4));u.reg_write(UC_X86_REG_R9,c.get('y',5))
 if c['mode']=='disturb':u.reg_write(UC_X86_REG_RDI,placeablePtr);u.reg_write(UC_X86_REG_RSI,nodePtr);u.reg_write(UC_X86_REG_R15,c.get('caller',99));m.wi(placeablePtr+0x19c,0x7f000000);m.wi(placeablePtr+0x1b0,0x7f000000);m.wi(placeablePtr+0x1b4,7)
 try:u.emu_start({'execute':0x1403c9960,'request':0x140380090,'input':0x140455f50,'clear':0x1403870b0,'cell':0x14046ac90,'disturb':0x1404b3789}[c['mode']],m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x1404b3883]
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,possessor=m.si(itemPtr+0x3c8)&0xffffffff,coords=list(u.mem_read(itemPtr+0x3d8,2)),panels=[u.mem_read(ptr+0xc,1)[0] for ptr in [primaryPtr,alternatePtr]],start=[m.si(actorPtr+0xc4),m.si(actorPtr+0xc8)],lock=lock,disturbed=[m.si(placeablePtr+0x19c)&0xffffffff,m.si(placeablePtr+0x1b0)&0xffffffff,m.si(placeablePtr+0x1b4)])
rows=[run(dict(mode='execute',possessor=source,destination=destination,bagOwner=bagOwner,add=add,container=container)) for source,destination,bagOwner,add,container in itertools.product([99,101,102,200,300,0x7f000000],[99,101,102,200,300,0x7f000000],[99,101,102,0x7f000000],[0,1],[0,1])]
rows += [run(dict(mode='execute',**{key:value})) for key,values in {'client':[False],'message':[False],'item':[False],'dead':[1,2],'dying':[1,2],'contains':[0,2],'nullItem':[True],'page':[0,256],'missing':[[300]],'nullRepos':[['placeable']],'cursed':[1],'master':[101],'dm':[1],'associateType':[3]}.items() for value in values]
rows += [run(dict(mode='execute',possessor=99,destination=200,cursed=cursed,pc=pc,master=master,dm=dm,container=container,add=add,message=message)) for cursed,pc,master,dm,container,add,message in itertools.product([1],[0,1,2],[101,0x7f000000],[0,1],[0,1],[0,1],[False,True])]
requests=[run(dict(mode='request',commandable=command,destination=dest,x=x,y=y,queue=queue)) for command,dest,x,y,queue in itertools.product([0,1,2],[0x7f000000,200],[-1,0,255,256],[3],[0,1,2])]
rows += [run(dict(mode='execute',associateType=3,controlled=controlled,associates=associates)) for controlled,associates in itertools.product([0,1,2],[0,1,2])]
rows += [run(dict(mode='execute',possessor=source,destination=dest,cursed=1,pc=pc,master=master,primaryOwner=owner)) for source,dest,pc,master,owner in itertools.product([99,300],[101,0x7f000000],[0,1,2],[101,0x7f000000],[99,101,0x7f000000])]
rows += [run(dict(mode='execute',**case)) for case in [dict(possessor=99,destination=99,move=0),dict(possessor=99,destination=99,move=2),dict(possessor=99,destination=99,message=False),dict(destination=777),dict(destination=200,nullRepos=['bag']),dict(possessor=99,destination=200,add=2),dict(possessor=300,nullItem=True,message=False)]]
inputs=[run(dict(mode='input',add=add,clientObject=obj,cast=cast,status=status)) for add,obj,cast,status in itertools.product([0,1,2],[False,True],[False,True],[0,1,2])]
inputs += [run(dict(mode='input',**{key:value})) for key,values in {'overflow':[1,2],'underflow':[1,2],'destination':[200,300,0x7f000000]}.items() for value in values]
clears=[run(dict(mode='clear',client=client,message=message,head=head,ready=ready,lock=lock)) for client,message,head,ready,lock in itertools.product([False,True],[False,True],[0,1,2],[0,1],[99,0x7f000000])]
cells=[run(dict(mode='cell',ids=ids,status=status,fit=fit,x=x,nullItem=nullItem,nullLookup=nullLookup)) for ids,status,fit,x,nullItem,nullLookup in itertools.product([[],[200],[200,100],[100,100]],[0,1,2],[0,1,2],[-1,0,256],[False,True],[False,True])]
disturbs=[run(dict(mode='disturb',caller=caller,eventObject=oid,integer=value)) for caller,oid,value in itertools.product([0,99,0x7f000000],[0,100,0x7f000000,0x80000055],[-2147483648,-1,0,1,2,2147483647])]
out=m.root/'backups/animations/native-repository-move-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,requests=requests,inputs=inputs,clears=clears,cells=cells,disturbs=disturbs),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows),requests=len(requests),inputs=len(inputs),clears=len(clears),cells=len(cells),disturbs=len(disturbs))))
