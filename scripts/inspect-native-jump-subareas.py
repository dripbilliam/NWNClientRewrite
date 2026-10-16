"""Original jump subarea and following-AoE owners. Point queries, subarea
events/AoE removal, registry and list allocation helpers are captured lower
boundaries. Ordered jumps, gates, count snapshots and list copies execute.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,aoe,area,otherArea,app,server,point,vtable,old,following,temp=[m.heap+n*0x2000 for n in range(1,12)]
def readlist(a):return [m.si(m.q(a)+i*4)&0xffffffff for i in range(m.si(a+8))]
def putlist(a,values,ptr):
 m.wq(a,ptr);m.wi(a+8,len(values));m.wi(a+12,max(64,len(values)))
 for i,v in enumerate(values):m.wi(ptr+i*4,v)
def vec(a):return [m.rf(a+i*4) for i in range(3)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14055b850:m.finish(server)
 elif a==0x140296470:calls.append(['areaById',y&0xffffffff]);m.wq(z,area);m.finish(0)
 elif a==m.stop+0x10:m.finish(area)
 elif a==0x14036c990:calls.append(['in',vec(y)]);putlist(z,c.get('next',[]),temp);m.finish(c.get('found',0))
 elif a==0x14055b2f0:calls.append(['aoe',y&0xffffffff]);m.finish(0 if (y&0xffffffff)==666 else aoe)
 elif a==0x1404f7a70 and c['operation']=='subareas':
  calls.append(['jump',None if y==0 else 88,vec(z)]);putlist(actor+0x518,c.get('mutated',c.get('old',[])),old);m.finish()
 elif a==0x1403d5890:calls.append(['changes',readlist(y),z,w&0xffffffff]);m.finish(c.get('changed',1))
 elif a==0x14007c830:putlist(x,[0]*y,old);m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140c4f024:m.finish()
 elif a==0x140c4f038:
  if x:u.mem_write(temp,bytes(u.mem_read(x,min(z,0x100))))
  m.finish(temp)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('anchor',True) else 0)
 elif a==0x140494e80:calls.append(['area']);m.finish(area)
 elif a==0x140175070:m.finish(int((y&0xffffffff) in readlist(x)))
 elif a==0x1400b5450:
  values=readlist(x);values.remove(y&0xffffffff);putlist(x,values,old);m.finish()
 elif a==0x14008ae10:values=readlist(x);values.append(y&0xffffffff);putlist(x,values,old);m.finish()
 elif a==0x140115890:calls.append(['warning','InSubAreasArray does not contain specified area']);m.finish()
 elif a==0x1404f8c40:calls.append(['removeSubareas',y&0xffffffff,readlist(actor+0x518)]);putlist(actor+0x518,c.get('mutated',[]),old);m.finish()
 elif a==0x14049bb40:calls.append(['position',vec(y),z&0xffffffff]);m.finish()
 elif a==0x1404f94c0:calls.append(['updateSubareas',y,readlist(actor+0x518)]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403db4a0,0x1403db6fc),(0x1404f7a70,0x1404f7b90)]):raise AssertionError(f'Uncaptured jump-subarea dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(area,vtable);m.wq(vtable+0x50,m.stop+0x10)
 m.wi(aoe+8,77);m.wi(aoe+0x334,99);putlist(actor+0x518,c.get('old',[]),old);putlist(actor+0x508,c.get('following',[]),following)
 for i,v in enumerate([1,2,3]):m.wf(point+i*4,v)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['operation']=='subareas':u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,point);u.reg_write(UC_X86_REG_R8,88 if c.get('area',True) else 0x7f000000);start=0x1403db4a0
 else:u.reg_write(UC_X86_REG_RCX,aoe);u.reg_write(UC_X86_REG_RDX,area if c.get('same',True) else otherArea);u.reg_write(UC_X86_REG_R8,point);start=0x1404f7a70
 try:u.emu_start(start,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,membership=readlist(actor+0x518),**(dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff) if c['operation']=='subareas' else {}))
if __name__=='__main__':
 rows=[run(dict(operation='subareas',area=area,old=old,next=next,found=found,following=following,changed=changed,mutated=mutated)) for area,old,next,found,following,changed,mutated in itertools.product([False,True],[[],[7]],[[],[8,77]],[0,1],[[],[77],[77,77,666],list(range(1,21))],[0,1,2],[[],[9]])]
 rows += [run(dict(operation='aoe',anchor=anchor,same=same,old=old,mutated=mutated)) for anchor,same,old,mutated in itertools.product([False,True],[False,True],[[],[77],[7,77,8]],[[],[77],[8]])]
 out=m.root/'backups/animations/native-jump-subarea-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
