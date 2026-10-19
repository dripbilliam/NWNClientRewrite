"""Complete original client7f74d0 ready-spell/per-day count. Spell/class/level,
domain confirmation and metamagic-cost queries are captured lower boundaries.
Actual BYTE iteration and ready/metamagic tests execute. No gameplay effects.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);stats,rules,classes,spell,master,slots,rows=[m.heap+n*0x1000 for n in range(20,27)]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402af4a0:m.finish(0 if c.get('missingSpell')else master if (y&0xffffffff)==2 else spell);return
 if a==0x1407f0f60:m.finish(10);return
 if a==0x1402af530:m.finish(c['level']);return
 if a==0x1407ee290:m.finish(c.get('domainValid',1));return
 if a==0x1402a3f70:m.finish(c.get('metaCost',0));return
 if 0x1407f74d0<=a<0x1407f7740:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c
 c=case;t.reset(dict(format=1));sp=m.stack+0x1fe08;m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spell);m.wq(rules+0x110,classes);m.wi(classes+10*0x530+0x4ec,c['memo']);m.wi(spell+0x178,c.get('master',1));m.wi(master+0x178,2);u.mem_write(stats+0x69,bytes([c.get('classCount',8)]))
 level=c['domain']or c['level'];level=(level+c.get('metaCost',0))&255;index=c['index']
 if index<8 and level<10:
  p=stats+index*0x150;m.wq(p+0x148+(level+10)*0x10,slots);m.wi(p+0x1f0+level*0x10,len(c['slots']));u.mem_write(p+0x288+level,bytes([c['perDay']]))
  for i,s in enumerate(c['slots']):
   if s is None:m.wq(slots+i*8,0);continue
   q=rows+i*0x30;m.wq(slots+i*8,q);m.wi(q,s['spell']);m.wi(q+4,s['ready']);u.mem_write(q+8,bytes([s['metamagic']]))
 m.wi(sp+0x28,c['meta']);value=w.call(0x1407f74d0,[stats,1,index,c['domain']])&255;return dict(case=c,result=value)
pools=[[],[None],[dict(spell=1,ready=1,metamagic=0)],[dict(spell=1,ready=1,metamagic=1),dict(spell=1,ready=2,metamagic=2),dict(spell=2,ready=1,metamagic=3),dict(spell=1,ready=0,metamagic=255)]]
cases=[dict(index=i,level=1,domain=d,meta=meta,memo=memo,perDay=perDay,slots=pool,metaCost=1 if meta else 0)for i,d,meta,memo,perDay,pool in itertools.product([0,7,8],[0,2],[0,1,3,255],[0,1],[0,9,255],pools)]
base=dict(index=0,level=1,domain=0,meta=0,memo=1,perDay=9,slots=pools[-1])
for change in [dict(level=255),dict(domain=2,domainValid=0),dict(missingSpell=True),dict(classCount=0),dict(master=2)]:cases.append(base|change)
observations=[run(c)for c in cases];output=m.root/'backups/animations/native-network-spell-use-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=observations),indent=2)+'\n');print(json.dumps(dict(cases=len(observations),output=str(output))))
