"""Untouched blindness/darkness application and removal, plus vision filter
and miss-chance admission. Complete original clearing copy constructor executes.
Captured allocation, immunity and ApplyEffect
children. Child application does not execute recursively in this comparison.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_effect_copy_fixture import NativeEffectCopyFixture
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,source,stats,effect,ints,vt,app,rules,rows=[m.heap+n*0x1000 for n in range(1,10)]
copy_fixture=NativeEffectCopyFixture(m)
owners={'blind':0x140427bb0,'inactive':0x140427f40,'dark':0x14042a590,'deaf':0x14042a790,'removeBlind':0x140435fe0,'removeDark':0x140436590,'filter':0x140434e80,'miss':0x14042efa0}
ranges=[(0x140427bb0,0x140428000),(0x14042a590,0x14042aa3b),(0x140435fe0,0x140436190),(0x140436590,0x1404366a0),(0x140434e80,0x140435050),(0x14042efa0,0x14042f040)]
def snapshot(addr):return {'type':int.from_bytes(u.mem_read(addr+8,2),'little'),'integers':list(struct.unpack('<8i',u.mem_read(m.q(addr+0x48),32))),'exposed':m.si(addr+0x20),'showIcon':m.si(addr+0x24)}
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 if copy_fixture.handle(a):return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:m.finish(actor if c.get('kind',5)==5 else 0)
 elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True) else 0)
 elif a==0x140402f80:m.finish(c.get('dm',0))
 elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immune',0))
 elif a==0x1404953b0:m.finish(c.get('dead',0))
 elif a==0x140423fc0:m.finish(m.si(m.q(x+0x48)+(y&0xffffffff)*4)&0xffffffff)
 elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x10000+allocation*0x1000)
 elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
 elif a==0x1402da770:messages[x]={'objects':[z&0xffffffff]};m.finish()
 elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
 elif a==0x140439ae0:calls.append(['floaty',z&0xffffffff,y&0xffffffff]);m.finish()
 elif a==0x1402ae870:m.finish(0)
 elif a==0x1402a4130:m.finish(c.get('chance',50))
 elif a in [0x140423770,0x140c10360]:m.finish(1)
 elif not any(lo<=a<hi for lo,hi in ranges+[(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,messages
 c=case;calls=[];allocation=0;messages={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(actor+8,99);m.wi(source+8,98);m.wq(actor+0xad0,stats);m.wi(actor+0xfc,c.get('plot',0));u.mem_write(actor+0x770,bytes([c.get('flags',0)]));m.wq(effect,77);m.wq(effect+0x48,ints);m.wi(effect+0x20,1);m.wi(effect+0x24,1);m.wi(effect+0x18,98);m.wi(effect+0x108,c.get('bypass',0));m.wi(ints,c.get('mode',16));u.mem_write(effect+8,struct.pack('<HH',c.get('type',73),8|c.get('durationType',2)))
 effects=[effect]+[m.heap+0xa000+i*0x200 for i in range(len(c.get('remaining',[])))];m.wq(actor+0x150,rows);m.wi(actor+0x158,len(effects));u.mem_write(stats+0xdb0,b'\0\0')
 for i,addr in enumerate(effects):
  m.wq(rows+i*8,addr)
  if i>0:m.wq(addr+0x48,addr+0x100);u.mem_write(addr+8,struct.pack('<H',73));m.wi(addr+0x100,c['remaining'][i-1])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[app,actor,effect,c.get('loading',0)]):u.reg_write(reg,value)
 copy_fixture.prepare(effect);u.emu_start(owners[c['owner']],m.stop,count=12000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return {'case':c,'result':u.reg_read(UC_X86_REG_RAX)&0xffffffff,'calls':calls,'flags':u.mem_read(actor+0x770,1)[0],'type':int.from_bytes(u.mem_read(effect+8,2),'little')}
out=[]
for flags,mode,plot,immune,bypass in itertools.product([0,1,2,4,8,16,32,255],[8,16,0,128],[0,1],[0,1],[0,1]):out.append(run(dict(owner='blind',flags=flags,mode=mode,plot=plot,immune=immune,bypass=bypass)))
for flags,dm,kind in itertools.product([0,2,4,8,16,32,255],[0,1],[5,9]):out.append(run(dict(owner='dark',type=74,flags=flags,dm=dm,kind=kind)))
for owner,mode,flags,remaining in itertools.product(['removeBlind','removeDark'],[8,16],[0,8,16,24,255],[[],[8],[16],[8,16]]):out.append(run(dict(owner=owner,mode=mode,flags=flags,remaining=remaining)))
for owner,mode,loading,dead,durationType in itertools.product(['filter','miss'],range(5),[0,1],[0,1],[0,1,2,3,4]):out.append(run(dict(owner=owner,mode=mode,loading=loading,dead=dead,durationType=durationType)))
for loading,dead,durationType,plot,immune,bypass,kind in itertools.product([0,1],[0,1],range(5),[0,1],[0,1],[0,1],[5,9]):out.append(run(dict(owner='deaf',type=21,loading=loading,dead=dead,durationType=durationType,plot=plot,immune=immune,bypass=bypass,kind=kind)))
for loading,kind,mode in itertools.product([0,1],[5,9],[0,8,16]):out.append(run(dict(owner='inactive',type=89,mode=mode,loading=loading,kind=kind)))
print(json.dumps({'owner':'Blindness427bb0/Darkness42a590 plus paired removal and vision/miss admission','binarySha256':m.digest,'limits':__doc__,'copyConstructorExecutions':copy_fixture.executions,'rows':out}))
