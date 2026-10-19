"""Original sanctuary constructor/apply/remove, targeted PacifyCreature and
RemoveCombatInvisibilityEffects. Native effect clearing-copy constructor executes.
VM/base allocation, registry/area/visibility lookup, saving throws, pacify during
apply, round clear, hostile actions, linked-ID erase and child apply are captured
boundaries. No full AI, renderer, save engine or transport claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_effect_copy_fixture import NativeEffectCopyFixture
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);copy=NativeEffectCopyFixture(m)
actor,effect,ints,stats,app,area,areaIds,vt,module,pool,command=[m.heap+n*0x2000 for n in range(1,12)]
objects={99:actor,100:m.heap+0x20000,101:m.heap+0x24000};nodes={oid:m.heap+0x30000+i*0x100 for i,oid in enumerate(objects)}
rounds={oid:m.heap+0x31000+i*0x100 for i,oid in enumerate(objects)}
ranges=[(0x14051b1c0,0x14051b30f),(0x140431120,0x14043135d),(0x140437ff0,0x140438246),(0x140399b50,0x140399c27),(0x14039e500,0x14039e5a2),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]

def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little');return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(ptr+0x18)&0xffffffff,spellId=m.si(ptr+0x1c),casterLevel=m.si(ptr+0x28),showIcon=m.si(ptr+0x24),exposed=m.si(ptr+0x20),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def refresh():
 for i,ptr in enumerate(live):m.wq(pool+i*8,ptr)
 m.wi(actor+0x158,len(live));u.mem_write(stats+0xda2,struct.pack('<H',next((i for i,ptr in enumerate(live) if int.from_bytes(u.mem_read(ptr+8,2),'little')>=47),len(live))))
def hook(u,a,n,_):
 global allocation,pops,output
 if a==m.stop:u.emu_stop();return
 if copy.handle(a):return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 oid=lambda ptr:m.si(ptr+8)&0xffffffff
 if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
 elif a==0x140286110:
  calls.append(['popInt']);m.wi(y,c.get('dc',17) if pops==0 else c.get('versus',1));pops+=1;m.finish(int(pops!=c.get('failPop',0)))
 elif a==0x140286330:output=snapshot(z);calls.append(['push']);m.finish(c.get('push',1))
 elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x60000+allocation*0x1000)
 elif a==0x1404233d0:
  m.wq(x,100);m.wq(x+0x48,x+0x200);m.wi(x+0x40,8);m.wi(x+0x18,0x7f000000);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x20,1);m.wi(x+0x24,1);m.finish(x)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a in [0x140423770,0x140c10360,0x140c4f024]:m.finish()
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140494e80:calls.append(['area']);m.finish(area if c.get('area',True) else 0)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(0 if y==101 and c.get('missing',False) else objects.get(y&0xffffffff,0))
 elif a==0x1403d5850:calls.append(['node',oid(x),y&0xffffffff]);m.finish(nodes[oid(x)] if c.get('nodes',{}).get(str(oid(x))) is not None else 0)
 elif a==0x1403ec600:
  rsp=u.reg_read(UC_X86_REG_RSP);calls.append(['save',oid(x),y&255,z&65535,w&255,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.si(rsp+0x38),m.si(rsp+0x40)]);m.finish(c.get('save',0))
 elif a==0x140399b50 and c['mode']!='pacify':calls.append(['pacify',oid(x),y&0xffffffff]);m.finish()
 elif a==0x14055b6e0:m.finish(module)
 elif a==0x140174af0:calls.append(['addInvisible',y&0xffffffff]);m.finish()
 elif a==0x1400b5450:calls.append(['removeInvisible',y&0xffffffff]);m.finish()
 elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
 elif a==0x140c4f038:assert x==0;m.finish(m.heap+0x40000)
 elif a==0x1403d7390:calls.append(['removeNode',oid(x),y&0xffffffff]);m.finish()
 elif a==0x140378d60:calls.append(['roundActions']);m.finish()
 elif a==0x1403754d0:calls.append(['roundAttacks']);m.finish()
 elif a==0x14049b070:calls.append(['lastHostile',oid(x),y&0xffffffff,z]);m.wi(x+0x190,y);m.finish()
 elif a==0x140387bf0:calls.append(['clearHostile',oid(x),oid(y)]);m.finish()
 elif a==0x140498280:
  calls.append(['removeId',f'{y:016x}']);live[:]=[ptr for ptr in live if m.q(ptr)!=y];refresh();m.finish(1)
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured sanctuary dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,allocation,pops,output,live
 c=case;calls=[];allocation=pops=0;output=None;live=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,app);m.wi(command+0xc,99)
 for oid,ptr in objects.items():m.wi(ptr+8,oid);m.wq(ptr,vt);m.wi(nodes[oid],99);u.mem_write(nodes[oid]+4,bytes([c.get('nodes',{}).get(str(oid),0) or 0]))
 m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wq(actor+0x150,pool);m.wq(area+0x228,areaIds);ids=c.get('areaIds',[100,101,99,999]);m.wi(area+0x230,len(ids))
 for i,oid in enumerate(ids):m.wi(areaIds+i*4,oid)
 for i,e in enumerate(c.get('effects',[])):
  ptr=m.heap+0x50000+i*0x200;m.wq(ptr,e.get('id',77));u.mem_write(ptr+8,struct.pack('<H',e['type']&65535));m.wq(ptr+0x48,ptr+0x100);m.wi(ptr+0x40,8);m.wi(ptr+0x100,e.get('kind',1));live.append(ptr)
 refresh()
 if 'index' in c:u.mem_write(stats+0xda2,struct.pack('<H',c['index']))
 m.wq(effect,77);m.wq(effect+0x48,ints);m.wi(effect+0x40,8);u.mem_write(effect+8,struct.pack('<HH',63,8|(c.get('durationType',2)&7)));m.wi(effect+0x18,98);m.wi(effect+0x1c,11);m.wi(effect+0x28,7);m.wi(effect+0x20,1);m.wi(effect+0x24,c.get('showIcon',1))
 for i,v in enumerate([8,28,0,0,c.get('dc',17),c.get('versus',1),0,0]):m.wi(ints+i*4,v)
 for field in [0x728,0x724,0x73c,0x740,0x190]:m.wi(objects[100]+field,99 if field in c.get('targets',[]) else 0x7f000000)
 m.wi(objects[100]+0x700,2);m.wi(objects[100]+0x704,8000);m.wi(objects[100]+0x744,17);m.wi(objects[100]+0x6fc,0);m.wq(objects[100]+0x880,rounds[100] if c.get('round',True) else 0)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 regs=[command,0,c.get('argc',2),0] if c['mode']=='construct' else [actor,c.get('id',100),0,0] if c['mode']=='pacify' else [actor,0,0,0] if c['mode']=='combatRemove' else [app,actor,effect,c.get('loading',0)]
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,v)
 copy.prepare(effect);u.emu_start(dict(construct=0x14051b1c0,apply=0x140431120,remove=0x140437ff0,pacify=0x140399b50,combatRemove=0x14039e500)[c['mode']],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,nodes={str(oid):int.from_bytes(u.mem_read(nodes[oid]+4,1),'little') for oid in objects},effects=[dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),kind=m.si(m.q(ptr+0x48))) for ptr in live],target={hex(field):m.si(objects[100]+field)&0xffffffff for field in [0x700,0x704,0x744,0x6fc,0x724,0x190]})

rows=[run(dict(mode='construct',dc=dc,versus=versus,argc=argc,failPop=fail,push=push))for dc,versus,argc,fail,push in itertools.product([-1,0,1,17,255,256,257,0x7fffffff],[-1,0,1,2],[1,2],[0,1,2],[0,1])]
rows += [run(dict(mode='apply',dc=dc,versus=versus,save=save,nodes={'100':flags,'101':4},missing=missing))for dc,versus,save,flags,missing in itertools.product([1,255,256,257,-1],[0,1,2],[0,1,256,257],[None,0,4,8,12,255],[False,True])]
rows += [run(dict(mode='apply',objectType=kind,area=area,dead=dead,loading=loading,durationType=duration,nodes={'100':0}))for kind,area,dead,loading,duration in itertools.product([5,9],[False,True],[0,1],[0,1],[0,1,2,3,4,5,7])]
effectsets=[[],[dict(type=47,id=77)],[dict(type=47,id=78)],[dict(type=63,id=77)],[dict(type=63,id=78)],[dict(type=47,id=78),dict(type=63,id=79)],[dict(type=46,id=78),dict(type=67,id=79)]]
rows += [run(dict(mode='remove',objectType=kind,area=area,nodes={'100':flags,'101':8},effects=effects))for kind,area,flags,effects in itertools.product([5,9],[False,True],[None,0,4,8,12,255],effectsets)]
rows += [run(dict(mode='pacify',targets=[field for i,field in enumerate([0x728,0x724,0x73c,0x740,0x190]) if mask&(1<<i)],round=round,id=oid))for mask,round,oid in itertools.product(range(32),[False,True],[100,999])]
for effects in effectsets+[[dict(type=47,id=77,kind=kind),dict(type=63,id=78),dict(type=67,id=77)]for kind in [0,1,2,4]]:
 rows += [run(dict(mode='combatRemove',effects=effects,index=index))for index in [0,1,65535]]
out=m.root/'backups/animations/native-sanctuary-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copies=copy.executions,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions,output=str(out))))
