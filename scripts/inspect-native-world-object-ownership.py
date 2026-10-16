"""Full placeable/store/waypoint constructors and destructors. Real repository
constructor462d40 executes; base ctor, AI, area/tag/base destructors, repository
child destruction, store GUI closure and memory/string primitives are captured
boundaries. Common base/AI/repository/area owners have separate native checks.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actorPtr,appPtr,areaPtr,clientArrayPtr=[m.heap+n*0x1000 for n in range(1,5)]
ranges=[(0x1404af9c0,0x1404afd6a),(0x1404f9a70,0x1404f9bc7),(0x140508d60,0x140508dd0),(0x140462d40,0x140462e3d),(0x140047300,0x14004730c),(0x1404afd70,0x1404aff40),(0x1404f9c20,0x1404f9e3a),(0x140508dd0,0x140508e92)]
ctors={'placeable':0x1404af9c0,'store':0x1404f9a70,'waypoint':0x140508d60};dtors={'placeable':0x1404afd70,'store':0x1404f9c20,'waypoint':0x140508dd0}
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14048b760:
  u.mem_write(x,bytes(0x308));m.wi(x+8,99 if z==0x7f000000 else z);m.wi(x+0x7c,-1);m.wi(x+0xa0,0x7f000000);m.finish(x);return
 if a in [0x140c10324,0x140c10368]:ptr=m.heap+cursor;cursor+=(x+15)&~15;u.mem_write(ptr,bytes([0xa5])*x);m.finish(ptr);return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x140169560:u.mem_write(x,bytes(16));m.finish(x);return
 if a==0x14018ded0:u.mem_write(x,bytes(17));m.finish(x);return
 if a==0x14055b960:m.finish(appPtr);return
 if a==0x140557430:calls.append(['ai',m.si(y+8)&0xffffffff,z]);m.wi(y+0x7c,z);m.finish();return
 if a==0x140462d40:calls.append(['repository',y&0xffffffff,z&255,w&255,m.si(rsp+0x28),m.si(rsp+0x30)])
 elif a==0x140463120:calls.append(['repository',repoNames[x]]);m.finish();return
 elif a==0x140494e80:calls.append(['area']);m.finish(areaPtr if m.si(x+0xa0)&0xffffffff==88 else 0);return
 elif a in [0x1404b6930,0x14050a470]:calls.append(['removeArea',kind]);m.wi(x+0xa0,0x7f000000);m.finish();return
 elif a==0x140364cc0:calls.append(['removeObject',y&0xffffffff]);m.finish();return
 elif a==0x14049ae60:calls.append(['setArea',None]);m.wi(x+0xa0,0x7f000000);m.finish();return
 elif a==0x1405595b0:calls.append(['ai']);m.wi(y+0x7c,-1);m.finish();return
 elif a==0x14055b6e0:calls.append(['module']);m.finish(appPtr if c.get('module',True) else 0);return
 elif a==0x14003d8c0:m.finish(x);return
 elif a==0x140484bd0:calls.append(['tag',z&0xffffffff]);m.finish();return
 elif a==0x14048bf10:calls.append(['base']);m.finish();return
 elif a==0x14055b390:
  id=y&0xffffffff;calls.append(['client',id]);m.finish(m.heap+0x50000+(id-100)*0x100 if id in c.get('present',[]) else 0);return
 elif a==0x1404b9520:
  id=(y-m.heap-0x50000)//0x100+100;calls.append(['closeStore',id,z]);
  if c.get('mutate'):m.wq(clientArrayPtr,0)
  m.finish();return
 elif a in [0x140c10360,0x140c10370]:
  if x in clientNames:calls.append(['freeClient',clientNames[x]])
  m.finish();return
 elif a in [0x1401695b0,0x140c4f024,0x140c10434]:m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured world ownership dependency {a:x}: {kind}/{mode}, {c}')
u.hook_add(UC_HOOK_CODE,hook)
def repository(ptr):return None if not ptr else dict(ownerId=m.si(ptr+8)&0xffffffff,width=u.mem_read(ptr,1)[0],height=u.mem_read(ptr+1,1)[0],boundary=m.si(ptr+4)&0xffffffff,expand=m.si(ptr+12))
def run(case,objectKind,operation):
 global c,calls,kind,mode,cursor,repoNames,clientNames
 c=case;kind=objectKind;mode=operation;calls=[];cursor=0x20000;repoNames={};clientNames={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(actorPtr,bytes([0xa5])*0x1000);m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr)
 if mode=='destroy':
  u.mem_write(actorPtr,bytes(0x1000));m.wi(actorPtr+8,99);m.wi(actorPtr+0xa0,88 if c.get('area') else 0x7f000000)
  for i,hasRepo in enumerate(c.get('repos',[True]*5) if kind=='store' else [c.get('repo',True)]):
   ptr=m.heap+0x20000+i*0x100;repoNames[ptr]=i;m.wq(actorPtr+(0x328+i*8 if kind=='store' else 0x540),ptr if hasRepo else 0)
  if kind=='store':
   clients=c.get('clients',[]);m.wq(actorPtr+0x350,clientArrayPtr);m.wi(actorPtr+0x358,len(clients))
   for i,id in enumerate(clients):
    ptr=m.heap+0x40000+i*0x100;m.wq(clientArrayPtr+i*8,0 if id is None else ptr)
    if id is not None:m.wi(ptr,id);clientNames[ptr]=id
   for id in c.get('present',[]):m.wq(m.heap+0x50000+(id-100)*0x100+0x88,appPtr)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actorPtr);u.reg_write(UC_X86_REG_RDX,c.get('requestedId',0x7f000000))
 try:u.emu_start((ctors if mode=='construct' else dtors)[kind],m.stop,count=30000)
 except Exception:print(json.dumps(dict(kind=kind,mode=mode,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=dict(kind=kind,mode=mode,case=c,calls=calls,id=m.si(actorPtr+8)&0xffffffff,areaId=m.si(actorPtr+0xa0)&0xffffffff)
 if mode=='construct':
  result['aiLevel']=m.si(actorPtr+0x7c)
  if kind=='placeable':result|=dict(repo=repository(m.q(actorPtr+0x540)),slot=m.si(actorPtr+0x50c),override=m.si(actorPtr+0x5a4),dieWhenEmpty=m.si(actorPtr+0x504),occupant=m.si(actorPtr+0x36c)&0xffffffff,effectSpell=m.si(actorPtr+0x590),points=[[m.rf(actorPtr+0x550+i*12+j*4) for j in range(3)] for i in range(2)])
  if kind=='placeable':result['loadDefaults']=[u.mem_read(actorPtr+0x3d0,1)[0],m.si(actorPtr+0x3c8),m.si(actorPtr+0x3d4),m.si(actorPtr+0x3d8),m.si(actorPtr+0x368),u.mem_read(actorPtr+0x59c,1)[0]]
  elif kind=='store':result|=dict(repos=[repository(m.q(actorPtr+0x328+i*8)) for i in range(5)],clients=m.si(actorPtr+0x358),enumeration=[int.from_bytes(u.mem_read(actorPtr+0x388,2),'little'),u.mem_read(actorPtr+0x38a,1)[0]],buyArrays=[[m.q(actorPtr+offset),m.si(actorPtr+offset+8),m.si(actorPtr+offset+12)]for offset in [0x398,0x3a8]])
  else:result|=dict(animation=m.si(actorPtr+0xd8),mapFlags=[m.si(actorPtr+0x308),m.si(actorPtr+0x30c)])
 return result
rows=[run(dict(requestedId=id),kindName,'construct') for kindName,id in itertools.product(ctors,[0x7f000000,0,99,0x80000077])]
rows += [run(dict(repo=repo,area=area,module=module),'placeable','destroy') for repo,area,module in itertools.product([False,True],repeat=3)]
rows += [run(dict(area=area,module=module),'waypoint','destroy') for area,module in itertools.product([False,True],repeat=2)]
for repos,hasArea,hasModule,clients,present,mutate in itertools.product([[False]*5,[True]*5,[True,False,True,False,True],[False,True,False,True,False]],[False,True],[False,True],[[],[100],[100,None,101],[100,101,102]], [[],[100],[100,101,102]],[False,True]):rows.append(run(dict(repos=repos,area=hasArea,module=hasModule,clients=clients,present=present,mutate=mutate),'store','destroy'))
out=m.root/'backups/animations/native-world-object-ownership-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
