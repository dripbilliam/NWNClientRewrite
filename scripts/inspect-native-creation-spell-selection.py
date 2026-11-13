"""Execute complete original spell-tab initialization9ce190 and OK admission
9c6e70 with captured current-class/known-count/gain/minimum/known-capacity
getters and GUI service boundaries. Getters have separate original evidence;
this corpus does not execute full table loading, GUI list construction or
recommendation/commit. No live process, credentials, server or GPU.
"""
import importlib.util,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,actor,stats,rule,cls,spell_array,spells,twodas,school_table,vtable,color=[m.heap+n for n in[0x1000,0x5000,0x9000,0xd000,0x10000,0x16000,0x20000,0x40000,0x41000,0x50000,0x51000]]
ranges=[(0x1409ce190,0x1409ce72e),(0x1409c6e70,0x1409c7007)]
case={};known=[];calls=[];selected=None
def byte(a,v):u.mem_write(a,bytes([v&255]))
def word(a,v):u.mem_write(a,(v&65535).to_bytes(2,'little'))
def remaining(level):return max(0,case['capacity'][level]-len(known[level])) if level<10 else 0
def hook(_u,a,_n,_):
 global selected
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop:u.emu_stop();return
 if a==0x140800c90:m.finish(actor)
 elif a==0x1407f0f60:m.finish(0)
 elif a==0x1407f1080:m.finish(case['classLevel'])
 elif a==0x1407ec3a0:m.finish(case['intModifier'])
 elif a==0x1407f66e0:m.finish(len(known[z&255]) if (z&255)<10 else 0)
 elif a==0x1407f5c50:m.finish(known[z&255][w&255])
 elif a==0x1407ebed0:
  id=z&0xffffffff;level=case['spells'][id]['level'];calls.append(['learn',id])
  if id not in known[level]:known[level].append(id)
  m.finish()
 elif a==0x1407eec90:
  # Ability calculation is a separate helper boundary for known capacity.
  u.mem_write(m.q(u.reg_read(UC_X86_REG_RSP)+0x28),bytes([11]));m.finish()
 elif a==0x140299e70:m.finish(case['capacity'][z&255] if (z&255)<10 else 0)
 elif a==0x1407f6b20:m.finish(case['gain'][z&255])
 elif a==0x1407f7130:m.finish(int(case['minimum'][z&255]))
 elif a==0x1407ee050:m.finish(remaining(y&255))
 elif a==0x1407f69a0:m.finish(case['school'])
 elif a==0x1402af4a0:m.finish(spells+(y&0xffffffff)*0x1b8)
 elif a==0x1402af530:m.finish(case['spells'][(x-spells)//0x1b8]['level'])
 elif a==0x1401a7010: m.wi(w,case['opposition'] or 0);m.finish(int(case['opposition']is not None))
 elif a==0x140c10368:m.finish(m.heap+0x80000)
 elif a==0x140c10370:m.finish()
 elif a==0x1401e5c60:m.wi(x+8,(m.si(x+8)&~1)|(0 if y else 1));m.finish()
 elif a==0x1401eb800:m.wi(x+8,(m.si(x+8)&~1)|(0 if y else 1));m.finish()
 elif a in[0x1401eb5c0,0x1401e5d20]:m.finish()
 elif a==0x1401eff30:selected=y&0xffffffff;m.wi(x+0x10,selected);m.finish()
 elif a==0x1409caae0:
  selected=y&0xffffffff;byte(panel+0x19de,selected)
  if not case['memorizes']:word(panel+0x19dc,remaining(selected))
  m.finish()
 elif a==m.stop+0x10:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original spell dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,known,calls,selected
 case=c;known=[row.copy()for row in c['known']];calls=[];selected=None
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor+0x3b0,stats);m.wq(0x1412df8f8,rule);m.wq(rule+0x110,cls);m.wq(rule+0xd0,spell_array);m.wq(rule+0x130,twodas);m.wq(twodas+0x290,school_table);m.wi(spell_array,len(c['spells']));m.wi(cls+0x4ec,int(c['memorizes']));m.wi(cls+0x4fc,int(c['learnScroll']));m.wi(cls+0x4f8,int(c['pickSchool']));byte(stats+0x79,c['baseInt']);word(panel+0x19dc,c['storedRemaining']);m.wq(vtable+0x78,m.stop+0x10);m.wq(color,vtable);m.wq(panel+0x6b8,color)
 for id,spell in enumerate(c['spells']):byte(spells+id*0x1b8+0x29,spell['school'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel);u.reg_write(UC_X86_REG_RDX,int(c['keepBudget']))
 try:u.emu_start(0x1409ce190,m.stop,count=250000)
 except Exception:
  print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(input=c,output=dict(remaining=int.from_bytes(u.mem_read(panel+0x19dc,2),'little'),selected=selected,tabs=[not bool(m.si(panel+0x12f8+level*0xb0+8)&1)for level in range(10)],finished=[m.si(panel+0x19e0+level*4)!=0 for level in range(10)],known=known,learned=calls,ok=not bool(m.si(panel+0x5e0)&1)))
if __name__=='__main__':
 out=m.root/'godot-client/reports/native-creation-spell-selection-original-v1.json';assert not out.exists(),'Preserve original evidence'
 rng=random.Random(90210);rows=[]
 for at in range(480):
  definitions=[dict(id=id,level=rng.choice([0,0,1,1,2,3,5,9,255]),school=id%4)for id in range(at%19)]
  known=[[]for _ in range(10)]
  for spell in definitions:
   if spell['level']<10 and rng.randrange(5)==0:known[spell['level']].append(spell['id'])
  c=dict(memorizes=bool(at%2),learnScroll=bool((at//2)%2),classLevel=[1,2,40][at%3],intModifier=[-2,0,2,127,128,255][at%6],baseInt=[8,9,10,14][at%4],keepBudget=bool((at//4)%2),storedRemaining=[0,1,3,255,65535][at%5],school=at%3,pickSchool=bool((at//3)%2),opposition=[None,0,2,255][at%4],spells=definitions,known=known,capacity=[rng.choice([0,0,1,2,4])for _ in range(10)],gain=[rng.choice([0,1,2,255])for _ in range(10)],minimum=[bool(rng.randrange(2))for _ in range(10)])
  rows.append(run(c))
 out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,ranges=[[hex(a),hex(b)]for a,b in ranges],rows=rows),indent=2)+'\n')
 print(json.dumps(dict(output=str(out),cases=len(rows),gpu=False,serverConnections=0)))
