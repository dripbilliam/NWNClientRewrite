"""Original quick-equip sender7c0e20 and complete server455f50 subtype11.

Item/base/inventory/repository lookups are explicit lower boundaries. Original
slot scans, pair handling and equip/unequip routing execute unchanged. Queued
actions and transport are captured, not executed. No live process writes.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
a=importlib.import_module('inspect-native-network-item-actions');t=a.t;w=a.w;r=a.r;m=a.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(a.hook_handle)
d=json.loads((m.root/'backups/animations/rea-network-item-toggle-request.json').read_text())['structuredContent']['raw_result']['value']['procedure'];a.ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
second,base2,inventory=[m.heap+n*0x1000 for n in [18,19,20]]
def hook(u,addr,n,data):
 x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if addr==0x14055b6c0:m.finish(0 if y==0x7f000000 or y==2 and c.get('missing')else a.item if y==2 else second);return
 if addr==0x14029ca00:m.finish(a.base if y==0 else base2);return
 if addr==0x140462b40:m.finish(int((c['slot']if y==a.item else c['secondSlot'])!=0));return
 if addr==0x140462c10:m.finish(c['slot']if y==a.item else c['secondSlot']);return
 if addr==0x140468bd0:m.finish(int(not c.get('absent')));return
 if addr==0x140462bd0:m.finish(0);return
 a.hook(u,addr,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
cases=[dict(format=f,slot=s,mask=mask,secondId=other,secondSlot=otherSlot,wield=wield)for f,s,mask,other,otherSlot,wield in itertools.product([0,1],[0,16,32,128],[0,16,48,384],[0x7f000000,0x80000003],[0,32],[0,1])]
cases.extend(dict(format=1,slot=0,mask=16,secondId=0x7f000000,secondSlot=0,wield=1,**extra)for extra in [dict(missing=True),dict(absent=True)])
for c in cases:
 a.c=c;a.sent=[];a.calls=[];t.reset(dict(format=c['format']));w.call(0x1407c0e20,[w.message,0x80000002,c['secondId'],0]);assert len(a.sent)==1;packet=a.sent[0]
 u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 for ptr in [a.client,a.actor,a.item,a.vt,a.base,a.rules,a.otherGui,second,base2,inventory]:u.mem_write(ptr,bytes(0x1000))
 m.wq(a.actor,a.vt);m.wq(a.vt+0x60,m.stop+0x10);m.wq(a.actor+0x950,inventory);m.wi(a.actor+8,99);m.wi(a.item+8,2);m.wi(a.item+0x50,2);m.wi(second+8,3);m.wi(second+0x50,3);m.wi(second+0x40,1);m.wi(a.base+4,c['mask']);m.wi(base2+4,48);u.mem_write(a.base+9,bytes([c['wield']]));u.mem_write(base2+9,b'\1');m.wq(0x1412df8f8,a.rules);m.wq(a.rules+0x20,a.base)
 result=w.call(0x140455f50,[w.message,a.client,11,0]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 if c.get('missing')or c.get('absent'):assert a.calls==[]
 else:
  assert all(v['kind']in ['equip','unequip']for v in a.calls)
  for v in a.calls:assert v['flag0']==1 and v['flag1']==0 and v['sourceId']==0x7f000000
 rows.append(dict(case=c,packet=packet.hex(),result=result,calls=list(a.calls),reader=r.state()))
output=m.root/'backups/animations/native-network-item-toggle-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
