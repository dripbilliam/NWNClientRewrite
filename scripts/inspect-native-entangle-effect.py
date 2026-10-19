"""Original Entangle constructor130/apply42d5d0/remove436c20 and cutscene
immobilize constructor767/apply4286b0 (native registration has no remove94).
Original clearing copies/GetInteger/SetInteger execute. VM/base allocation,
creature/dead/possessed, immunity, feedback, clearing actions/visibility and
child application/floaty are captured lower boundaries. No full AI/movement proof.
"""
import importlib,itertools,json,struct
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,source,stats,effect,ints,vt,app,commands=[m.heap+n*0x2000 for n in range(8)];copy=NativeEffectCopyFixture(m)
ranges=[(0x14042d5d0,0x14042d944),(0x140436c20,0x140436c78),(0x1405180b0,0x140518927),(0x140425210,0x14042521c),(0x1404286b0,0x140428735)]
def snapshot(e):
 flags=int.from_bytes(u.mem_read(e+10,2),'little');return dict(id=f'{m.q(e):016x}',type=int.from_bytes(u.mem_read(e+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(e+24)&0xffffffff,spellId=m.si(e+28),casterLevel=m.si(e+40),exposed=m.si(e+32),showIcon=m.si(e+36),integers=[m.si(m.q(e+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
 global cursor,output
 if a==m.stop:u.emu_stop();return
 if a==0x140423570:calls.append(['copy',u.reg_read(UC_X86_REG_R8)&0xffffffff])
 if copy.handle(a):return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x14055b3d0:calls.append(['source',y&0xffffffff]);m.finish(source if c.get('source',True) else 0)
 elif a==0x140400ab0:calls.append(['immunity',y&255,'source' if z else None,w&0xffffffff]);m.finish(c.get('immune',0))
 elif a==0x140c10324:cursor+=0x1000;m.finish(m.heap+cursor)
 elif a==0x1404233d0:m.wq(x,101);m.wq(x+0x48,x+0x400);m.wi(x+0x40,8);m.wi(x+24,0x7f000000);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+32,1);m.wi(x+36,1);m.finish(x)
 elif a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a==0x140286330:output=snapshot(z);calls.append(['push']);m.finish(c.get('push',1))
 elif a in [0x140423770,0x140c10360]:m.finish()
 elif a==0x14048e350:assert w==0;calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
 elif a==0x1402da770:m.wi(x+0x60,z);m.finish()
 elif a==0x1402d5210:m.wi(y+0x60,m.si(x+0x60));m.finish()
 elif a==0x1403a2480:calls.append(['feedback','source' if x==source else 'actor',y&0xffffffff,{'objectIds':[m.si(z+0x60)&0xffffffff]}]);m.finish()
 elif a==0x140490b80:calls.append(['clearActions']);m.finish()
 elif a==0x140439ae0:calls.append(['floaty',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1403d54d0:calls.append(['possessed']);m.finish(c.get('possessed',0))
 elif a==0x1403d3760:calls.append(['clearVisible']);m.finish()
 elif a==0x1403dba50:calls.append(['updateVisible']);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected Entangle dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,output
 c=case;calls=[];cursor=0x30000;output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(actor+8,99);m.wi(actor+0xfc,c.get('plot',0));m.wi(actor+0x89c,c.get('pc',0));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,app);m.wi(commands+12,98)
 m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',18,8|c.get('durationType',2)));m.wi(effect+24,98);m.wi(effect+28,11);m.wi(effect+40,7);m.wi(effect+32,c.get('exposed',1));m.wi(effect+36,c.get('showIcon',1));m.wi(effect+0x108,c.get('bypass',0));copy.prepare(effect)
 for i in range(8):m.wi(ints+i*4,100+i)
 mode=c['mode'];args=[commands,767 if mode=='constructorImmobile' else 130,0,0] if mode.startswith('constructor') else [app,0 if c.get('nullObject') else actor,effect,c.get('loading',0)]
 if mode=='immobile':u.mem_write(effect+8,struct.pack('<H',94))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
 u.emu_start(dict(apply=0x14042d5d0,remove=0x140436c20,constructor=0x1405180b0,constructorImmobile=0x1405180b0,immobile=0x1404286b0)[mode],m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;return dict(case=c,result=(result^0x80000000)-0x80000000,calls=calls,output=output)
rows=[]
for creature,loading,dead,duration,plot,immune,bypass,source,exposed in itertools.product([False,True],[0,1],[0,1],range(5),[0,1],[0,1],[0,1],[False,True],[0,1]):rows.append(run(dict(mode='apply',creature=creature,loading=loading,dead=dead,durationType=duration,plot=plot,immune=immune,bypass=bypass,source=source,exposed=exposed)))
for creature,pc,possessed,null in itertools.product([False,True],[0,1,2],[0,1],[False,True]):rows.append(run(dict(mode='remove',creature=creature,pc=pc,possessed=possessed,nullObject=null)))
rows.extend([run(dict(mode='apply',showIcon=0)),run(dict(mode='constructor')),run(dict(mode='constructor',push=0))])
for loading,duration,exposed in itertools.product([0,1,-1,255],range(8),[0,1]):rows.append(run(dict(mode='immobile',loading=loading,durationType=duration,exposed=exposed)))
rows.extend([run(dict(mode='constructorImmobile')),run(dict(mode='constructorImmobile',push=0))])
out=m.root/'backups/animations/native-entangle-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions,output=str(out))))
