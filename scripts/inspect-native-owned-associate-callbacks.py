"""Unchanged original normal associate Examine/Talk/Possess/Kick callbacks.

Loads the pinned v1 authored CPU fixture definitions without its case loops.
Controlled identity, allocation, assignment setters and final wire/record
publication are captured services, not a live client or authoritative server.
"""
from pathlib import Path
import hashlib,itertools,json
root=Path(__file__).resolve().parents[1]
fixture=Path(__file__).with_name('inspect-native-owned-associate-radial.py')
source=fixture.read_text();proof=json.loads((root/'godot-client/reports/native-owned-associate-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
assert source.count('\nroots=[]\n')==1
prefix=source.split('\nroots=[]\n')[0]
assert prefix.count('u.hook_add(UC_HOOK_CODE,hook)')==1
prefix=prefix.replace('u.hook_add(UC_HOOK_CODE,hook)','new_hook=u.hook_add(UC_HOOK_CODE,hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_authored_associate_fixture'}
exec(compile(prefix,str(fixture),'exec'),ns)
u,heap=ns['u'],ns['heap'];u.hook_del(ns['new_hook'])
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
active={};seen=False;events=[]
def hook(_u,address,size,data):
 global seen
 x,y,z=[u.reg_read(r) for r in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8)]
 if address==ns['ns']['start'] and not seen:
  seen=True
  ns['ns']['wi'](ns['ns']['menu']+0x7f8,active.get('target',101))
  ns['ns']['wi'](ns['ns']['menu']+0x804,active.get('master',99))
  ns['ns']['wi'](ns['ns']['menu']+0x808,active.get('associateType',1))
  if active.get('assignment'):ns['ns']['wq'](ns['ns']['menu']+0x828,heap+0x15000)
  if active['kind']=='kick':u.reg_write(UC_X86_REG_RDX,2)
 if address==0x1406ac1c0:ns['ns']['finish'](99)
 elif address==0x1406abbc0:ns['ns']['finish'](heap+0x17000)
 elif address==0x1406fb330:events.append(dict(kind='record',target=y&0xffffffff,panel=8));ns['ns']['finish']()
 elif address==0x1407bfa80:events.append(dict(kind='examine',target=y&0xffffffff));ns['ns']['finish']()
 elif address==0x1407bf900:events.append(dict(kind='talk',target=y&0xffffffff));ns['ns']['finish']()
 elif 0x140804e90<=address<=0x140804ec0:return
 elif address==0x1407bff40:events.append(dict(kind='possess'));ns['ns']['finish']()
 elif address in (0x140866ea0,0x140866ac0,0x140868060):
  events.append(dict(kind='binding',type={0x140866ea0:40,0x140866ac0:6,0x140868060:38}[address]));ns['ns']['finish']()
 elif address==0x1407bf0e0:events.append(dict(kind='associate',target=y&0xffffffff,command=ns['signed32'](z)));ns['ns']['finish']()
 elif address==0x1407c3390:events.append(dict(kind='party',target=y&0xffffffff,operation=z&0xffffffff));ns['ns']['finish']()
 else:ns['hook'](_u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
def execute(address,last,case):
 global active,seen
 active=case;seen=False;events.clear()
 ns['execute'](address,last,dict(kind='extra'))
 return list(events)
rows=[]
for associate,master,assignment in itertools.product([0,1,2,3,4,5,6,65535],[99,100],[False,True]):
 case=dict(kind='examine',associateType=associate,master=master,assignment=assignment)
 actual=execute(0x140997e00,0x140997ee9,case)
 expected=[dict(kind='binding',type=40)] if assignment else [dict(kind='record',target=101,panel=8)] if associate in [1,2,3,4] and master==99 else [dict(kind='examine',target=101)]
 assert actual==expected,(case,actual,expected)
 rows.append(dict(input=case,observations=actual))
for assignment in [False,True]:
 case=dict(kind='talk',assignment=assignment)
 actual=execute(0x140996190,0x14099624f,case)
 expected=[dict(kind='binding',type=6)] if assignment else [dict(kind='talk',target=101)]
 assert actual==expected,(case,actual,expected);rows.append(dict(input=case,observations=actual))
 case=dict(kind='possess',assignment=assignment)
 actual=execute(0x1409980c0,0x1409980ff,case)
 expected=[dict(kind='binding',type=38)] if assignment else [dict(kind='possess')]
 assert actual==expected,(case,actual,expected);rows.append(dict(input=case,observations=actual))
for associate in [0,1,2,3,4,5,6,65535]:
 case=dict(kind='kick',associateType=associate)
 actual=execute(0x140997f30,0x140998057,case)
 expected=[dict(kind='associate',target=101,command=-17)]+([] if associate==1 else [dict(kind='party',target=101,operation=2)])
 assert actual==expected,(case,actual,expected);rows.append(dict(input=case,observations=actual))
report=dict(success=True,binarySha256=proof['binarySha256'],scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),fixtureSha256=proof['scriptSha256'],cases=len(rows),rows=rows,scope=__doc__,limits=['Normal permission0; DM forced record requires separate source admission.','Talk self-message input is not used by the associate type2 branch and is not covered here.','Record target publication8 is captured, not a21/1 subscription or received data outcome.','Kick is not assigned; its source callback has no assignment mode and must not invent a type39 drag.'])
output=ns['ns']['output'];output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,cases=len(rows),report=str(output))))
