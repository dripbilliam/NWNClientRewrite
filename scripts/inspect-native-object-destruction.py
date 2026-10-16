"""Original creature/item destructors and repository/equipment ownership loops.
Internal memory destructors, base destructor, area removal and tag/AI owners
are captured phase boundaries here; base destruction is validated separately.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
root,master,chair,app,module,stats,path,roundp,repo,equipment,vt,linked,itemA,itemB,valueptr=[m.heap+n*0x1000 for n in range(1,16)]
items={100:itemA,101:itemB};ids=[]
def identity(ptr):return m.si(ptr+8)&0xffffffff
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(master if c.get('masterExists',True) else 0)
 elif a==0x1403d6e10:calls.append(['associate',y&0xffffffff]);m.finish()
 elif a==0x14055b890:calls.append(['placeable',y&0xffffffff]);m.finish(chair if c.get('chairExists',True) else 0)
 elif a==0x140494e80:calls.append(['area']);m.finish(app if m.si(x+0xa0)&0xffffffff==88 else 0)
 elif a in [0x14039e6b0,0x14046b1d0]:calls.append(['removeArea',y if a==0x14039e6b0 else None]);m.wi(x+0xa0 if a==0x14039e6b0 else x+0xe8,0x7f000000);m.finish()
 elif a in [0x1403ee860,0x140293c20,0x140374180]:calls.append([{0x1403ee860:'stats',0x140293c20:'path',0x140374180:'round'}[a]]);m.finish()
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405595b0:calls.append(['ai']);m.finish()
 elif a==0x14055b6e0:calls.append(['module']);m.finish(module if c.get('module',True) else 0)
 elif a==0x14003d8c0:m.finish(x)
 elif a==0x140484bd0:calls.append(['tag',z&0xffffffff]);m.finish()
 elif a in [0x140463120,0x140463640] and kind in ['creature','item']:calls.append(['repository']);m.finish()
 elif a==m.stop+0x30:calls.append(['equipment']);m.finish()
 elif a==0x140387b40:calls.append(['autoMap']);m.finish()
 elif a==0x14048bf10:calls.append(['base']);m.finish()
 elif a==0x14029c8a0:m.finish()
 elif a==0x1401692a0:
  id=ids.pop(0);m.wi(valueptr,id);m.wq(linked,1 if ids else 0);m.finish(valueptr)
 elif a in [0x14055b4c0,0x14055b6c0]:
  id=y&0xffffffff;calls.append(['object' if a==0x14055b4c0 else 'item',id]);m.finish(items.get(id,0) if id not in deleted else 0)
 elif a==m.stop+0x20:
  id=identity(x);calls.append(['destroy',id,y]);deleted.add(id);m.finish()
 elif a in [0x140c4f024,0x140c10360,0x140c10370,0x140168dc0,0x1401695b0,0x140463080,0x140369860,0x140c10434]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14037b440,0x14037ba13),(0x1404631c0,0x1404633f5),(0x140463120,0x1404631b3),(0x140462880,0x1404628f2)]):raise AssertionError(f'Uncaptured destructor dependency {a:x} kind={kind}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,operation):
 global c,calls,kind,ids,deleted
 c=case;kind=operation;calls=[];ids=list(c.get('ids',[]));deleted=set();u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app)
 base=root+0x48 if kind=='item' else root;m.wi(base+8,99);m.wi(base+0xa0,88 if c.get('area') else 0x7f000000);m.wi(root+0x8fc,100 if c.get('master') else 0x7f000000);m.wi(root+0x82c,101 if c.get('chair') else 0x7f000000);m.wi(chair+0x36c,99)
 for off,ptr,name in [(0xad0,stats,'stats'),(0x530,path,'path'),(0x880,roundp,'round'),(0x958,repo,'repository'),(0x950,equipment,'equipment')]:
  if c.get(name,False):m.wq(root+off,ptr)
 m.wq(equipment,vt);m.wq(vt,m.stop+0x30)
 for n,off in enumerate([0xac0,0xab0]):m.wq(root+off,linked+0x200+n*0x100)
 if kind=='item' and c.get('repository'):m.wq(root+0x3d0,repo)
 if kind=='repository':m.wq(root+0x10,linked);m.wq(linked,1 if ids else 0)
 if kind=='equipment':
  m.wq(root,vt)
  for n in range(18):m.wi(root+8+n*4,ids[n] if n<len(ids) else 0x7f000000)
 for id,obj in items.items():m.wi(obj+8,id);m.wq(obj,vt+0x100)
 m.wq(vt+0x100,m.stop+0x20)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,root)
 try:u.emu_start({'creature':0x14037b440,'item':0x1404631c0,'repository':0x140463120,'equipment':0x140462880}[kind],m.stop,count=10000)
 except Exception:print(json.dumps(dict(kind=kind,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,chair=m.si(root+0x82c)&0xffffffff,occupant=m.si(chair+0x36c)&0xffffffff,areaId=m.si(base+0xa0)&0xffffffff,
  fields={name:int(m.q(root+off)!=0) for off,name in [(0xad0,'stats'),(0x530,'path'),(0x880,'round'),(0x958,'repository'),(0x950,'equipment')]},ids=ids,slots=[m.si(root+8+i*4)&0xffffffff for i in range(18)] if kind=='equipment' else None)
creatures=[run(dict(master=hasMaster,chair=hasChair,area=hasArea,stats=hasStats,path=hasPath,round=hasRound,repository=hasRepo,equipment=hasEquipment,module=hasModule),'creature') for hasMaster,hasChair,hasArea,hasStats,hasPath,hasRound,hasRepo,hasEquipment,hasModule in itertools.product([False,True],repeat=9)]
creatures += [run(dict(master=True,masterExists=False,chair=True,chairExists=False),'creature')]
itemRows=[run(dict(area=area,repository=repo,module=module),'item') for area,repo,module in itertools.product([False,True],repeat=3)]
repositories=[run(dict(ids=ids),'repository') for ids in [[],[100],[100,101,100],[0x7f000000,100,102,101]]]
equipmentRows=[run(dict(ids=ids),'equipment') for ids in [[],[100],[100,101,100],[0x7f000000,100,102,101]]]
out=m.root/'backups/animations/native-object-destruction-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,creatures=creatures,items=itemRows,repositories=repositories,equipment=equipmentRows))+'\n');print(json.dumps(dict(creatures=len(creatures),items=len(itemRows),repositories=len(repositories),equipment=len(equipmentRows),output=str(out))))
