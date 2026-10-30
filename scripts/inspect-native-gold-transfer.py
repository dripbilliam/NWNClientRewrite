"""Read-only unchanged gold sender1407bdc70 and scalar/client-ID writers.
Only transport is captured. No live process, rules or balance is modified.
"""
import sys,importlib,itertools,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
e=json.loads((m.root/'backups/animations/rea-inventory-frame-interaction-v1.json').read_text())
f=next(v for v in e['functions'] if v['key']=='inventory_gold_sender')
ranges=[(int(v['start'],16),int(v['end'],16)+1)for v in f['procedure']['body']['ranges']]
d=json.loads((m.root/'backups/animations/rea-network-client-objectid-writer.json').read_text())['structuredContent']['raw_result']['value']['procedure']
ranges.extend((int(v['start'],16),int(v['end'],16)+1)for v in d['body']['ranges'])
def hook(u,a,n,data):
 if a==0x1407c25c0:
  y,z,p=[u.reg_read(reg)for reg in [UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];size=m.si(u.reg_read(UC_X86_REG_RSP)+0x28)&0xffffffff
  packet=bytearray(u.mem_read(p,size));packet[:3]=bytes([112,y&255,z&255]);sent.append(bytes(packet));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
if __name__=='__main__':
 rows=[]
 for fmt,target,amount,placement,(x,y)in itertools.product([0,1],[0x7f000000,0x80000002,0xffffffff],[1,27,999999999,-1], [0,1],[(0,0),(254,255)]):
  sent=[];t.reset(dict(format=fmt));point=m.heap+0x9000;position=[1.25,-2.5,3.75]
  for i,v in enumerate(position):m.wf(point+i*4,v)
  sp=m.stack+0x1fe08;m.wi(sp+0x28,placement);m.wi(sp+0x30,x);m.wi(sp+0x38,y)
  w.call(0x1407bdc70,[w.message,target,point,amount]);assert len(sent)==1
  rows.append(dict(case=dict(format=fmt,targetId=target,amount=amount,placement=placement,x=x,y=y,position=position),packet=sent[0].hex()))
 output=m.root/'backups/animations/native-gold-transfer-observations-v1.json';assert not output.exists()
 output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=rows),indent=2));print(json.dumps(dict(output=str(output),cases=len(rows))))
