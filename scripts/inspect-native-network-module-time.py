"""Original server module-time coordinator and CNWMessage scalar serialization.
Final network-send boundary is captured; its three-byte envelope owner is
independently covered by inspect-native-message-send.py. No real credentials.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
w=importlib.import_module('inspect-native-message-writer');m=w.m;u=w.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(w.hook_handle)
d=json.loads((m.root/'backups/animations/rea-network-module-time-message.json').read_text())['structuredContent']['normalized_result']
ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
def hook(u,a,n,data):
 if a==0x1404dc490:
  rsp=u.reg_read(UC_X86_REG_RSP);p=m.q(rsp+0x28);size=m.si(rsp+0x30)
  raw=bytearray(u.mem_read(p,size));raw[:3]=bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255]);packets.append(bytes(raw).hex());m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 w.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[];player=m.heap+0x5000
for mask in range(32):
 for period in [1,3,4]:
  w.cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,w.app);m.wi(w.app+0x28,1);w.call(0x1402d4830);m.wi(player+0x48,123)
  case=dict(mask=mask,year=0xfedcba98,month=11,day=27,hour=23,timeOfDay=period,transition=0x87654321);packets=[]
  for i,value in enumerate([case[k]for k in ['month','day','hour','timeOfDay','transition']]):m.wq(m.stack+0x1fe08+0x28+i*8,value)
  result=w.call(0x1404dcb50,[w.message,player,mask,case['year']]);assert result==1 and len(packets)==1
  rows.append(dict(case=case,packet=packets[0]))
output=m.root/'backups/animations/native-network-module-time-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
