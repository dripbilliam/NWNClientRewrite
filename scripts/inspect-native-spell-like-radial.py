"""Untouched innate radial traversal1409a3e80, count1408017c0 and selection
1409a4610. Allocation/icon/string/presentation, spell lookup and target admission
are captured boundaries. Target admission is independently instruction-compared.
Client pool is synthetic; replicated client storage/network sync are not tested.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
context,actor,pool,rows,rules,manager,spellbase,seen,strings=[m.heap+n*0x1000 for n in range(1,10)]
spellbase,seen,strings=m.heap+0x10000,m.heap+0x18000,m.heap+0x19000
ranges=[(0x1409a3e80,0x1409a4213),(0x1408017c0,0x1408017ff),(0x1409a4610,0x1409a469c)]
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406ac1a0:m.finish(actor if c.get('controlled',True) else 0)
 elif a==0x1402af4a0:
  id=y&0xffffffff;ptr=spellbase+(id%16)*0x200;lookup[id]=ptr;m.wi(ptr+0x10,id+1000);m.finish(0 if id in c.get('missing',[]) else ptr)
 elif a==0x140c4f038:m.finish(seen)
 elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x20000+allocation*0x100)
 elif a==0x1409aaf70:m.finish(x)
 elif a==0x14016c810:texts[x]=y&0xffffffff;m.finish(x)
 elif a==0x1401e4720:counts[x]=texts[y];m.finish()
 elif a==0x1401fa010:
  entries.append(dict(slot=y&0xffffffff,spellId=(w-1000)&0xffffffff,uses=counts[z],packed=m.q(rsp+0x38),disabled=False));m.finish()
 elif a==0x1409a4910:m.finish(int(y&0xffffffff not in c.get('denied',[])))
 elif a==0x1401f8b30:next(e for e in entries if e['slot']==y)['disabled']=True;m.finish()
 elif a==0x1401faa40:entries.append(dict(slot=y&0xffffffff,next=m.q(rsp+0x38)));m.finish()
 elif a==0x140804e20:
  calls.append(dict(spellId=y&0xffffffff,casterLevel=z&255,targetId=w&0xffffffff,position=[m.rf(m.q(rsp+0x28)+i*4) for i in range(3)]));m.finish()
 elif a==0x140868bd0:calls.append(dict(assignment=True));m.finish()
 elif a in [0x140c10370,0x140c4f024]:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured innate radial dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,selection=False):
 global c,entries,calls,allocation,texts,counts,lookup
 c=case;entries=[];calls=[];allocation=0;texts={};counts={};lookup={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wq(context+0x890,1 if c.get('assignment') else 0)
 values=c.get('pool',[]);m.wq(actor+0x478,0 if c.get('nullPool') else pool);m.wq(pool,rows);m.wi(pool+8,len(values))
 for i,row in enumerate(values):m.wi(rows+i*12,row[0]);m.wi(rows+i*12+4,row[1]);u.mem_write(rows+i*12+8,bytes([row[2]&255]))
 for i,v in enumerate([1.25,2.5,3.75]):m.wf(context+0x880+i*4,v)
 m.wi(context+0x88c,99);rsp=m.stack+0x1fc08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,context);u.reg_write(UC_X86_REG_RDX,c.get('packed',0) if selection else 0);u.reg_write(UC_X86_REG_R8,c.get('start',0))
 u.emu_start(0x1409a4610 if selection else 0x1409a3e80,m.stop,count=200000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,entries=entries,calls=calls)
pools=[[],[[0,1,0]],[[0,0,8],[0,1,8]],[[0,0,1],[0,1,2]],[[i,1,i] for i in range(12)],[[i//3,i%2,8] for i in range(30)],[[0,1,8]]*256,[[i,1,i] for i in range(7)]+[[0,1,0],[8,1,8],[8,0,8]]]
cases=[dict(pool=pool,start=start,missing=missing,denied=denied,assignment=assign) for pool,start,missing,denied,assign in itertools.product(pools,[0,1,4,7,12],[[],[0,2,5]],[[],[0,1,4]],[False,True])]
cases += [dict(pool=[[0,1,8]],nullPool=True),dict(pool=[[0,1,8]],controlled=False)]
results=[run(c) for c in cases]
selections=[run(dict(packed=id|(level<<24),assignment=assignment),True) for id,level,assignment in itertools.product([0,100,65535],[0,1,8,15,16,255],[False,True])]
out=m.root/'backups/animations/native-spell-like-radial-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=results,selections=selections))+'\n');print(json.dumps(dict(rows=len(results),selections=len(selections),output=str(out))))
