"""Original item action senders and complete server455f50 dispatch branches.

Original scalar/ID writers/readers and validation/control routing execute.
Transport, object/rule lookup, feedback and queued action/cancel boundaries
are captured. No action execution, item mutation, gameplay rules simulation,
live process writes or proprietary asset copies.
"""
import sys,importlib,itertools,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
senders={'equip':('item-equip-request',0x1407c0d70,1),'drop':('item-drop-request',0x1407c0c90,3),'pickup':('item-request-0f60',0x1407c0f60,5),'unequip':('item-request-1100',0x1407c1100,7),'move':('item-request-1030',0x1407c1030,9)}
for name in [v[0]for v in senders.values()]+['inventory-request-handler','client-objectid-writer']:
 d=json.loads((m.root/'backups/animations'/('rea-network-'+name+'.json')).read_text())['structuredContent']['raw_result']['value']['procedure'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
client,actor,associate,item,vt,base,rules,otherGui=[m.heap+n*0x1000 for n in range(10,18)]
cancelNames={0x1404da660:'equip',0x1404da510:'drop',0x1404da850:'pickup',0x1404dab80:'unequip',0x1404da990:'move'}

def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;p=bytearray(u.mem_read(k,size));p[:3]=bytes([112,y&255,z&255]);sent.append(bytes(p));m.finish(1);return
 if a==0x1404ba840:m.finish(0 if c.get('noActor')else actor);return
 if a==m.stop+0x10:m.finish(0 if c.get('badCast')else x);return
 if a==m.stop+0x20:m.finish(0 if c.get('missingItem')else item);return
 if a==0x14055b6c0:m.finish(0 if c.get('missingItem')else item);return
 if a==0x14055b3d0:m.finish(0 if c.get('badAssociate')else associate);return
 if a==0x14029ca00:m.finish(base);return
 if a==0x14055b850:m.finish(rules);return
 if a==0x140296470:m.wq(z,item);m.finish(1 if c.get('missingItem')else 0);return
 if a==0x14055b810:m.finish(w.message);return
 if a in cancelNames:calls.append(dict(kind='cancel',action=cancelNames[a],playerId=y&0xffffffff,itemId=z&0xffffffff,slot=k&0xffffffff if a==0x1404da660 else None,flag=m.si(sp+0x28)&0xffffffff if a==0x1404da660 else k&0xffffffff));m.finish(1);return
 if a==0x14037cbc0:calls.append(dict(kind='manager',value=y&0xffffffff));m.finish();return
 if a==0x1403a2480:calls.append(dict(kind='feedback',value=y&0xffffffff));m.finish();return
 if a==0x1403d54d0:m.finish(0);return
 if a==0x140115890:calls.append(dict(kind='diagnostic'));m.finish();return
 if a==0x14037eb50:calls.append(dict(kind='equip',actor='associate'if x==associate else'self',itemId=m.si(y+8)&0xffffffff,slot=z&0xffffffff,flag0=k&0xffffffff,flag1=m.si(sp+0x28)&0xffffffff,sourceId=m.si(sp+0x30)&0xffffffff));m.finish();return
 if a==0x14037e9d0:calls.append(dict(kind='drop',itemId=y&0xffffffff,position=[m.rf(z+i*4)for i in range(3)]));m.finish(c.get('actionResult',1));return
 if a in [0x14037ff50,0x140380090,0x140380bd0]:
  row=dict(kind={0x14037ff50:'pickup',0x140380090:'move',0x140380bd0:'unequip'}[a],actor='associate'if x==associate else'self',itemId=y&0xffffffff if a==0x14037ff50 else m.si(y+8)&0xffffffff,destinationId=z&0xffffffff,x=k&255,y=m.si(sp+0x28)&255)
  if a==0x140380bd0:row.update(flag0=m.si(sp+0x30)&0xffffffff,flag1=m.si(sp+0x38)&0xffffffff,sourceId=m.si(sp+0x40)&0xffffffff)
  calls.append(row);m.finish(c.get('actionResult',1));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
rows=[]
cases=[dict(format=f,kind=k,itemId=i,destinationId=d,slot=s,x=x,y=y,position=[1.25,-2.5,3.75])for f,k,i,d,s,(x,y)in itertools.product([0,1],senders,[0x80000002,0xffffffff],[0x7f000000,0x80000013],[16,2**31],[(0,0),(255,255)])]
for kind in senders:
 for extra in [dict(missingItem=True),dict(badCast=True),dict(cursed=True,ownerId=88),dict(slotMask=0),dict(actionResult=0),dict(ownerId=19,destinationId=0x80000013),dict(ownerId=19,destinationId=0x80000013,badAssociate=True)]:
  cases.append(dict(format=1,kind=kind,itemId=0x80000002,destinationId=0x7f000000,slot=16,x=255,y=255,position=[0,0,-1],**{k:v for k,v in extra.items()if k!='destinationId'}))
  cases[-1].update(extra)
for c in cases:
 sent=[];calls=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 if c['kind']=='equip':args=[w.message,c['itemId'],c['slot'],c['destinationId']]
 elif c['kind']=='drop':
  args=[w.message,c['itemId'],0,0];u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',c['position'][0]),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',c['position'][1]),'little'));m.wf(sp+0x28,c['position'][2])
 else:args=[w.message,c['itemId'],c['x'],c['y']];m.wi(sp+0x28,c['destinationId'])
 w.call(senders[c['kind']][1],args);assert len(sent)==1;packet=sent[0];u.mem_write(t.inputBase,packet[3:]);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 for ptr in [client,actor,associate,item,vt,base,rules,otherGui]:u.mem_write(ptr,bytes(0x1000))
 for ptr in [actor,associate,item]:m.wq(ptr,vt)
 m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x70,m.stop+0x20);m.wi(actor+8,99);m.wi(associate+8,19);m.wi(client+0x48,17);m.wq(client+0xa0,otherGui);m.wi(otherGui+0x10,19);m.wi(item+8,c['itemId']&0x7fffffff);m.wi(item+0x450,c.get('cursed',0));m.wi(item+0x3c8,c.get('ownerId',99));m.wi(base+4,c.get('slotMask',0xffffffff));m.wq(0x1412df8f8,rules);m.wq(rules+0x20,base)
 result=w.call(0x140455f50,[w.message,client,senders[c['kind']][2],0]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=c,packet=packet.hex(),result=result,calls=list(calls),reader=r.state()))
output=m.root/'backups/animations/native-network-item-actions-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
