"""Original seven damage-buff admission owners, four removal owners, complete
copy constructor and SetDamageImmunity. Creature/dead/immunity, icon application,
floaty, heap/string/vector initialization are captured lower boundaries. No
allocation-failure, native GUI art, whole damage resolution or campaign claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,effect,ints,pool,storage,vtable,source,child,cache=[m.heap+n*0x2000 for n in range(1,11)]
apply={2:0x14042a420,12:0x14042a380,13:0x14042a290,14:0x140429ce0,16:0x14042a080,17:0x140429e10,61:0x14042a4c0}
remove={13:0x140436540,14:0x1404362e0,16:0x140436430,17:0x140436320}
ranges=[(0x140429ce0,0x140429e07),(0x140429e10,0x14042a07c),(0x14042a080,0x14042a28c),(0x14042a290,0x14042a376),(0x14042a380,0x14042a41d),(0x14042a420,0x14042a4bd),(0x14042a4c0,0x14042a585),(0x1404362e0,0x140436315),(0x140436320,0x14043642d),(0x140436430,0x14043653f),(0x140436540,0x140436575),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x140423570,0x140423768),(0x14049ae80,0x14049aebf)]
def signed(value):return (value+2**31)%2**32-2**31
def snapshot(ptr):return dict(type=int.from_bytes(u.mem_read(ptr+8,2),'little'),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:m.finish(actor if c['objectType']==5 else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c['dead'])
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(source if c['source'] else 0)
 elif a==0x140400ab0:calls.append(['immunity',y&255,bool(z),w]);m.finish(c['immune'])
 elif a==0x140c10324:m.finish(child)
 elif a==0x140423570:calls.append(['copy',z])
 elif a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish()
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(child+0x400)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif a==0x14048e350:calls.append(['icon',snapshot(y),z&0xffffffff,w&0xffffffff]);m.finish(1)
 elif a==0x140439ae0:calls.append(['floaty',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x14049ae80:calls.append(['setImmunity',y&0xffffffff,signed(z)]) # execute actual BYTE cache setter
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured damage buff dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x40000));m.wq(0x1412df970,m.heap+0x30000);m.wq(m.heap+0x30008,m.heap+0x31000);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(actor+8,77);m.wi(actor+0xfc,c['plot']);m.wq(actor+0x200,cache);u.mem_write(cache,bytes([249]*32));m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wi(effect+0x18,91);m.wi(effect+0x20,c['exposed']);m.wi(effect+0x108,c['bypass']);u.mem_write(effect+8,struct.pack('<HH',c['type'],8|c['duration']))
 for i,v in enumerate(c['integers']):m.wi(ints+i*4,v)
 m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c['effects']))
 for i,e in enumerate(c['effects']):
  ptr=effect if e.get('samePointer') else storage+i*0x400;m.wq(pool+i*8,ptr)
  if ptr!=effect:
   u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wq(ptr+0x48,ptr+0x200)
   for n,v in enumerate(e['integers']):m.wi(ptr+0x200+n*4,v)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[m.heap,actor,effect,c['loading']]):u.reg_write(reg,value)
 entry=(apply if c['mode']=='apply' else remove)[c['type']]
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,cache=[int.from_bytes(u.mem_read(cache+i,1),'little',signed=True) for i in range(32)],dirty=m.si(actor+0x53c),calls=calls)

base=dict(mode='apply',type=16,objectType=5,loading=0,dead=0,duration=1,plot=0,immune=0,bypass=0,source=True,exposed=1,integers=[256,30,28,0,0,0,0,0],effects=[])
out=[]
for type,objectType,loading,dead,duration,amount,plot,immune,bypass in itertools.product(apply,[5,9],[0,1],[0,1],[0,1,3,4],[-1,0,1,30],[0,1],[0,1],[0,1]):out.append(run(base|dict(type=type,objectType=objectType,loading=loading,dead=dead,duration=duration,plot=plot,immune=immune,bypass=bypass,integers=[256,amount,28,0,0,0,0,0])))
flags=[0,1,3,8,16,24,32,64,128,256,512,1024,2048,4096,0x80000000,0xffffffff]
for mode,type,flag,amount,variant in itertools.product(['apply','remove'],[16,17],flags,[0,30,2147483647],range(5)):
 values=[flag,amount,0,0,0,0,0,0];effects=[]
 if variant>0:effects=[dict(type=16,integers=[flag,70,0,0,0,0,0,0]),dict(type=17,integers=[flag,40,0,0,0,0,0,0]),dict(type=16,integers=[flag^1,90,0,0,0,0,0,0])]
 if variant==2:effects.append(dict(type=16,integers=[flag,2147483647,0,0,0,0,0,0]))
 if variant==3:effects.append(dict(type=17,integers=[flag,2147483647,0,0,0,0,0,0]))
 if mode=='remove':effects.insert(0,dict(type=type,integers=values,samePointer=True))
 out.append(run(base|dict(mode=mode,type=type,integers=values,effects=effects)))
for type,objectType,exposed,source in itertools.product(apply,[5,9],[0,1],[False,True]):out.append(run(base|dict(type=type,objectType=objectType,exposed=exposed,source=source)))
for type,objectType in itertools.product([13,14],[5,9]):out.append(run(base|dict(mode='remove',type=type,objectType=objectType)))
dest=m.root/'backups/animations/native-damage-buff-observations.json';dest.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=out),indent=2)+'\n');print(json.dumps(dict(rows=len(out),output=str(dest))))
