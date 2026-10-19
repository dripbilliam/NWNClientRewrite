"""Complete original skill increase4332d0/decrease433190 and clearing
effect copy constructor. Object casts/death, source lookup/immunity, allocation
and child ApplyEffect are captured. Actual admission, gate order, icon43/44
payload and inherited metadata execute. Allocation success is assumed; the
original subsequently writes a null pointer if its new allocation fails.
"""
import importlib,itertools,json
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);handler,actor,source,effect,ints,child,stats,app,vtable=[m.heap+n*0x1000 for n in range(9)];copy=NativeEffectCopyFixture(m)
def snapshot(p):
 flags=int.from_bytes(u.mem_read(p+10,2),'little');return dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(p+12),creatorId=m.si(p+24)&0xffffffff,spellId=m.si(p+28),casterLevel=m.si(p+40),showIcon=m.si(p+36),exposed=m.si(p+32),integers=[m.si(m.q(p+0x48)+i*4)for i in range(8)],bypassImmunity=m.si(p+0x108))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140423570:trace.append(['copy',u.reg_read(UC_X86_REG_R8)])
 if copy.handle(a):return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:trace.append(['asCreature']);m.finish(actor if c.get('objectType',5)==5 else 0)
 elif a==0x1404953b0:trace.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x14055b3d0:trace.append(['creature',y&0xffffffff]);m.finish(source if c.get('source',True)else 0)
 elif a==0x140400ab0:trace.append(['immunity',y&255,bool(z),w&0xffffffff]);m.finish(c.get('immune',0))
 elif a==0x140c10324:m.finish(child)
 elif a==0x14048e350:trace.append(['apply',snapshot(y),z&0xffffffff,w&0xffffffff]);m.finish(1)
 elif not any(lo<=a<hi for lo,hi in[(0x140433190,0x1404332cc),(0x1404332d0,0x1404333b8),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]):raise AssertionError(f'Unmapped skill buff boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(actor+0xfc,c.get('plot',0));copy.prepare(effect);m.wq(effect,0x1234567800000011);m.wq(effect+0x48,ints);u.mem_write(effect+8,(c['type']&65535).to_bytes(2,'little')+((c.get('subtype',8)|c.get('duration',1))&65535).to_bytes(2,'little'));m.wf(effect+12,9.25)
 for off,v in[(24,0x80000042),(28,70),(40,8),(32,c.get('exposed',1)),(36,c.get('showIcon',1)),(0x108,c.get('bypass',0))]:m.wi(effect+off,v)
 for i,v in enumerate([c.get('skill',255),c.get('amount',2),28,0,0,0,0,0]):m.wi(ints+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[handler,actor,effect,c.get('loading',0)]):u.reg_write(reg,v)
 u.emu_start(0x140433190 if c['type']==56 else 0x1404332d0,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_EAX),trace=trace)
cases=[dict(type=t,objectType=obj,loading=loading,dead=dead,duration=duration,amount=amount)for t,obj,loading,dead,duration,amount in itertools.product([55,56],[5,9],[0,1],[0,1,2],[0,1,2,3,4,7],[-1,0,2])]
cases +=[dict(type=56,immune=immune,bypass=bypass,plot=plot,source=source)for immune,bypass,plot,source in itertools.product([0,1,2],[0,1],[0,1],[False,True])]
cases +=[dict(type=t,skill=skill,showIcon=show,exposed=exposed,subtype=subtype)for t,skill,show,exposed,subtype in itertools.product([55,56],[-1,0,255,256],[0,1],[0,1],[0,8,16])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-skill-buff-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions)))
