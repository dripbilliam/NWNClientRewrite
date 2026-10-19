"""Complete original GetFilteredEffectList, UpdateCombatInformation and combat
cache/node constructors; bounded AI dirty refresh and base-item constructor.
Lower stat/feat/item/base/rank/spell-slot queries, array storage,
allocation/free and old-cache destruction are captured boundaries. Native node
construction, GetInteger and cache orchestration execute. No allocation failure,
native heap addresses, complete lower stats or encounter parity claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,output,pool,rules,tables,rankTable,monsterTable,inventory,oldCache=[m.heap+n*0x1000 for n in range(10)]
ranges=[(0x140390560,0x140390b57),(0x1404171e0,0x140418523),(0x1402a22b0,0x1402a2369),(0x1402a2370,0x1402a2388),(0x140423fc0,0x140423fcc)]
baseBody=json.loads((m.root/'backups/animations/rea-base-item-instance-constructor-cache-fields.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1) for r in baseBody['ranges'])
def signed(n):return(n+2**31)%2**32-2**31
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~31;assert cursor<0xf0000;u.mem_write(ptr,bytes(size));allocations[ptr]=size;return ptr
def rank(value):return c.get('ranks',{}).get(str(value),value*3)
def itemName(ptr):return itemsByPointer[ptr][0]
def hook(u,a,n,_):
 global nextFilter
 if a in [m.stop,0x14037caf9]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if c['mode']=='frame' and a in [0x140418a60,0x1403f00a0,0x1404171e0]:
  calls.append({0x140418a60:'memorized',0x1403f00a0:'spellUses',0x1404171e0:'combat'}[a])
  if a==0x1403f00a0 and 'afterUses' in c:m.wi(actor+0x53c,c['afterUses'][0]);m.wi(actor+0x540,c['afterUses'][1])
  m.finish()
 elif a in [0x140c10324,0x140c10368]:m.finish(alloc(x))
 elif a in [0x140c10370,0x140c10360,0x140c4f024]:m.finish()
 elif a==0x140c4f038:
  ptr=alloc(y)
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,allocations[x]))))
  m.finish(ptr)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140379ca0:
  ptr=alloc(y*8);m.wq(x,ptr);m.wi(x+8,y);m.wi(x+12,y);m.finish()
 elif a==0x1401a7010:
  text=bytes(u.mem_read(m.q(z),16)).split(b'\0')[0].decode('ascii');value=rank(signed(y)) if text=='Rank' else c.get('monster',{}).get(str(y),{}).get(text,0);m.wi(w,value);m.finish(1)
 elif a==0x1402a3b60:m.finish(0 if y<=1 else y.bit_length()-1)
 elif a==0x140390560 and c['mode']=='cache':
  effects=filterPointers[z&255];ptr=alloc(len(effects)*8)
  for i,e in enumerate(effects):m.wq(ptr+i*8,e)
  m.wq(y,ptr);m.wi(y+8,len(effects));m.wi(y+12,len(effects));calls.append(['filtered',z&255]);m.finish(y)
 elif a==0x1402a2930:calls.append(['dispose']);m.finish()
 elif a in scores:
  index=scores.index(a);calls.append(['score',index]);m.finish(c.get('scores',[10,12,14,16,18,20])[index])
 elif a==0x1403f16c0:calls.append(['modifier',y&255]);m.finish((y&255)-10)
 elif a==0x140396370:calls.append(['monk']);m.finish(c.get('monk',0))
 elif a==0x1403f8e90:calls.append(['bab',y&0xffffffff]);m.finish(c.get('bab',7))
 elif a==0x140462bd0:calls.append(['equipped',y&0xffffffff]);m.finish(itemPointers.get(str(y&0xffffffff),0))
 elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);m.finish(basePointers.get(y&0xffffffff,0))
 elif a==0x140468ef0:m.finish(propertyPointers[x][y&0xffffffff])
 elif a==0x140468800:m.finish(c.get('damageFlags',3))
 elif a in [0x140468f20,0x1404690d0]:
  kind=(z if a==0x140468f20 else y)&65535;prop=next((ptr for ptr in propertyPointers[x] if int.from_bytes(u.mem_read(ptr,2),'little')==kind),0)
  if a==0x140468f20:m.wq(y,prop)
  m.finish(int(prop!=0))
 elif a==0x1404041c0:calls.append(['meleeAttack',signed(y)]);m.finish(c.get('meleeAttack',[17,11])[int(y!=0)])
 elif a==0x140405b00:calls.append(['rangedAttack']);m.finish(c.get('rangedAttack',23))
 elif a==0x1404047c0:calls.append(['meleeDamage',signed(y),z&255]);m.finish(c.get('meleeDamage',[7,3])[int(y!=0)] if (z&255)==255 else c.get('naturalDamage',[4,5,6])[z&255])
 elif a==0x1404061f0:calls.append(['rangedDamage']);m.finish(c.get('rangedDamage',9))
 elif a==0x140408dd0:calls.append(['resistance']);m.finish(c.get('resistance',13))
 elif a==0x14040aa70:calls.append(['unarmedDice']);m.finish(c.get('unarmed',[1,3])[0])
 elif a==0x14040ad60:calls.append(['unarmedDie']);m.finish(c.get('unarmed',[1,3])[1])
 elif a==0x14040b900:calls.append(['feat',y&65535]);m.finish(int((y&65535) in c.get('feats',[])))
 elif a==0x1403fcf40:calls.append(['criticalMultiplier',signed(y)]);m.finish(c.get('offMultiplier',3))
 elif a==0x1403fd040:calls.append(['criticalRoll',signed(y)]);m.finish(c.get('criticalRoll',[19,18])[int(y!=0)])
 elif not any(lo<=a<hi for lo,hi in ranges+[(0x14037caac,0x14037caf9)]):raise AssertionError(f'Unknown combat information dependency {a:x} {c}')
scores=[0x140406930,0x1403fd3e0,0x1403fa0f0,0x140402d10,0x14040b5e0,0x1403fa050]
u.hook_add(UC_HOOK_CODE,hook)
def effectData(e,index):
 ptr=m.heap+0x10000+index*0x400;values=e.get('integers',[1,0,28,0,0,0]);u.mem_write(ptr+8,struct.pack('<H',e['type']&65535));m.wi(ptr+28,e.get('spellId',-1));m.wi(ptr+0x40,8);m.wq(ptr+0x48,ptr+0x200)
 for i,value in enumerate(values):m.wi(ptr+0x200+i*4,value)
 effectIndices[ptr]=index;return ptr
def run(case):
 global c,calls,cursor,allocations,effectIndices,filterPointers,itemPointers,basePointers,propertyPointers,itemsByPointer
 c=case;calls=[];cursor=0x40000;allocations={};effectIndices={};filterPointers={1:[],2:[]};itemPointers={};basePointers={};propertyPointers={};itemsByPointer={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(actor+0xad0,stats);m.wq(stats+0x30,actor);m.wq(actor+0x950,inventory);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(rules+0x20,rules);m.wq(tables+0x2f0,rankTable);m.wq(tables+0x2d8,monsterTable)
 effects=[effectData(e,i) for i,e in enumerate(c.get('effects',[]))]
 for i,e in enumerate(effects):m.wq(pool+i*8,e)
 m.wq(actor+0x150,pool);m.wi(actor+0x158,len(effects));u.mem_write(stats+0xd94,struct.pack('<H',c.get('start',0)));u.mem_write(stats+0xd9a,struct.pack('<H',c.get('start',0)))
 if c['mode']=='cache':
  m.wq(stats+0xd70,oldCache);u.mem_write(stats+0xd78,bytes(c.get('failure',[30,20,10])));u.mem_write(stats+0xdd0,bytes(c.get('penalties',[255,254])))
  for i,e in enumerate(c.get('effects',[])):filterPointers[1 if e['type'] in [10,11] else 2].append(effects[i])
  for i,(slot,item) in enumerate(c.get('items',{}).items()):
   ptr=alloc(0x500);base=alloc(0x100);itemPointers[slot]=ptr;itemsByPointer[ptr]=(slot,item);basePointers[item['id']]=base;m.wi(ptr+0x40,item['id']);m.wi(ptr+0x50,item.get('objectId',100+int(slot)));u.mem_write(base+8,bytes([item.get('wield',0)&255,item.get('weaponType',1)&255]));u.mem_write(base+0x18,bytes([item.get('ranged',0)&255]));u.mem_write(base+0x1d,bytes([item.get('criticalMultiplier',2)&255]));u.mem_write(base+0xbe,struct.pack('<H',item.get('weaponOfChoice',100)&65535));m.wi(base+0xc0,item.get('monk',0));m.wi(base+4,item.get('equipableSlots',int(slot)))
   properties=[]
   for p in item.get('properties',[]):
    pp=alloc(32);u.mem_write(pp,struct.pack('<HHBBHBB',p['type'],p.get('subtype',0),0,0,p.get('costValue',0),0,p.get('param1Value',0)));m.wi(pp+12,p.get('remaining',0));properties.append(pp)
   propertyPointers[ptr]=properties;m.wi(ptr+0x380,len(properties))
  feats=c.get('stored',[]);fp=alloc(len(feats)*2)
  for i,feat in enumerate(feats):u.mem_write(fp+i*2,struct.pack('<H',feat))
  m.wq(stats,fp);m.wi(stats+8,len(feats));m.wi(stats+0x28,0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,output,c.get('kind',1)] if c['mode']=='filter' else [stats,0,0]):u.reg_write(reg,value)
 u.emu_start(0x140390560 if c['mode']=='filter' else 0x1404171e0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 if c['mode']=='filter':return dict(case=c,indices=[effectIndices[m.q(m.q(output)+i*8)] for i in range(m.si(output+8))])
 cache=m.q(stats+0xd70);nodes=lambda off:[list(u.mem_read(m.q(m.q(cache+off)+i*8),6)) for i in range(m.si(cache+off+8))]
 return dict(case=c,scalars=list(u.mem_read(cache,21))+list(u.mem_read(cache+24,6)),weaponIds=[m.si(cache+0x40)&0xffffffff,m.si(cache+0x44)&0xffffffff],attackNodes=nodes(0x20),damageNodes=nodes(0x30),capacity=[m.si(cache+0x2c),m.si(cache+0x3c)],modifiers=[bytes(u.mem_read(stats+o,1))[0] for o in [0xd39,0xd3b,0xd3d,0xd3f,0xd41,0xd43]],propertyRemaining={slot:[m.si(p+12) for p in propertyPointers[ptr]] for slot,ptr in itemPointers.items()},calls=calls)
rows=[]
def e(t,amount=1,hand=0,spell=-1,flags=1):return dict(type=t,spellId=spell,integers=[amount,hand if t in [10,11] else flags,28,0,0,hand])
for kind,t,values,spells in itertools.product([0,1,2,3,257],[10,11,13,14],[(1,2),(3,1),(2,2)],[(-1,-1),(-1,2),(2,-1),(2,2),(2,3)]):rows.append(run(dict(mode='filter',kind=kind,effects=[e(t,values[0],1,spells[0]),e(t,values[1],1,spells[1])],ranks={'1':30,'2':10,'3':20})))
for kind,start in itertools.product([1,2],[0,1,2,65535]):rows.append(run(dict(mode='filter',kind=kind,start=start,effects=[e(1),e(10,2),e(11,3),e(13,4),e(14,5),e(67)])))
for kind in [1,2]:
 t=10 if kind==1 else 13
 for field in range(1,6):
  a=e(t,1,1,5);b=e(t,2,1,5);b['integers'][field]+=1;rows.append(run(dict(mode='filter',kind=kind,effects=[a,b])))
 rows.append(run(dict(mode='filter',kind=kind,effects=[e(t,i+1,i%8,i) for i in range(40)])))
for bab,monk,right,left in itertools.product([-12,-5,-1,0,1,5,16,20,26,30],[0,1],[None,dict(id=22),dict(id=8,ranged=20),dict(id=22,monk=1)],[None,dict(id=14,weaponType=0),dict(id=30,monk=1)]):
 items={};
 if right:items['16']=right
 if left:items['32']=left
 if right and right.get('ranged'):items['2048']=dict(id=20)
 rows.append(run(dict(mode='cache',items=items,bab=bab,monk=monk)))
for selector,t,amount in itertools.product([-1,0,1,2,3,4,5,6,7,255],[10,11,13,14],[-129,0,2,128]):rows.append(run(dict(mode='cache',effects=[e(t,amount,selector,5,8)])))
for subtype,t in itertools.product(range(10),[16,17,18,19,21]):rows.append(run(dict(mode='cache',items={'16':dict(id=8,ranged=20),'2048':dict(id=20,properties=[dict(type=t,subtype=subtype,costValue=1,param1Value=3),dict(type=t,subtype=subtype,costValue=2,param1Value=3)])},ranks={'1':30,'2':10})))
for failure in itertools.product([0,30,100,127,128,255],repeat=3):rows.append(run(dict(mode='cache',failure=failure)))
for cost in [0,1,2,257]:rows.append(run(dict(mode='cache',items={'16384':dict(id=69,properties=[dict(type=77,costValue=cost)]),'32768':dict(id=70),'65536':dict(id=71)},monster={str(cost):dict(NumDice=258,Die=263)})))
for stored,feats in itertools.product([[],[883],list(range(870,890))],[[],[100]]):rows.append(run(dict(mode='cache',items={'16':dict(id=22,wield=8,criticalMultiplier=3)},stored=stored,feats=feats)))
rows.append(run(dict(mode='cache',effects=[e(10,i+1,i%8,i) for i in range(40)]+[e(13,i+1,i%8,i) for i in range(40)])))
frames=[]
frameCases=[dict(mode='frame',spells=spells,dirty=dirty,consumers=consumers) for spells,dirty,consumers in itertools.product([-1,0,1,2],[-1,0,1,2],[-1,0,1,2])]
frameCases.extend([dict(mode='frame',spells=1,dirty=dirty,consumers=consumers,afterUses=after) for dirty,consumers,after in itertools.product([0,1],[0,1],[(0,1),(1,0),(1,2)])])
for c in frameCases:
 calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor+0xad0,stats);m.wi(actor+0x544,c['spells']);m.wi(actor+0x53c,c['dirty']);m.wi(actor+0x540,c['consumers']);u.reg_write(UC_X86_REG_RDI,actor);u.reg_write(UC_X86_REG_R14,0);u.reg_write(UC_X86_REG_RSP,m.stack+0x10000);u.emu_start(0x14037caac,0x14037caf9,count=100);assert u.reg_read(UC_X86_REG_RIP)==0x14037caf9;frames.append(dict(case=c,calls=calls,spells=m.si(actor+0x544),dirty=m.si(actor+0x53c),consumers=m.si(actor+0x540)))
c=dict(mode='baseConstructor');u.mem_write(m.heap,bytes([0xa5])*0x100000);u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,output);u.emu_start(0x14029c750,m.stop,count=200);assert u.reg_read(UC_X86_REG_RIP)==m.stop
baseDefaults={key:int.from_bytes(u.mem_read(output+offset,2),'little') for key,offset in [('WeaponSpecializationFeat',0xb4),('EpicWeaponSpecializationFeat',0xb6),('WeaponOfChoiceFeat',0xbe)]}
out=m.root/'backups/animations/native-combat-information-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,frames=frames,baseDefaults=baseDefaults),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),frames=len(frames),baseDefaults=baseDefaults,output=str(out))))
