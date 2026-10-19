"""Complete original CNWCCreature SwitchWeaponEvent14080e9d0 routing.

Original owner updates, weapon scale fallback, hidden/model checks, bow/shield
branches and attachment/detachment requests execute. Canonical object/control,
model/animation-base lookups, FLOAT table getter, virtual attach/priority and
animation refresh are captured lower boundaries. No bone/pivot/GPU claim.
"""
import sys,importlib,json,itertools,struct
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for file in ['rea-network-held-equipment-presentation.json','rea-network-held-anim-base.json','rea-network-item-owner-change.json']:
 d=json.loads((m.root/'backups/animations'/file).read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
actor,right,left,body,actorVt,itemVt,bodyVt,modelVt,appearance,array,rules=[m.heap+n*0x1000 for n in range(3,14)]
def cstr(p):return bytes(u.mem_read(p,256)).split(b'\0')[0].decode('latin1')
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406abb70:m.finish(array);return
 if a==0x140296470:
  item=right if y==0x80000002 and c['right']else left if y==0x80000003 and c['left']else 0
  if item:m.wq(z,item+0x48)
  m.finish(0 if item else 1);return
 if a==m.stop+0x10:m.finish(x-0x48);return
 if a==m.stop+0x20:
  item=x-0x48;absent=c['missingRightModel']if item==right else c['missingLeftModel'];m.finish(0 if absent else item+0x500);return
 if a==m.stop+0x30:
  priority.append(dict(itemId=0x80000002 if x==right+0x500 else 0x80000003,value=y&0xffffffff));m.finish();return
 if a==m.stop+0x40:
  attach.append(dict(itemId=y&0xffffffff,anchor=cstr(m.q(z))if m.q(z)else'',right=k&255,scale=struct.unpack('<f',bytes(u.mem_read(sp+0x28,4)))[0]));m.finish();return
 if a==m.stop+0x50:m.finish(0);return
 if a==0x1406ac1a0:m.finish(actor if c['local']else actor+0x800);return
 if a==0x1401a6c70:
  reads.append(dict(row=y,column=cstr(m.q(z))));m.wf(k,c['scale']);m.finish(c['scaleFound']);return
 if a in [0x1407630d0,0x140762530,0x140764300]:m.finish(0);return
 if a==0x140115890:warnings.append('Native missing item model');m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,attach,priority,reads,warnings
 c=case;attach=[];priority=[];reads=[];warnings=[];t.reset(dict(format=1));m.wq(actor,actorVt);m.wi(actor+8,0xffffffff);m.wq(actor+0x78,body);m.wq(actor+0x300,appearance if c['appearance']else 0);u.mem_write(appearance+0xcc,struct.pack('<H',42));m.wq(body,bodyVt);m.wq(bodyVt+0xc8,m.stop+0x40);m.wq(actorVt+0x140,m.stop+0x50);m.wi(actor+0x318,0x80000002 if c['right']else 0x7f000000);m.wi(actor+0x31c,0x80000003 if c['left']else 0x7f000000)
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,rules);m.wq(rules+0x100,appearance)
 m.wq(itemVt+0x68,m.stop+0x10);m.wq(itemVt+0x140,m.stop+0x20);m.wq(modelVt+0x1a0,m.stop+0x30)
 for item,base,hidden in [(right,c['rightBase'],c['hiddenRight']),(left,c['leftBase'],c['hiddenLeft'])]:
  m.wi(item+0x40,base);m.wq(item+0x48,itemVt);m.wi(item+0x50,0x80000002 if item==right else 0x80000003);m.wi(item+0x2b0,hidden);m.wq(item+0x500,modelVt);m.wi(item+0x25c,0x7f000000);m.wi(item+0x260,0x7f000000)
 w.call(0x14080e9d0,[0,0,actor,0]);return dict(case=c.copy(),attach=attach,priority=priority,reads=reads,warnings=warnings,owners=[dict(owner=m.si(i+0x25c)&0xffffffff,visual=m.si(i+0x260)&0xffffffff)for i in [right,left]])
base=dict(right=True,left=True,rightBase=22,leftBase=22,appearance=True,scaleFound=True,scale=1,local=True,hiddenRight=False,hiddenLeft=False,missingRightModel=False,missingLeftModel=False)
cases=[]
for rb,lb,mask,local in itertools.product([0,8,11,22],[0,14,22,56,57,58],range(4),[False,True]):cases.append(dict(base,rightBase=rb,leftBase=lb,right=bool(mask&1),left=bool(mask&2),local=local))
for key in ['hiddenRight','hiddenLeft','missingRightModel','missingLeftModel']:
 for rb,lb in itertools.product([8,22],[14,22]):cases.append(dict(base,**{key:True},rightBase=rb,leftBase=lb))
for appearancePresent,found,scale in itertools.product([False,True],[False,True],[0,.5,2]):cases.append(dict(base,appearance=appearancePresent,scaleFound=found,scale=scale))
rows=[run(c)for c in cases]
vtables=[]
for name,tableAddr,thunk,bodyAddr in [('Wield',0x140e74fe8,0x14099d32c,0x14099d340),('HeadWield',0x140e75280,0x14099e1e4,0x14099e1f0),('Parts adjusted base',0x140e755e8,0x1409a10c8,0x14099e1f0)]:
 assert struct.unpack('<Q',m.pe.get_data(tableAddr-0x140000000+0xc8,8))[0]==thunk
 vtables.append(dict(name=name,table=hex(tableAddr),slot='0xc8',thunk=hex(thunk),body=hex(bodyAddr)))
staticScope='Static vtable/disassembly evidence; derived attachment methods not emulated here'
ctor=[dict(address=hex(x.address),text=x.mnemonic+' '+x.op_str)for x in Cs(CS_ARCH_X86,CS_MODE_64).disasm(m.pe.get_data(0x99e344,0x1d),0x14099e344)]
output=m.root/'backups/animations/native-held-equipment-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,staticAttachment=dict(scope=staticScope,vtables=vtables,partsConstructor=ctor),cases=rows),indent=2)+'\n');print(json.dumps(dict(output=str(output),cases=len(rows))))
