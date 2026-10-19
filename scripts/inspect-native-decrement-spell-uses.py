"""Complete original DecrementSpellUses581 wrapper and selected slot/class/
per-day/SLA accessor owners. VM, spell lookup/level, uses-left, ClassInfo ready
count and UnReadySpell are captured lower boundaries; the last three already
have separate native spellbook comparisons. Native slot pointers/counts/details,
per-day mutation and duplicate SLA search/mutation execute. No whole casting or
unbounded/corrupt storage claim. Traces include actual direct helper calls.
"""
import importlib,sys,json,itertools,copy,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
stats,actor,rules,spellArray,app,vm,abilityListPtr,abilityArray=[m.heap+i*0x2000 for i in range(1,9)]
classDefs,allocation,spellBase=m.heap+0x20000,m.heap+0x80000,m.heap+0xa0000
ranges=[(0x1405155c0,0x140515993),(0x1403fa4a0,0x1403fa4c2),(0x1403fa4d0,0x1403fa4f0),
 (0x140404aa0,0x140404b4a),(0x140404be0,0x140404c65),(0x140405770,0x14040579d),
 (0x140404f80,0x140404fff),(0x1403f2790,0x1403f2869),(0x140403340,0x140403376),
 (0x140408aa0,0x140408ae4),(0x140416b00,0x140416b62)]
entryNames={0x1403fa4a0:'classType',0x1403fa4d0:'classInfo',0x140404aa0:'slotId',0x140404be0:'details',0x140405770:'slotCount',0x140404f80:'ready',0x1403f2790:'decrementDay',0x140403340:'abilityReady',0x140408aa0:'abilityLevel',0x140416b00:'setAbilityReady'}
def alloc(size):
 global cursor
 ptr=allocation+cursor;cursor+=(size+15)&~15;assert cursor<0x20000;return ptr
def string(ptr):
 out=bytearray()
 while ptr:
  byte=u.mem_read(ptr,1)[0]
  if not byte:break
  out.append(byte);ptr+=1
 return out.decode('ascii')
def record(ptr):return None if not ptr else dict(id=m.si(ptr)&0xffffffff,ready=m.si(ptr+4),metamagic=m.si(ptr+8)&0xffffffff,domain=m.si(ptr+12))
def response(index,id):return c['ready'].get(f'{index}:{id}',dict(count=0,level=255,slot=255))
def hook(u,a,n,_):
 global detailResult
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286160:calls.append(['pop','object']);m.wi(y,c['objectId']);m.finish(c['popObject']);return
 if a==0x140286110:calls.append(['pop','int']);m.wi(y,c['id']);m.finish(c['popInt']);return
 if a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(pointers.get(str(y&0xffffffff),0));return
 if a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c['creature']else 0);return
 if a==0x1402af530:
  id=pointerIds[x];calls.append(['level',id,y&255]);value=c['spells'][str(id)];m.finish(value.get('levels',{}).get(str(y&255),value.get('level',1)));return
 if a==0x140409160:calls.append(['uses',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255]);m.finish(c['uses'].get(str(z&255),0));return
 if a==0x140405110:
  index=(x-stats-0xe0)//0x188;r=response(index,y&0xffffffff);assert m.si(rsp+0x28)&255==255
  u.mem_write(z,bytes([r['level']&255]));u.mem_write(w,bytes([r['slot']&255]));m.finish(r['count']);return
 if a==0x140416eb0:calls.append(['unready',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255]);m.finish(c['unreadyResult']);return
 if a==0x140115890:warnings.append(string(m.q(rsp+0x38)));m.finish();return
 if a in entryNames:
  name=entryNames[a]
  if name in['classType','classInfo']:args=[y&255]
  elif name in['slotId']:args=[y&255,z&255,w&255]
  elif name=='details':args=[(x-stats-0xe0)//0x188,y&255,z&255]
  elif name=='ready':args=[y&255,z&0xffffffff]
  elif name in['slotCount','decrementDay']:args=[y&255,z&255]
  elif name in['abilityReady','abilityLevel']:args=[y&0xffffffff]
  else:args=[y&0xffffffff,z&0xffffffff,w&255]
  calls.append([name,*args]) # execute each complete original helper
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured decrement spell dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,warnings,cursor,pointers,pointerIds,detailResult
 c=case;calls=[];warnings=[];cursor=0;detailResult=None;pointers={};pointerIds={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spellArray);m.wq(rules+0x110,classDefs);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,vm);m.wq(actor+0xad0,stats)
 for index,(id,spell)in enumerate(c['spells'].items()):
  ptr=spellBase+index*0x200;pointers[id]=ptr;pointerIds[ptr]=int(id);m.wi(ptr+0x178,spell['master']);m.wi(ptr+0x188,spell.get('spontaneouslyCast',0))
 u.mem_write(stats+0xd8,bytes([len(c['classes'])&255]));m.wq(stats+0xd88,abilityListPtr);m.wq(abilityListPtr,abilityArray);m.wi(abilityListPtr+8,len(c['abilities']))
 for index,entry in enumerate(c['abilities']):m.wi(abilityArray+index*12,entry['id']);m.wi(abilityArray+index*12+4,entry['remaining']);u.mem_write(abilityArray+index*12+8,bytes([entry['casterLevel']&255]))
 for index,cls in enumerate(c['classes']):
  state=stats+0xe0+index*0x188;u.mem_write(stats+index*0x188+0x25c,bytes([cls['id']&255]));m.wi(classDefs+cls['id']*0x530+0x4d8,cls['caster']);m.wi(classDefs+cls['id']*0x530+0x4ec,cls['memo'])
  for level,pool in enumerate(cls['pools']):
   m.wi(state+0xa8+level*16,len(pool));ptr=alloc(max(1,len(pool))*8);m.wq(state+0xa0+level*16,ptr);u.mem_write(stats+0x248+index*0x188+level,bytes([cls['perDay'][level]&255]))
   for slot,entry in enumerate(pool):
    if entry is None:continue
    r=alloc(16);m.wq(ptr+slot*8,r);m.wi(r,entry['id']);m.wi(r+4,entry['ready']);m.wi(r+8,entry['metamagic']);m.wi(r+12,entry['domain'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);mode=c.get('mode','wrapper');i=c.get('index',0);level=c.get('level',1);slot=c.get('slot',0)
 start={'wrapper':0x1405155c0,'slotId':0x140404aa0,'details':0x140404be0,'slotCount':0x140405770,'classInfo':0x1403fa4d0,'decrementDay':0x1403f2790}[mode]
 regs=[app,581,2,0]if mode=='wrapper'else[stats+0xe0+i*0x188,level,slot,0]if mode=='details'else[stats,i,level,slot]
 for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(register,value&0xffffffffffffffff)
 try:u.emu_start(start,m.stop,count=100000)
 except Exception as error:raise RuntimeError(f'Decrement oracle RIP={u.reg_read(UC_X86_REG_RIP):x} case={c} calls={calls}')from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop;result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 output=record(u.reg_read(UC_X86_REG_RAX))if mode=='details'else (u.reg_read(UC_X86_REG_RAX)-stats-0xe0)//0x188 if mode=='classInfo'and u.reg_read(UC_X86_REG_RAX)else None
 return dict(case=c,result=result if mode not in['classInfo','details','decrementDay']else None,output=output,calls=calls,warnings=warnings,
  perDay=[[u.mem_read(stats+0x248+index*0x188+level,1)[0]for level in range(10)]for index in range(len(c['classes']))],abilities=[dict(id=m.si(abilityArray+i*12)&0xffffffff,remaining=m.si(abilityArray+i*12+4),casterLevel=u.mem_read(abilityArray+i*12+8,1)[0])for i in range(len(c['abilities']))])
def cls(id=0,caster=1,memo=1,entries=None):
 pools=[[]for _ in range(10)];pools[1]=entries if entries is not None else[dict(id=3,ready=1,metamagic=0,domain=0)];return dict(id=id,caster=caster,memo=memo,pools=pools,perDay=[3]*10)
def fixture(**args):
 d=dict(mode='wrapper',id=3,objectId=0x80000001,popObject=1,popInt=1,creature=True,spells={'3':dict(master=3,spontaneouslyCast=0,level=1)},classes=[cls()],ready={'0:3':dict(count=1,level=1,slot=0)},uses={'0':1},abilities=[],unreadyResult=1);d.update(args);return d
if __name__=='__main__':
 rows=[]
 for popObject,popInt,creature,id in itertools.product([0,1],[0,1],[False,True],[3,0xffffffff]):rows.append(run(fixture(popObject=popObject,popInt=popInt,creature=creature,id=id)))
 for ready,domain,meta,result,readyCount in itertools.product([0,1,2,256],[0,1,256],[0,16,256],[0,2],[0,1,256]):
  rows.append(run(fixture(classes=[cls(entries=[dict(id=3,ready=ready,metamagic=meta,domain=domain)])],unreadyResult=result,ready={'0:3':dict(count=readyCount,level=1,slot=0)})))
 for caster,memo,uses,level in itertools.product([0,1,2],[0,1,2],[0,1,256],[0,1,255]):rows.append(run(fixture(classes=[cls(caster=caster,memo=memo)],uses={'0':uses},spells={'3':dict(master=3,spontaneouslyCast=1,level=level)})))
 for selectedId,selectedReady,domain,meta,count in itertools.product([1,2,3,0xffffffff],[0,1,2],[0,1,256],[0,16],[0,1]):
  classes=[cls(entries=[dict(id=selectedId,ready=selectedReady,metamagic=meta,domain=domain)])]
  rows.append(run(fixture(classes=classes,spells={'3':dict(master=3,spontaneouslyCast=1,level=1)},ready={'0:3':dict(count=0,level=1,slot=0),f'0:{selectedId}':dict(count=count,level=1,slot=0)})))
 for master,missing in itertools.product([3,4,0xffffffff],[False,True]):
  spells={'3':dict(master=master,spontaneouslyCast=1,level=1)}
  if not missing:spells['4']=dict(master=5,spontaneouslyCast=1,level=2)
  rows.append(run(fixture(spells=spells,abilities=[dict(id=5,remaining=1,casterLevel=3)])))
 for abilities in[[],[dict(id=3,remaining=0,casterLevel=3)],[dict(id=3,remaining=2,casterLevel=3)],[dict(id=3,remaining=1,casterLevel=7)],[dict(id=3,remaining=0,casterLevel=3),dict(id=3,remaining=1,casterLevel=7)],[dict(id=3,remaining=1,casterLevel=3),dict(id=3,remaining=1,casterLevel=3)]]:
  for classes in[[],[cls(caster=0)],[cls(caster=2)],[cls(memo=0)],[cls(),cls(1,memo=0)]]:rows.append(run(fixture(classes=classes,uses={},ready={},abilities=abilities)))
 for early in[0,1]:rows.append(run(fixture(classes=[cls(memo=0),cls(1)],uses={'0':early},ready={'1:3':dict(count=1,level=1,slot=0)})))
 parent=cls(entries=[]);parent['pools'][2]=[dict(id=6,ready=1,metamagic=0,domain=0)]
 rows.append(run(fixture(classes=[parent],spells={'3':dict(master=4,spontaneouslyCast=0,level=1),'4':dict(master=5,spontaneouslyCast=1,level=2)},ready={'0:6':dict(count=1,level=2,slot=0)})))
 rows.append(run(fixture(classes=[cls(entries=[dict(id=4,ready=1,metamagic=0,domain=0)]),cls(1)],ready={'0:3':dict(count=1,level=1,slot=0),'1:3':dict(count=1,level=1,slot=0)})))
 for remaining,index,level in itertools.product([0,1,255],[0,1],[0,1,255]):
  state=cls();state['perDay']=[remaining]*10;rows.append(run(fixture(mode='decrementDay',classes=[state],index=index,level=level)))
 for mode,index,level,slot in itertools.product(['slotId','slotCount','classInfo','details','decrementDay'],[0,1,256],[0,1,9,10,255,257],[0,1,255,256]):
  entry=[dict(id=0x80000001,ready=256,metamagic=16,domain=256),None]
  if mode=='details'and index!=0:continue
  rows.append(run(fixture(mode=mode,index=index,level=level,slot=slot,classes=[cls(entries=entry)])))
 out=m.root/'backups/animations/native-decrement-spell-uses-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
