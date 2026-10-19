"""Complete original RemoveSleepEffects39eb90 and
RemoveCharmEffectsByFactionID39e0d0. Effect payload access, canonical lookup,
source casts, reputation mutation and shared-ID removal are captured boundaries.
Native live scans/restarts, protected-sleep second pass, temporary charm gates,
deferred ordered ID collection and return values execute unchanged.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,pool,app,array,source,stats,vtable=[m.heap+n*0x1000 for n in range(7)]
def storePool():
 m.wi(actor+0x158,len(effects))
 for i,e in enumerate(effects):m.wq(pool+i*8,e)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b850:m.finish(array if c.get('array',True)else 0)
 elif a==0x140296470:
  trace.append(['object',y&0xffffffff]);exists=y&0xffffffff==100 and c.get('source',True);m.wq(z,source if exists else 0);m.finish(0 if exists else 1)
 elif a==m.stop+0x100:m.finish(source if c.get('creature',True)else 0)
 elif a==0x140423fc0:m.finish(m.si(m.q(x+0x48)+(y&0xffffffff)*4))
 elif a==0x140498280:
  trace.append(['remove',f'{y:016x}']);effects[:]=[e for e in effects if m.q(e)!=y];storePool();m.finish()
 elif a==0x1403d0c50:trace.append(['reputation',100,y&0xffffffff,z&0xffffffff,w&0xffffffff,m.rf(rsp+0x28)]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in[(0x14039e0d0,0x14039e2d7),(0x14039eb90,0x14039ecac),(0x140425210,0x14042521c)]):raise AssertionError(f'Unmapped damage status boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,effects,trace
 c=case;effects=[];trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(actor+8,99);m.wq(actor+0x150,pool);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(source,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wq(source+0xad0,stats);m.wi(stats+0xc4,c.get('sourceFaction',1))
 for i,e in enumerate(c['effects']):
  ptr=m.heap+0x10000+i*0x1000;effects.append(ptr);m.wq(ptr,e.get('id',10+i));u.mem_write(ptr+8,(e.get('type',8)&65535).to_bytes(2,'little')+(e.get('durationType',1)&7).to_bytes(2,'little'));m.wq(ptr+0x48,ptr+0x200);m.wi(ptr+0x40,8);m.wi(ptr+0x18,e.get('creator',100));m.wi(ptr+0x200,e.get('kind',9));m.wi(ptr+0x204,e.get('protected',0))
 storePool();rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,c.get('faction',1),c.get('adjustment',-100)&0xffffffff]):u.reg_write(reg,v)
 u.emu_start(0x14039eb90 if c['mode']=='sleep'else 0x14039e0d0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,trace=trace,effects=[dict(id=f'{m.q(e):016x}',type=int.from_bytes(u.mem_read(e+8,2),'little'),kind=m.si(m.q(e+0x48)),protected=m.si(m.q(e+0x48)+4))for e in effects],result=u.reg_read(UC_X86_REG_EAX)if c['mode']=='charm'else None)
cases=[]
for mode,kind,duration,protected in itertools.product(['sleep','charm'],range(11),[0,1,2,3,4],[0,1,2]):cases.append(dict(mode=mode,effects=[dict(kind=kind,durationType=duration,protected=protected)]))
for mode,rows in itertools.product(['sleep','charm'],[[],[dict(kind=9),dict(kind=9,protected=1),dict(kind=9)],[dict(type=9),dict(kind=9)],[dict(kind=1),dict(kind=7),dict(kind=9)],[dict(kind=9,id=77),dict(kind=9,id=77),dict(kind=9,protected=1)]]):cases.append(dict(mode=mode,effects=rows))
for key,values in dict(array=[False],source=[False],creature=[False],sourceFaction=[0,2],adjustment=[0,1,-1,2147483647],creator=[99]).items():
 for value in values:cases.append(dict(mode='charm',effects=[dict(kind=1,creator=value if key=='creator'else 100),dict(kind=7)],**({}if key=='creator'else{key:value})))
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-damage-status-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
