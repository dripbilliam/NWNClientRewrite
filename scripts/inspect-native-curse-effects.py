"""Original Curse apply/remove and Curse/Ethereal VM constructors. Full original
clearing copy constructor and integer accessors execute. Allocation/base ctor,
VM, registry/casts, immunity, feedback, child application and AI event insertion
are captured lower boundaries; this is not full engine/event/renderer acceptance.
"""
import importlib,itertools,json,struct
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,source,stats,effect,ints,vt,app,commands=[m.heap+n*0x2000 for n in range(8)]
copy=NativeEffectCopyFixture(m)
ranges=[(0x1404281a0,0x140428659),(0x140436290,0x140436296),(0x1405180b0,0x140518927),(0x140519e10,0x140519efb),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]
def snapshot(e):
 flags=int.from_bytes(u.mem_read(e+10,2),'little')
 return dict(id=f'{m.q(e):016x}',type=int.from_bytes(u.mem_read(e+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(e+24)&0xffffffff,spellId=m.si(e+28),casterLevel=m.si(e+40),exposed=m.si(e+32),showIcon=m.si(e+36),integers=[m.si(m.q(e+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
 global cursor,popped,output
 if a==m.stop:u.emu_stop();return
 if copy.handle(a):return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x14055b3d0:calls.append(['source',y&0xffffffff]);m.finish(source if c.get('source',True) else 0)
 elif a==0x140400ab0:calls.append(['immunity',y&255,'source' if z else None,w&0xffffffff]);m.finish(c.get('immune',0))
 elif a==0x140c10324:cursor+=0x1000;m.finish(m.heap+cursor)
 elif a==0x1404233d0:
  m.wq(x,101);m.wq(x+0x48,x+0x400);m.wi(x+0x40,8);m.wi(x+24,0x7f000000);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+32,1);m.wi(x+36,1);m.finish(x)
 elif a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a==0x140286110:
  calls.append(['pop']);popped+=1;m.wi(y,c.get('values',[1]*6)[popped-1]);m.finish(0 if c.get('failPop')==popped else 1)
 elif a==0x140286330:output=snapshot(z);calls.append(['push']);m.finish(c.get('push',1))
 elif a in [0x140423770,0x140c10360]:m.finish()
 elif a==0x14048e350:assert w==0;calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405570b0:
  calls.append(['event',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30)&0xffffffff,snapshot(m.q(rsp+0x38))]);m.finish(1)
 elif a==0x1402da770:m.wi(x+0x60,z);m.finish()
 elif a==0x1402d5210:m.wi(y+0x60,m.si(x+0x60));m.finish()
 elif a==0x1403a2480:calls.append(['feedback','source' if x==source else 'actor',y&0xffffffff,{'objectIds':[m.si(z+0x60)&0xffffffff]}]);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected curse dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,popped,output
 c=case;calls=[];cursor=0x30000;popped=0;output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(actor+8,99);m.wi(actor+0xfc,c.get('plot',0));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,app);m.wi(commands+12,98)
 m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',45,8|c.get('durationType',2)));m.wi(effect+24,98);m.wi(effect+28,11);m.wi(effect+40,7);m.wi(effect+32,1);m.wi(effect+36,c.get('showIcon',1));m.wi(effect+0x108,c.get('bypass',0));copy.prepare(effect)
 for i,v in enumerate(c.get('values',[1,2,3,4,5,6])):m.wi(ints+i*4,v)
 mode=c['mode'];entry={'apply':0x1404281a0,'remove':0x140436290,'curse':0x1405180b0,'ethereal':0x140519e10}[mode]
 args=[commands,138,c.get('argc',6),0] if mode=='curse' else [commands,666,0,0] if mode=='ethereal' else [app,actor,effect,c.get('loading',0)]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v&0xffffffffffffffff)
 u.emu_start(entry,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,result=(result^0x80000000)-0x80000000,calls=calls,output=output)
rows=[]
for creature,loading,dead,duration,plot,immune,bypass,source in itertools.product([False,True],[0,1],[0,1],range(5),[0,1],[0,1],[0,1],[False,True]):rows.append(run(dict(mode='apply',creature=creature,loading=loading,dead=dead,durationType=duration,plot=plot,immune=immune,bypass=bypass,source=source)))
for values,showIcon in itertools.product([[0]*6,[-1,0,2,3,4,5],[-2147483648,2147483647,-10,0,99,1]],[0,1]):rows.append(run(dict(mode='apply',values=values,showIcon=showIcon)))
for argc,values in itertools.product([0,1,6],[[1]*6,[0,-1,2,2147483647,-2147483648,99]]):rows.append(run(dict(mode='curse',argc=argc,values=values)))
for i in range(1,7):rows.append(run(dict(mode='curse',failPop=i)))
rows.extend([run(dict(mode='curse',push=0)),run(dict(mode='ethereal')),run(dict(mode='ethereal',push=0)),run(dict(mode='remove'))])
out=m.root/'backups/animations/native-curse-effects-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions,output=str(out))))
