"""Complete unchanged enhancement/damage/ability item materializers with real
CGameEffect base/copy constructors, CopyEffect and SetInteger. Capture active
table/base/damage-flag queries, SetCreator, ApplyEffect and memory/string/vector
owners. Original ID allocation, copy exposure/icon flags, argument order, slot/
condition selection, cost remapping and early exits execute. No every-spell or
lower ApplyEffect/equipment-completion claim; no live process or asset edits.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
handler,item,prop,owner,rules,twodas,info,melee,ability,damage,armor=[m.heap+i*0x1000 for i in range(11)]
tables={melee:'melee',ability:'ability',damage:'damage',armor:'armor'};idGlobal=0x141290568
ranges=[(0x1404725f0,0x1404726c8),(0x140472270,0x1404723c6),(0x14042ed70,0x14042ee1f),(0x14046d9b0,0x14046dca9),(0x14046fee0,0x14047077d),(0x14046ece0,0x14046f0aa),(0x14046dcd0,0x14046de6d),(0x1404233d0,0x14042356e),(0x140423570,0x140423768),(0x140423ce0,0x140423f86),(0x140425210,0x14042521c)]
ranges.extend([(0x140470c90,0x140470f00),(0x1404726d0,0x1404727b4),(0x14046f540,0x14046f692),(0x14046f6a0,0x14046f806)])
formMaterializers={'darkVision':(0x14046f980,0x14046fa2a),'trueSeeing':(0x140472cb0,0x140472d49),'evasion':(0x140471e80,0x140471f29),'immunity':(0x140471c70,0x140471e7c),'bonusFeat':(0x14046e6d0,0x14046e817),'spellLevel':(0x140472900,0x1404729eb),'spellSchool':(0x1404729f0,0x140472b54),'spellSpecific':(0x140472b60,0x140472cac),'damagePercent':(0x14046f0b0,0x14046f22c),'vulnerability':(0x14046f810,0x14046f97d),'spellResistance':(0x140472130,0x14047226d)}
ranges.extend(formMaterializers.values());feats=m.heap+0xb000;tables[feats]='feats'
formMaterializers.update({'attack':(0x14046dfe0,0x14046e3eb),'saveVs':(0x140472030,0x14047212f),'turnResistance':(0x140472d50,0x140472e05)})
ranges.extend([formMaterializers[k]for k in ['attack','saveVs','turnResistance']]);ranges.append((0x14046e9f0,0x14046ecd4));saveElements=m.heap+0xc000;tables[saveElements]='saveElements'
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def text(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode('ascii') if m.q(ptr) else ''
def snapshot(ptr):return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),durationType=int.from_bytes(u.mem_read(ptr+0xa,2),'little'),exposed=m.si(ptr+0x20),showIcon=m.si(ptr+0x24),creatorId=m.si(ptr+0x18)&0xffffffff,spellId=m.si(ptr+0x1c),casterLevel=m.si(ptr+0x28),propertyId=f'{m.q(ptr+0xf0):016x}',integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(m.si(ptr+0x40))])
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10324,0x140c10368]:
  ptr=m.heap+cursor;cursor+=(x+15)&~15;assert cursor<0xe0000;m.finish(ptr);return
 if a in [0x140c10360,0x140c10370]:m.finish();return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x140047300:u.mem_write(x,bytes(12));m.finish(x);return
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if a==0x14003d8c0:
  if z:
   raw=bytes(u.mem_read(y,z));ptr=m.heap+cursor;cursor+=(z+16)&~15;u.mem_write(ptr,raw+b'\0');m.wq(x,ptr);m.wi(x+8,z);m.wi(x+12,z+1)
  else:m.wq(x,0);m.wq(x+8,0)
  m.finish(x);return
 if a==0x1404233d0:trace.append(['ctor',signed(y)])
 if a==0x140423570:trace.append(['copyCtor',signed(z)])
 if a==0x140423ce0:trace.append(['copyAssign',signed(z)])
 if a==0x14029ca00:trace.append(['base',signed(y)]);m.finish(info);return
 if a==0x1402b38a0:
  trace.append(['cost',y&255]);m.finish((0 if c.get('noTable') else armor)if c['kind'] in formMaterializers else ability if y&255==1 else armor if y&255 in [2,6,7] else 0 if c.get('noDamageTable') else damage);return
 if a==0x1401a7010:
  table=tables[x];column=text(z);row=y&0xffffffff
  if table=='damage':value=c.get('damageRows',[[0,3],[0,6],[1,7],[0,7]])[row][0 if column=='NumDice' else 1];status=c.get('damageStatus',1)
  elif table=='saveElements':value=c.get('saveValue',22);status=c.get('saveStatus',1)
  else:value=c.get('value',3);status=c.get('status',1)
  trace.append(['int',table,row,column,status,value]);m.wi(q,value);m.finish(status);return
 if a==0x140425110:trace.append(['creator',y&0xffffffff]);m.wi(x+0x18,y);m.wi(x+0x28,0);m.finish();return
 if a==0x140468800:trace.append(['damageFlags']);m.finish(c.get('damageFlags',4));return
 if a==0x1404690d0:trace.append(['has',y&65535,z&65535]);m.finish(c.get('has',1));return
 if a==0x14048e350:trace.append(['apply',snapshot(y),z&0xffffffff,q&0xffffffff]);m.finish(1);return
 if a==0x140423770:trace.append(['release',snapshot(x)]);m.finish();return
 if a==0x140115890:
  line=m.si(u.reg_read(UC_X86_REG_RSP)+0x28);trace.append(['warning',{0x20e:'attackSlot',0x49d:'attackSlot',0x298:'damageSlot',0x401:'damageSlot'}[line]]);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if any(lo<=a<hi for lo,hi in ranges):return
 raise RuntimeError(f'Unmapped concrete materializer dependency {a:x}')
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,cursor
 c=case;trace=[];cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(idGlobal,100);m.wq(0x1412df8f8,rules);m.wq(rules+0x20,info);m.wq(rules+0x130,twodas);m.wq(twodas+0x160,melee);m.wi(item+0x40,c.get('baseItem',22));m.wi(item+0x50,123);u.mem_write(info+8,bytes([c.get('wield',0)&255]));u.mem_write(info+0xa9,bytes([c.get('acEnchant',3)&255]));m.wi(damage+0x50,len(c.get('damageRows',[[0,3],[0,6],[1,7],[0,7]])))
 m.wq(twodas+0x400,feats);m.wq(owner+0xad0,0 if c.get('noStats')else m.heap+0xc000);u.mem_write(prop+4,bytes([c.get('costTable',0)&255]))
 m.wq(twodas+0x198,saveElements if c.get('saveTable',False)else 0)
 for offset,key,fmt,default in [(0,'type','H',6),(2,'subtype','H',0),(6,'costValue','H',1),(9,'param1Value','B',5)]:u.mem_write(prop+offset,struct.pack('<'+fmt,c.get(key,default)&(65535 if fmt=='H' else 255)))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,c.get('slot',16));m.wi(rsp+0x30,c.get('loading',0));u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[handler,item,prop,owner]):u.reg_write(reg,value)
 entries={**{name:bounds[0]for name,bounds in formMaterializers.items()},'freeAction':0x140470c90,'skill':0x1404726d0,'reduction':0x14046f540,'resistance':0x14046f6a0,'regeneration':0x1404725f0,'light':0x140472270,'armor':0x14046d9b0,'enhancement':0x14046fee0,'damage':0x14046ece0,'ability':0x14046dcd0}
 try:u.emu_start(entries[c['kind']],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,trace=trace,nextId=f'{m.q(idGlobal):016x}')
if __name__=='__main__':
 rows=[]
 for kind,types in [('enhancement',[6,7,8,9]),('damage',[16,17,18,19])]:
  for type_,subtype in itertools.product(types,[0,1,2,3,4,5,6,7,8,9,65535]):rows.append(run(dict(kind=kind,type=type_,subtype=subtype)))
  for type_,slot,wield in itertools.product(types,[16,32,8,16384,32768,65536,1],[0,8]):rows.append(run(dict(kind=kind,type=type_,subtype=5,slot=slot,wield=wield)))
 for value,wield,status in itertools.product([0,-1,1,5,6,7,20,-2147483648],[0,8],[0,1]):rows.append(run(dict(kind='enhancement',value=value,wield=wield,status=status)))
 for base_,cost_,slot,wield in itertools.product([0,20,25,27,28,0xffffffff],[0,1,65535],[16,32,8,1],[0,8]):rows.append(run(dict(kind='damage',type=16,baseItem=base_,costValue=cost_,slot=slot,wield=wield)))
 for type_,value in itertools.product([16,17,18,19],[0,1,2,3,5,13,255,256,65535]):rows.append(run(dict(kind='damage',type=type_,subtype=value,param1Value=value)))
 for selector,value,status,loading in itertools.product([0,1,2,3,4,5,6,7,8,65535],[0,1,4,-1],[0,1],[0,1,3]):rows.append(run(dict(kind='ability',type=0,subtype=selector,value=value,status=status,loading=loading)))
 for fields in [dict(noDamageTable=True),dict(damageRows=[]),dict(damageRows=[[1,6],[0,7]]),dict(damageRows=[[0,6],[0,6]]),dict(damageStatus=0),dict(damageFlags=0x80000000)]:rows.append(run(dict(kind='enhancement',value=6,**fields)))
 out=m.root/'backups/animations/native-item-property-materializer-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
