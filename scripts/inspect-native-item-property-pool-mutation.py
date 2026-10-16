"""Original OnRemoveItemProperty complete owner and bounded OnApplyItemProperty
post-materialization block14042e83e..14042e942. Base pool classification executes;
scalar/property storage, canonical owner lookup, equipment, weight/cache/visual,
AI materializer and pool removal are captured lower boundaries. No assets or
live process edits. This does not execute every property materializer.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
item,effect,owner,ai,vtable,storage,repository,app=[m.heap+i*0x1000 for i in range(8)]
def serialize(ptr,p):
 for offset,key,fmt in [(0,'type','H'),(2,'subtype','H'),(4,'costTable','B'),(6,'costValue','H'),(8,'param1','B'),(9,'param1Value','B'),(10,'chance','B'),(16,'usesPerDay','B'),(17,'durationType','B')]:u.mem_write(ptr+offset,struct.pack('<'+fmt,p[key]&({'H':65535,'B':255}[fmt])))
 m.wq(ptr+0x28,int(p.get('propertyId','1'),16))
def propIndex(ptr):return None if ptr==0 else (ptr-storage)//0x40
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x200:m.finish(item if c.get('item',True) else 0)
 elif a==0x140423fc0:m.finish(c['integers'][y]&0xffffffff)
 elif a in [0x1404686d0,0x140468ef0]:m.finish(0 if c['properties'][y] is None else storage+y*0x40)
 elif a in [0x14046b1a0,0x14046b4a0]:trace.append(['removeActive' if a==0x14046b1a0 else 'removePassive',y]);remaining.pop(y);m.finish()
 elif a==0x14046cf20:trace.append(['activeChanged',y]);m.finish()
 elif a==0x140466660:trace.append(['weight']);m.finish()
 elif a==0x14055b3d0:trace.append(['creature',y&0xffffffff]);m.finish(owner if c.get('owner',True) else 0)
 elif a==0x140462b40:trace.append(['equipped']);m.finish(c.get('equipped',1))
 elif a==0x14055b960:trace.append(['ai']);m.finish(ai if c.get('ai',True) else 0)
 elif a==0x140462c10:trace.append(['slot']);m.finish(16)
 elif a in [0x140559490,0x1405594b0]:trace.append(['applyProperty' if a==0x140559490 else 'removeProperty',propIndex(z),m.si(rsp+0x28),m.si(rsp+0x30)] if a==0x140559490 else ['removeProperty',propIndex(z),m.si(rsp+0x28)]);m.finish()
 elif a==0x1404171e0:trace.append(['combatInformation']);m.finish()
 elif a==0x140465310:trace.append(['contentsWeight']);m.finish()
 elif a==0x1403db1e0:trace.append(['encumbrance',y]);m.finish()
 elif a==0x14046d140:trace.append(['visual']);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14042e83e,0x14042e942),(0x1404373c0,0x14043776b),(0x1404640e0,0x140464108)]):raise RuntimeError(f'Unmapped item-property pool mutation {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def active(type_):return type_&65535==80 or 15<=(type_&65535)<=70 and (0x80010000000001>>((type_&65535)-15)&1)!=0
def run(case):
 global c,trace,remaining
 c=case;trace=[];remaining=list(range(len(c['properties'])));u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(item,vtable);m.wq(vtable+0x70,m.stop+0x200);m.wi(item+0x3c8,55 if c.get('possessed',True) else 0x7f000000);m.wq(item+0x3d0,repository if c.get('repository') else 0);m.wi(item+0x398,0);u.mem_write(effect+0xa,struct.pack('<H',c['duration']));m.wq(owner+0x950,ai);m.wq(owner+0xad0,ai)
 for i,p in enumerate(c['properties']):
  if p:serialize(storage+i*0x40,p)
 if c['kind']=='remove':
  m.wi(item+(0x370 if active(c['integers'][0]) else 0x380),len(c['properties']));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[ai,item,effect]):u.reg_write(reg,value)
  u.emu_start(0x1404373c0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 else:
  rbp=m.stack+0x10000;rsp=rbp-0x200;u.reg_write(UC_X86_REG_RBP,rbp);u.reg_write(UC_X86_REG_RSP,rsp);serialize(rbp-0x19,c['properties'][0]);
  for reg,value in zip([UC_X86_REG_RDI,UC_X86_REG_RSI,UC_X86_REG_R15],[item,effect,0]):u.reg_write(reg,value)
  # The callback's stack-copy pointer is represented as property index0.
  m.wq(rbp+0x170,storage);u.emu_start(0x14042e83e,0x14042e942,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x14042e942;result=None
  for entry in trace:
   if entry[0]=='applyProperty':entry[1]=0
 return dict(case=c,result=result,trace=trace,remaining=remaining,priceDirty=m.si(item+0x398))
def property_(type_,duration=1):return dict(type=type_,durationType=duration,subtype=2,costTable=3,costValue=4,param1=5,param1Value=6,usesPerDay=7,chance=8,propertyId='000000000000002a')
if __name__=='__main__':
 rows=[]
 for kind,type_,duration,possessed,owner_,equipped,ai_,repository_ in itertools.product(['remove','post'],[6,11,15,32,47,80,81],[1,2],[False,True],[False,True],[0,1],[False,True],[False,True]):
  p=property_(type_,duration);rows.append(run(dict(kind=kind,integers=[type_,2,3,4,5,6,7,8],duration=duration,properties=[p,p.copy()],possessed=possessed,owner=owner_,equipped=equipped,ai=ai_,repository=repository_)))
 for type_,field,value in itertools.product([6,15],['type','durationType','subtype','costTable','costValue','param1','param1Value','usesPerDay','chance'],[-1,0,258,65538]):
  p=property_(type_);p[field]=value;rows.append(run(dict(kind='remove',integers=[type_,2,3,4,5,6,7,8],duration=1,properties=[p])))
 for type_,props in itertools.product([6,15,11],[[],[None],[None,property_(1)],[property_(1),None]]):rows.append(run(dict(kind='remove',integers=[type_,2,3,4,5,6,7,8],duration=1,properties=props)))
 out=m.root/'backups/animations/native-item-property-pool-mutation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
