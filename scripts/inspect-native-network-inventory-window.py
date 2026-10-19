"""Original inventory window/panel senders and complete server451db0 handler.

Scalar/OBJECT_ID writers, readers and server routing execute unchanged.
Transport, controlled-object lookup, SetOpen, SetOwner and SetPanel are
captured lower boundaries. Does not evaluate inventories or change a live
game/server. Fixed synthetic memory is independent of installed game assets.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['network-client-inventory-window-request','network-client-inventory-panel-request','network-inventory-gui-request-handler','network-client-objectid-writer']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['raw_result']['value']['procedure']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
client,actor,selfGui,otherGui=[m.heap+n*0x1000 for n in [10,11,12,13]]

def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;p=bytearray(u.mem_read(k,size));p[:3]=bytes([112,y&255,z&255]);sent.append(bytes(p));m.finish(1);return
 if a==0x1404ba840:m.finish(0 if current.get('noActor')else actor);return
 if a in [0x1404be9a0,0x1404beab0,0x1404beb40]:
  label={0x1404be9a0:'open',0x1404beab0:'owner',0x1404beb40:'panel'}[a]
  calls.append(dict(method=label,gui='self'if x==selfGui else'other',value=(z&255)if label=='panel'else y&0xffffffff,flag=z&0xffffffff if label=='open'else None));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
cases=[dict(kind='window',format=f,open=o,ownerId=i)for f,o,i in itertools.product([0,1],[0,1],[0xffffffff,0x7f000000,0x80000002,42])]
cases.extend(dict(kind='panel',format=f,panel=p,self=s)for f,p,s in itertools.product([0,1],[0,1,9,255],[0,1]))
cases.extend(dict(kind='window',format=1,open=1,ownerId=42,**extra)for extra in [dict(noActor=True),dict(noPlayer=True),dict(truncate=True)])
for current in cases:
 sent=[];calls=[];t.reset(dict(format=current['format']));window=current['kind']=='window'
 w.call(0x1407be110 if window else 0x1407be060,[w.message,current['open']if window else current['panel'],current['ownerId']if window else current['self']]);assert len(sent)==1;packet=sent[0]
 payload=packet[3:];payload=payload[:-1]if current.get('truncate')else payload
 u.mem_write(t.inputBase,payload+bytes([0xa5])*128);m.wi(m.stack+0x1fe08+0x28,1);setup=w.call(0x1402da7b0,[w.message,t.inputBase,len(payload),0xffffffff])
 if setup!=1:
  assert current.get('truncate');rows.append(dict(case=current,packet=packet.hex(),setup=setup,result=0,calls=[]));continue
 u.mem_write(client,bytes(0x1000));u.mem_write(actor,bytes(0x1000));m.wi(actor+8,0x7fffffff);m.wq(client+0x98,selfGui);m.wq(client+0xa0,otherGui)
 result=w.call(0x140451db0,[w.message,0 if current.get('noPlayer')else client,1 if window else 2,0])
 if current.get('truncate'):assert result==0 and calls==[]
 elif current.get('noActor')or current.get('noPlayer'):assert result==1 and calls==[]
 elif window:
  own=(current['ownerId']&0x7fffffff)in [0x7fffffff,0x7f000000];assert calls[0]==dict(method='open',gui='self'if own else'other',value=current['open'],flag=1)
  assert len(calls)==(1 if own else 2)
  if not own:assert calls[1]['value']==(current['ownerId']&0x7fffffff if current['open']else 0x7f000000)
 else:assert calls==[dict(method='panel',gui='self'if current['self']else'other',value=current['panel'],flag=None)]
 rows.append(dict(case=current,packet=packet.hex(),result=result,calls=list(calls),reader=r.state()))
output=m.root/'backups/animations/native-network-inventory-window-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
