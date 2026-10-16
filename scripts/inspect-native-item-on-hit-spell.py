"""Complete unchanged ApplyOnHitCastSpell1403de8a0..1403deaec. Capture
the table output, spell lookup, payload allocation/copy, area/attack lookups
and append boundary. Lower table/string/allocator/list helpers are isolated;
this oracle does not execute the impact script or prove visual presentation.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
actor,target,prop,item,app,rules,tables,table,spell,payload,string,area,round_,attack=[m.heap+i*0x1000 for i in range(14)]

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(string)
 elif a==0x1401a7010:
  trace.append(['query',y,'SpellIndex',c['status'],c['spellId']]);m.wi(q,c['spellId']);m.finish(c['status'])
 elif a==0x1402af4a0:trace.append(['spell',y&0xffffffff]);m.finish(spell if c['validSpell'] else 0)
 elif a==0x140c10324:trace.append(['allocate',x]);m.finish(payload if c['allocate'] else 0)
 elif a==0x14003d8c0:
  trace.append(['copyScript','test_impact']);m.wq(x,string+0x100);m.wi(x+8,11);m.finish(x)
 elif a==0x140494e80:trace.append(['area','actor']);m.finish(area)
 elif a==0x140375e40:trace.append(['attack',y&0xffffffff]);m.finish(attack)
 elif a==0x1403de410:
  trace.append(['append',1 if x==attack+0xc0 else 2,dict(spellId=m.si(y),featId=int.from_bytes(u.mem_read(y+4,2),'little'),casterId=m.si(y+8)&0xffffffff,targetId=m.si(y+0xc)&0xffffffff,itemId=m.si(y+0x10)&0xffffffff,position=[m.rf(y+0x14+i*4)for i in range(3)],script='test_impact',areaId=m.si(y+0x30)&0xffffffff,casterLevel=m.si(y+0x34))]);m.finish()
 elif not 0x1403de8a0<=a<0x1403deaec:raise RuntimeError(f'Unmapped item spell owner {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,app);m.wq(app+0x130,tables);m.wq(tables+0x3d0,table);m.wq(app+0xd0,rules)
 m.wi(actor+8,0x80000042);m.wi(target+8,91);m.wi(item+0x50,123);m.wi(item+0x40,c['base']);m.wi(prop,c['type']|(c['subtype']&65535)<<16);m.wi(prop+4,(c['cost']&65535)<<16)
 m.wi(actor+0xa0,0x7f000000 if c['invalidArea'] else 55);m.wi(area+0x140,55);m.wq(actor+0x880,round_);u.mem_write(round_+0x2f2c,bytes([c['attack']&255]))
 for obj,point in [(actor,[1.25,-2.5,3.75]),(target,[-4.5,5.25,-6.75])]:
  for i,v in enumerate(point):m.wf(obj+0xa4+i*4,v)
 m.wq(spell+0x58,string+0x100);m.wi(spell+0x60,11)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,target,prop,item]):u.reg_write(reg,value)
 u.emu_start(0x1403de8a0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,trace=trace)
default=dict(base=22,type=82,subtype=124,cost=9,status=1,spellId=542,validSpell=True,allocate=True,invalidArea=False,attack=0)
rows=[run(default|dict(base=base,cost=cost,status=status,invalidArea=invalidArea,attack=257))for base,cost,status,invalidArea in itertools.product(list(range(0,85))+[-1,0x7fffffff],[0,9,65535],[0,1],[False,True])]
rows.extend(run(default|case)for case in [dict(type=81),dict(type=83),dict(validSpell=False),dict(allocate=False),dict(subtype=65535,spellId=-1),dict(base=16,subtype=65537,cost=65537,spellId=0)])
out=m.root/'backups/animations/native-item-on-hit-spell-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
