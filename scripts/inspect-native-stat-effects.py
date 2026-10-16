"""Unmodified attack/save/AC admission and removal owners plus shared sorted
effect index updater and complete effect copy constructor (including cleared
payload with icon flag1). Lower AsCreature/dead/immunity/apply/feedback and heap,
string/vector initialization boundaries are captured. Child icon application is
separately native-compared; no allocation-failure/full stat recomputation claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,effect,ints,pool,rows,vtable,source,child=[m.heap+n*0x2000 for n in range(1,10)]
offsets={'up':[0xd4f,0xd4d,0xd47,0xd4b,0xd49],'down':[0xd50,0xd4e,0xd48,0xd4c,0xd4a]}
apply={10:0x140427920,11:0x1404277d0,26:0x1404314a0,27:0x140431360,48:0x140426ad0,49:0x140426860}
remove={10:0x140435f90,11:0x140435f50,26:0x140438290,27:0x140438250,48:0x140435ad0,49:0x1404358c0}
ranges=[(0x140426860,0x140426acf),(0x140426ad0,0x140426da2),(0x140431360,0x140431496),(0x1404314a0,0x1404315d7),(0x1404277d0,0x140427920),(0x140427920,0x140427a1c),(0x1404358c0,0x140435ace),(0x140435ad0,0x140435d04),(0x140438250,0x140438285),(0x140438290,0x1404382c5),(0x140435f50,0x140435f85),(0x140435f90,0x140435fc5),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x1403a7780,0x1403a7ba3),(0x140423570,0x140423768)]
def snapshot(ptr):return dict(type=int.from_bytes(u.mem_read(ptr+8,2),'little'),integers=[m.si(m.q(ptr+0x48)+n*4) for n in range(8)])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:m.finish(actor if c['objectType']==5 else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c['dead'])
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(source if c['source'] else 0)
 elif a==0x140400ab0:calls.append(['immunity',y&255,bool(z),w]);m.finish(c['immune'])
 elif a==0x140c10324:m.finish(child)
 elif a==0x140423570:calls.append(['copy',z]) # execute the complete constructor
 elif a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish()
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(child+0x400)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif a==0x14048e350:calls.append(['icon',snapshot(y),z&0xffffffff,w&0xffffffff]);m.finish(1)
 elif a==0x1403a2480:calls.append(['feedback',y&0xffff,None]);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured stat effect dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def enter(address,args):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(address,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x40000));m.wq(0x1412df970,m.heap+0x30000);m.wq(m.heap+0x30008,m.heap+0x31000);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(actor+0xfc,c['plot']);m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wi(effect+0x18,91);m.wi(effect+0x108,c['bypass']);u.mem_write(effect+8,struct.pack('<HH',c['type'],8|c['duration']))
 for i,v in enumerate(c['integers']):m.wi(ints+i*4,v)
 for sign,places in offsets.items():
  for off,value in zip(places,c['cache'][sign]):u.mem_write(stats+off,bytes([value&255]))
 if c['mode']=='remove':
  m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c['effects']));u.mem_write(stats+0xd92,b'\xff\xff')
  for i,e in enumerate(c['effects']):
   ptr=effect if e.get('samePointer') else rows+i*0x400;m.wq(pool+i*8,ptr)
   if ptr!=effect:
    u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wq(ptr+0x48,ptr+0x200)
    for n,v in enumerate(e['integers']):m.wi(ptr+0x200+n*4,v)
  enter(0x1403a7780,[actor,0,0,0]);result=enter(remove[c['type']],[m.heap,actor,effect,0])
 else:result=enter(apply[c['type']],[m.heap,actor,effect,c['loading']])
 cache={sign:[int.from_bytes(u.mem_read(stats+off,1),'little',signed=True) for off in places] for sign,places in offsets.items()}
 return dict(case=c,result=result,cache=cache,dirty=m.si(actor+0x53c),calls=calls,index=int.from_bytes(u.mem_read(stats+0xd92,2),'little') if c['mode']=='remove' else None)

base=dict(mode='apply',type=48,objectType=5,loading=0,dead=0,duration=1,plot=0,immune=0,bypass=0,source=True,cache={'up':[0]*5,'down':[0]*5},integers=[4,3,28,0,0,4103,0,0],effects=[])
out=[]
for type,objectType,loading,dead,duration,amount,plot,immune in itertools.product(apply,[5,9],[0,1],[0,1],[0,1,3,4],[-1,0,3],[0,1],[0,1]):
 values=[4,amount,28,0,0,4103,0,0] if type in [48,49] else [amount,2,0,28,0,0,0,0]
 out.append(run(base|dict(type=type,objectType=objectType,loading=loading,dead=dead,duration=duration,plot=plot,immune=immune,integers=values)))
filters=[[28,0,0,4103],[6,0,0,4103],[28,2,0,4103],[28,0,5,4103],[28,0,0,1]]
for type,category,amount,initial,filter in itertools.product([48,49],[-1,0,1,2,3,4,5],[1,127,128,129,255,256,300],[-128,-1,0,1,127],filters):
 out.append(run(base|dict(type=type,cache={'up':[initial]*5,'down':[initial]*5},integers=[category,amount,*filter,0,0])))
for type,category,filter,variant,initial in itertools.product([48,49],[0,1,2,3,4,5],filters,range(6),[-1,0,127]):
 values=[category,7,*filter,0,0];entries=[dict(type=type,integers=values,samePointer=True)]
 candidates=[dict(type=type,integers=[category,130,28,2 if variant==1 else 0,5 if variant==2 else 0,1 if variant==3 else 4103,0,0]),dict(type=type,integers=[category,4,28,0,0,4103,0,0])]
 if variant==4:candidates.insert(0,dict(type=48,integers=[category,9,28,0,0,4103,0,0]))
 if variant!=5:entries+=candidates
 entries.sort(key=lambda e:e['type']);out.append(run(base|dict(mode='remove',type=type,integers=values,effects=entries,cache={'up':[initial]*5,'down':[initial]*5})))
for type,bypass,source in itertools.product(apply,[0,1],[False,True]):out.append(run(base|dict(type=type,bypass=bypass,source=source,immune=1,integers=[4,3,28,0,0,4103,0,0] if type in [48,49] else [3,0,0,28,0,0,0,0])))
dest=m.root/'backups/animations/native-stat-effect-observations.json';dest.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=out),indent=2)+'\n');print(json.dumps(dict(rows=len(out),output=str(dest))))
