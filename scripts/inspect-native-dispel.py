"""Untouched dispel handlers14042c720/14042cbd0. Capture object/level,
RNG, allocations, active spell lookup, message and deferred event boundaries.
Effects stay live until separately scheduled event14; no recursive removals.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,source,stats,effect,ints,vt,app,rules,effectRows,client=[m.heap+n*0x1000 for n in range(1,11)]
def hook(u,a,n,_):
 global allocation,draw
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(source if c.get('sourceType',5)==5 else 0)
 elif a in [0x14055b850,0x14055b960,0x14055b810]:m.finish(app)
 elif a==0x140296470:m.wq(z,source if c.get('sourceExists',True) else 0);m.finish(0)
 elif a==0x1404035c0:m.finish(c.get('totalLevel',7))
 elif a==0x140423fc0:m.finish(m.si(ints))
 elif a==0x1402ad680:
  value=c.get('rolls',[20])[min(draw,len(c.get('rolls',[20]))-1)];draw+=1;calls.append(['roll',1,20]);m.finish(value)
 elif a==0x1402af4a0:m.finish(effect if (y&0xffffffff) in c.get('validSpells',[1,2,3]) else 0)
 elif a==0x1405570b0:
  payload=m.q(rsp+0x38);calls.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,0,{'id':str(m.q(payload))}]);m.finish()
 elif a==0x140c10324:allocation+=1;ptr=m.heap+0x30000+allocation*0x1000;messages[ptr]={'objects':[],'integers':[]};m.finish(ptr)
 elif a==0x140c4f038:
  allocation+=1;ptr=m.heap+0x30000+allocation*0x1000
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(z or y,0x800))))
  m.finish(ptr)
 elif a in [0x1402da770,0x1402da730]:
  key='objects' if a==0x1402da770 else 'integers';values=messages[x][key];i=y&0xffffffff
  while len(values)<=i:values.append(0)
  values[i]=z&0xffffffff;m.finish()
 elif a==0x14055b390:
  oid=y&0xffffffff
  if oid in c.get('clients',[99,98]):m.wi(client+0x48,oid);m.finish(client)
  else:m.finish(0)
 elif a==0x1404cf090:calls.append(['message',y&0xffffffff,z&255,json.loads(json.dumps(messages[w]))]);m.finish()
 elif a in [0x140c4f024,0x140c10360]:m.finish()
 elif not 0x14042c720<=a<0x14042d00f:raise AssertionError(f'Uncaptured dispel dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,messages,allocation,draw
 c=case;calls=[];messages={};allocation=0;draw=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(actor+0x150,effectRows);m.wi(actor+0x158,len(c['effects']));m.wi(actor+8,99);m.wi(source+8,c.get('sourceId',98));m.wq(source,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(source+0xad0,stats);m.wi(effect+0x18,c.get('sourceId',98));m.wq(effect+0x48,ints);m.wi(ints,c.get('level',10))
 for i,e in enumerate(c['effects']):
  ptr=m.heap+0x10000+i*0x200;m.wq(effectRows+i*8,ptr);m.wq(ptr,int(e['id']));m.wi(ptr+0x28,e.get('casterLevel',1));m.wi(ptr+0x1c,e.get('spellId',1));u.mem_write(ptr+0xa,struct.pack('<H',e.get('subtype',8)|e.get('durationType',2)))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[app,actor,effect,0]):u.reg_write(reg,v)
 u.emu_start(0x14042cbd0 if c.get('best') else 0x14042c720,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls)
rows=[]
for best,level,caster,roll,subtype,duration in itertools.product([False,True],[-1,0,1,10,20],[-1,0,1,10,20],[1,10,20],[0,8,16,24],[0,1,2,3,4]):
 rows.append(run(dict(best=best,level=level,rolls=[roll],effects=[dict(id='1',casterLevel=caster,subtype=subtype,durationType=duration)])))
for best,clients,sourceId in itertools.product([False,True],[[],[99],[98],[98,99]],[98,99]):
 rows.append(run(dict(best=best,clients=clients,sourceId=sourceId,level=10,rolls=[1,20,1,20],effects=[dict(id='1',casterLevel=30),dict(id='1',casterLevel=1),dict(id='2',casterLevel=0,spellId=2),dict(id='3',casterLevel=10,spellId=-1)])))
for best in [False,True]:
 for missing in [False,True]:rows.append(run(dict(best=best,level=0,sourceExists=not missing,sourceType=9,effects=[dict(id='1')])))
 rows.append(run(dict(best=best,level=0,effects=[])))
 rows.append(run(dict(best=best,level=1,rolls=[1,20],effects=[dict(id=str(i%19+1),casterLevel=i%3,spellId=i%4) for i in range(50)])))
out=m.root/'backups/animations/native-dispel-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
