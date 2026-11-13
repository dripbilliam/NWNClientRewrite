"""Execute unchanged original associate roots/actions and command callbacks.

The PE and base fixture are hash-pinned. UI allocation/publication, controlled
actor and party/network services are authored captured boundaries. No process,
network connection, visual acceptance or replacement policy is exercised.
"""
from pathlib import Path
import hashlib,itertools,json
root=Path(__file__).resolve().parents[1]
fixture=Path(__file__).with_name('inspect-native-creature-radial.py')
source=fixture.read_text()
proof=json.loads((root/'godot-client/reports/native-creature-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
assert source.count('\nrows=[]\n')==1
prefix=source.split('\nrows=[]\n')[0]
assert prefix.count('u.hook_add(UC_HOOK_CODE, hook)')==1
prefix=prefix.replace('u.hook_add(UC_HOOK_CODE, hook)','hook_handle=u.hook_add(UC_HOOK_CODE, hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_authored_radial_fixture'}
exec(compile(prefix,str(fixture),'exec'),ns)
u,heap=ns['u'],ns['heap'];u.hook_del(ns['hook_handle'])
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
active={};observed=[];entry_seen=False
def signed32(value):return (value&0xffffffff)-0x100000000 if value&0x80000000 else value&0xffffffff
def hook(_u,address,size,data):
 global entry_seen
 x,y,z=[u.reg_read(r) for r in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8)]
 if address==ns['start'] and not entry_seen:
  entry_seen=True
  if active['kind']=='root':
   ns['wi'](ns['actor']+0x408,active['polymorph'])
   u.reg_write(UC_X86_REG_RDX,active['associateType'])
  elif active['kind']=='actions':u.reg_write(UC_X86_REG_RDX,active['associateType'])
  elif active['kind']=='command':
   u.reg_write(UC_X86_REG_RDX,active['rawArgument']&0xffffffffffffffff)
   ns['wi'](ns['menu']+0x7f8,101)
   if active['assignment']:ns['wq'](ns['menu']+0x828,heap+0x15000)
 if address==0x1406ac1a0:ns['finish'](ns['actor'] if active.get('actorPresent',True) else 0)
 elif address==0x1406ac020:ns['finish'](heap+0x13000 if active.get('partyPresent',True) else 0)
 elif address==0x140851d00:
  index=signed32(y);observed.append(dict(kind='resolve',index=index));ns['finish'](200+index)
 elif address==0x1407bf0e0:
  observed.append(dict(kind='wire',target=y&0xffffffff,command=signed32(z)));ns['finish'](1)
 elif address==0x140860760:
  observed.append(dict(kind='binding',target=int.from_bytes(u.mem_read(x+0xe8,4),'little'),packed=y&0xffffffff));ns['finish']()
 elif address==0x140c10324:ns['finish'](heap+0x10000)
 elif address==0x1401f7950:ns['finish'](x)
 elif address==0x1400931f0:ns['finish'](heap+0x14000)
 elif address in (0x14084c550,0x1401f9ee0):ns['finish']()
 else:ns['hook'](_u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
def execute(address,last,case):
 global active,entry_seen
 active=case;entry_seen=False;observed.clear()
 value=ns['execute'](address,last)
 value['observations']=list(observed)
 return value
roots=[]
for present,poly,associate in itertools.product([False,True],[0,1,0xffffffff],[0,1,2,3,4,5,6,65535]):
 case=dict(kind='root',actorPresent=present,polymorph=poly,associateType=associate)
 value=execute(0x14098e340,0x14098e545,case)
 byslot={entry['slot']:entry for entry in value['entries']}
 assert set(byslot)=={0,2,3,4,5,6,7}|({1} if present and poly==0 else set())
 for slot,command in [(0,-4),(2,-3),(3,-5),(4,-2),(5,-7)]:
  assert byslot[slot]['callback']=='0x140995f10'
  assert signed32(byslot[slot]['argument'])==command
 assert byslot[7]['argument']==associate
 roots.append(dict(input=case,**value))
actions=[]
for associate in [0,1,2,3,4,5,6,65535]:
 case=dict(kind='actions',associateType=associate)
 value=execute(0x14098f8e0,0x14098fbed,case)
 byslot={entry['slot']:entry for entry in value['entries']}
 expected={1:set(range(8)),2:{0,3,7},3:{0,2,3},4:{0,3},5:{0,3}}.get(associate,{0})
 assert set(byslot)==expected,(associate,byslot)
 actions.append(dict(input=case,**value))
callbacks=[]
commands=[-23,-22,-21,-20,-19,-18,-17,-13,-12,-10,-9,-8,-7,-5,-4,-3,-2]
for command,assignment,party in itertools.product(commands,[False,True],[False,True]):
 case=dict(kind='command',rawArgument=command,assignment=assignment,partyPresent=party)
 value=execute(0x140995f10,0x140995fc1,case)
 expected=[] if not party else [dict(kind='binding',target=101,packed=((command&65535)<<16)|1)] if assignment else [dict(kind='wire',target=101,command=command)]
 assert value['observations']==expected,(case,value,expected)
 callbacks.append(dict(input=case,**value))
report=dict(success=True,binarySha256=ns['digest'],scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),fixtureSha256=proof['scriptSha256'],rootCases=len(roots),actionCases=len(actions),callbackCases=len(callbacks),roots=roots,actions=actions,callbacks=callbacks,scope=__doc__,limits=['Controlled actor, party owner, UI allocations, sector publication and network writer are authored capture boundaries.','The callback wire observation is not an original-server outcome.','Portrait/world dispatcher and Cast/ability subtree semantics are retained separate original analyses; no DM/default initialization is inferred.','Positive packed selector variants, Kick/possession/conversation callbacks, binding display fallback and final pixels require separate coverage.'])
output=ns['output'];output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,rootCases=len(roots),actionCases=len(actions),callbackCases=len(callbacks),report=str(output))))
