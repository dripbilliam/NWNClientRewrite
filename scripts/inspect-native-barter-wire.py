"""Read-only complete original barter request/reply senders and native writers.
Only client/server transport is captured. No live peers or gameplay mutation.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
e=json.loads((m.root/'backups/animations/rea-native-barter-v1.json').read_text())
names=['sender_'+v for v in ['start','close','lock','accept','window','add','remove','move']]+['start','close','lock','accept']
functions={v['key'][7:]:v for v in e['functions'] if v['key'].startswith('barter_')}
ranges=[]
for key in names:
 ranges.extend((int(v['start'],16),int(v['end'],16)+1)for v in functions[key]['procedure']['body']['ranges'])
d=json.loads((m.root/'backups/animations/rea-network-client-objectid-writer.json').read_text())['structuredContent']['raw_result']['value']['procedure']
ranges.extend((int(v['start'],16),int(v['end'],16)+1)for v in d['body']['ranges'])
def hook(u,a,n,data):
 if a in [0x1407c25c0,0x1404dc490]:
  sp=u.reg_read(UC_X86_REG_RSP);y,z,k=[u.reg_read(reg)for reg in[UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
  p=k if a==0x1407c25c0 else m.q(sp+0x28);size=m.si(sp+(0x28 if a==0x1407c25c0 else 0x30))&0xffffffff
  packet=bytearray(u.mem_read(p,size));packet[:3]=bytes([112,y&255,z&255]if a==0x1407c25c0 else[80,z&255,k&255]);sent.append(bytes(packet));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def call(key,args,stack=None):
 for offset,value in (stack or{}).items():m.wi(m.stack+0x1fe08+offset,value)
 w.call(int(functions[key]['procedure']['address'],16),args)
if __name__=='__main__':
 rows=[]
 for fmt,operation,item,target,value,(x,y)in itertools.product([0,1],['start','close','lock','accept','window','add','remove','move'],[0x80000002,0xffffffff],[0x80000013,0x7f000000],[0,1],[(0,0),(255,255)]):
  sent=[];t.reset(dict(format=fmt));args=[w.message]
  args+=([target,item]if operation=='start'else[item,x,y]if operation in['add','remove','move']else[]if operation=='close'else[value])
  call('sender_'+operation,args);assert len(sent)==1
  rows.append(dict(direction='client',case=dict(format=fmt,operation=operation,itemId=item,targetId=target,value=bool(value),x=x,y=y),packet=sent[0].hex()))
 for fmt,operation,first,second in itertools.product([0,1],['start','close','lock','accept'],[0,1],[0,1]):
  sent=[];t.reset(dict(format=fmt))
  if operation=='start':call(operation,[w.message,0x80000001,0x80000002,0x80000013],{0x28:0xffffffff})
  elif operation=='close':call(operation,[w.message,0x80000001,0x80000002,second])
  else:call(operation,[w.message,0x80000001,0x80000002,first],{0x28:second})
  assert len(sent)==2 and sent[0]==sent[1]
  rows.append(dict(direction='server',case=dict(format=fmt,operation=operation,initiator=bool(first),value=bool(second),firstId=0x80000013,secondId=0xffffffff),packet=sent[0].hex()))
 output=m.root/'backups/animations/native-barter-wire-observations-v1.json';assert not output.exists()
 output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=rows),indent=2));print(json.dumps(dict(output=str(output),cases=len(rows))))
