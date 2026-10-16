"""Read-only original property cost4656c0, price-cache464e10 and GetCost468710.
Typed active-table/string/column/rules queries, base-info, lower property-price
and cache recalculation are captured boundaries in their respective callers.
Compares complete arithmetic/branch/lookup order and cache writes, not lower
table parsing, OOM/unwinding or arbitrary invalid native pointers.
Hash continuation2ae870 executes unchanged; rules queries verify the full
effective key including the prehashed first character.
"""
import importlib.util,itertools,json,struct,random,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,propertyPtr,basePtr,rulesPtr,baseInfoPtr,definitionPtr,armorPtr,spellsPtr,costPtr,namedPtr,passivePtr,activePtr=[m.heap+n*0x1000 for n in range(1,13)]
tables={definitionPtr:'definition',armorPtr:'armor',spellsPtr:'spells',costPtr:'cost',namedPtr:'named'}
owners={'property':(0x1404656c0,0x1404659de),'recalculate':(0x140464e10,0x14046530a),'get':(0x140468710,0x1404687fe)}
def fl(value):return float({'nan':math.nan,'inf':math.inf,'-inf':-math.inf}.get(value,value)) if isinstance(value,str)else value
def bits(value):return struct.unpack('<I',struct.pack('<f',fl(value)))[0]
def fnv(text):
 value=0xcbf29ce484222325
 for b in text.encode('ascii'):value=((value^b)*0x100000001b3)&0xffffffffffffffff
 return value
def ctext(ptr):
 raw=bytearray()
 while ptr and len(raw)<4096:
  b=u.mem_read(ptr+len(raw),1)[0]
  if not b:break
  raw.append(b)
 return raw.decode('cp1252')
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr
def owning(ptr,text):
 raw=text.encode('cp1252');data=alloc(len(raw)+1);u.mem_write(data,raw+b'\0');m.wq(ptr,data if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def writeProperty(ptr,p):
 u.mem_write(ptr,bytes(48));u.mem_write(ptr,(p.get('type',15)&65535).to_bytes(2,'little'));u.mem_write(ptr+2,(p.get('subtype',1)&65535).to_bytes(2,'little'));u.mem_write(ptr+6,(p.get('costValue',2)&65535).to_bytes(2,'little'));u.mem_write(ptr+0x11,bytes([p.get('durationType',2)&255]))
def propertyName(ptr):return propertyNames[ptr]
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if c['mode']=='get' and at==0x140464e10:
  calls.append(['recalculate']);m.wi(objectPtr+0x38c,c.get('newBase',17));m.wi(objectPtr+0x390,c.get('newUnidentified',3));m.wi(objectPtr+0x394,c.get('newAdd',2));m.finish();return
 if c['mode']=='recalculate' and at==0x1404656c0:
  name=propertyName(y);calls.append(['propertyPrice',name]);u.reg_write(UC_X86_REG_XMM0,bits(properties[y].get('price',0)));m.finish();return
 if at==0x14029ca00:
  calls.append(['baseInfo']);m.finish(0 if c.get('nullBase') else baseInfoPtr);return
 if at==0x1401a6c70:
  table=tables[x];row=y&0xffffffff;column=stored(z);calls.append(['float',table,row,column]);entry=c.get('floats',{}).get(table,dict(value=0,status=0));m.wi(w,bits(entry['value']));m.finish(entry['status']);return
 if at==0x1401a68f0:
  assert x==definitionPtr;calls.append(['string','definition',y&0xffffffff,stored(z)]);entry=c.get('subtype',dict(value='',status=0));owning(w,entry['value']);m.finish(entry['status']);return
 if at==0x1402b31e0:
  calls.append(['namedTable',stored(y),z&0xffffffff]);m.finish(namedPtr if c.get('named',True) else 0);return
 if at==0x14003d8c0:owning(x,bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252'));m.finish(x);return
 if at==0x1401a7010:
  calls.append(['int','definition',y&0xffffffff,stored(z)]);entry=c.get('costType',dict(value=0,status=0));m.wi(w,entry['value']);m.finish(entry['status']);return
 if at==0x1402b38a0:
  id=y&255;calls.append(['costTable',id]);m.finish(costPtr if c.get('costPresent',True) else 0);return
 if at==0x1401a6a80:
  calls.append(['column',tables[x],stored(y)]);m.finish(6 if x==costPtr else 3);return
 if at==0x1401a6d60:
  table=tables[x];row=y&0xffffffff;column=z&0xffffffff;calls.append(['floatColumn',table,row,column]);value=c.get('spellCosts' if x==spellsPtr else 'useCosts',{}).get(str(row),0);m.wi(w,bits(value));m.finish(0);return
 if at==0x1402a4130:assert y==fnv('MAX_CHARGES_FOR_ITEM_COST');calls.append(['rule','MAX_CHARGES_FOR_ITEM_COST',z&0xffffffff]);m.finish(c.get('rule',50));return
 if at==0x140c10368:m.finish(alloc(x));return
 if at==0x140c10370:m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not (any(lo<=at<hi for lo,hi in owners.values()) or 0x1402ae870<=at<0x1402ae899):raise AssertionError(f'Uncaptured item-price dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,properties,propertyNames
 c=case;calls=[];cursor=0x20000;properties={};propertyNames={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,basePtr);m.wq(basePtr+0x20,basePtr);m.wq(basePtr+0x130,rulesPtr)
 for offset,ptr in [(0x168,definitionPtr),(0x180,armorPtr),(0x148,spellsPtr)]:m.wq(rulesPtr+offset,ptr)
 u.mem_write(baseInfoPtr+0x1e,bytes([c.get('category',0)&255]));m.wi(baseInfoPtr+0x20,bits(c.get('baseCost',10)));m.wi(baseInfoPtr+0x28,bits(c.get('multiplier',1)));u.mem_write(baseInfoPtr+0x24,(c.get('stacking',1)&65535).to_bytes(2,'little'));u.mem_write(baseInfoPtr+0x38,bytes([c.get('ilrStackSize',7)&255]))
 for offset,key,fallback in [(0x40,'baseItem',0),(0x144,'plot',0),(0x35c,'armor',3),(0x360,'identified',0),(0x388,'charges',50),(0x38c,'base',11),(0x390,'unidentified',5),(0x394,'add',2),(0x398,'dirty',0),(0x454,'stack',3)]:m.wi(objectPtr+offset,c.get(key,fallback))
 for key,ptr,member in [('passive',passivePtr,0x378),('active',activePtr,0x368)]:
  rows=c.get(key,[]);m.wq(objectPtr+member,ptr);m.wi(objectPtr+member+8,len(rows))
  for i,p in enumerate(rows):target=ptr+i*48;writeProperty(target,p);properties[target]=p;propertyNames[target]=key+str(i)
 if c['mode']=='property':writeProperty(propertyPtr,c.get('property',{}))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x700,bytes(0x800));m.wq(rsp,m.stop);m.wi(rsp+0x28,c.get('overridePlot',0));u.reg_write(UC_X86_REG_RSP,rsp)
 values=[objectPtr,propertyPtr if c['mode']=='property' else c.get('stackFlag',0),c.get('identifiedFlag',1),c.get('ilrFlag',0)]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],values):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(owners[c['mode']][0],m.stop,count=500000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,floatResult=f'{u.reg_read(UC_X86_REG_XMM0)&0xffffffff:08x}' if c['mode']=='property' else None,cells={str(offset):m.si(objectPtr+offset)&0xffffffff for offset in [0x38c,0x390,0x394,0x398]})
rows=[]
for duration,directStatus,subStatus,named,costStatus,costId,costPresent in itertools.product([1,2,3],[0,1,2],[0,1],[False,True],[0,1],[0,3],[False,True]):
 rows.append(run(dict(mode='property',property=dict(type=7,subtype=2,costValue=9,durationType=duration),floats=dict(definition=dict(status=directStatus,value=-.75),named=dict(status=1,value=1.25),cost=dict(status=0,value=2.5)),subtype=dict(status=subStatus,value='iprp_test'),named=named,costType=dict(status=costStatus,value=costId),costPresent=costPresent)))
for plot,baseItem,dirty,identifiedFlag,ilrFlag,stackFlag in itertools.product([0,1,2],[0,68,69,73,74],[0,1],[0,1,2],[0,1,2],[0,1,2]):
 rows.append(run(dict(mode='get',plot=plot,baseItem=baseItem,dirty=dirty,identifiedFlag=identifiedFlag,ilrFlag=ilrFlag,stackFlag=stackFlag)))
rng=random.Random(20261016)
for i in range(220):
 passive=[dict(type=1,price=rng.choice([-.1,-1,0,.2,1.5,2.25,'nan']))for _ in range(rng.randrange(4))]
 active=[dict(type=rng.choice([15,15,15,1]),subtype=rng.randrange(3),costValue=rng.randrange(9),durationType=rng.choice([1,2,3]),price=rng.choice([-.5,0,.5]))for _ in range(rng.randrange(6))]
 rows.append(run(dict(mode='recalculate',passive=passive,active=active,baseCost=rng.choice([-1.5,0,.75,10,1e20,'nan']),category=rng.choice([0,4]),multiplier=rng.choice([-.25,0,.5,1,1.25,3]),charges=rng.choice([0,7,50,255]),rule=rng.choice([-1,0,1,50,250,500]),floats=dict(armor=dict(status=0,value=rng.choice([0,1.25,10]))),spellCosts={str(n):rng.choice([0,.5,1.25,100,'nan'])for n in range(3)},useCosts={str(n):rng.choice([0,.5,1,2.25])for n in range(9)})))
for price,stack,stacking,ilrStack in itertools.product([0,1,0x7fffffff,0xffffffff],[-1,0,1,2,0x7fffffff],[0,1,3],[0,2]):
 rows.append(run(dict(mode='get',base=price,add=0,stack=stack,stacking=stacking,stackFlag=1,ilrStackSize=ilrStack)))
rows.append(run(dict(mode='recalculate',nullBase=True)))
out=m.root/'backups/animations/native-item-price-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
