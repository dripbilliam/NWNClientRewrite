"""Complete original Add/RemoveItemProperty commands after controlled typed VM
pops. Canonical lookup/casts, ApplyEffect, ILR/minimum-level/equipment/repository,
event queue and memory release are captured boundaries. Exposure writes and
last-pointer event selection execute unchanged; no real process or assets.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
command,popped,obj,owner,options,array,pool,records,app,vtable=[m.heap+i*0x1000 for i in range(10)]
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b850:m.finish(array)
 elif a==0x140286110:m.wi(y,c['duration']);m.finish(1)
 elif a==0x140286030:m.wq(z,0 if c.get('null') else popped);m.finish(1)
 elif a==0x140286160:m.wi(y,123);m.finish(1)
 elif a==0x1402860c0:m.wf(y,c.get('seconds',2.5));m.finish(1)
 elif a==0x140296470:
  trace.append(['object',y&0xffffffff]);m.wq(z,obj if c.get('present',True) else 0);m.finish(c.get('status',0))
 elif a==m.stop+0x200:trace.append(['asItem']);m.finish(obj if c.get('item',True) else 0)
 elif a==m.stop+0x210:m.finish(obj)
 elif a==m.stop+0x220:trace.append(['ilr']);m.finish(options)
 elif a==0x14048e350:trace.append(['apply',int.from_bytes(u.mem_read(y+0xa,2),'little'),m.rf(y+0xc),z,q]);m.finish()
 elif a==0x14055b3d0:trace.append(['creature',y&0xffffffff]);m.finish(owner if c.get('owner',True) else 0)
 elif a==0x140462c10:trace.append(['slot']);m.finish(c.get('slot',16))
 elif a==0x1404035c0:trace.append(['level']);m.finish(c.get('level',1))
 elif a==0x140468d90:trace.append(['minimum']);m.finish(c.get('minimum',2))
 elif a==0x1403a6150:trace.append(['unequip',z,q]);m.finish(c.get('unequip',1))
 elif a==0x140464200:trace.append(['repositoryAdd',z&255,q&255,m.si(rsp+0x28),m.si(rsp+0x30)]);m.finish(1)
 elif a==0x14055b960:m.finish(array)
 elif a==0x1405570b0:
  ptr=m.q(rsp+0x38);trace.append(['event',m.si(rsp+0x30),q&0xffffffff,m.si(rsp+0x28),signed(y),signed(z),(ptr-records)//0x200]);m.finish(1)
 elif a==0x140423770:trace.append(['release']);m.finish()
 elif a==0x140c10360:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14050fb00,0x14050fd56),(0x14053b4a0,0x14053b627)]):raise RuntimeError(f'Unmapped item-property command dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(0x1412df910,app);m.wq(app+8,app);m.wq(app,vtable);m.wq(vtable+0x68,m.stop+0x220);m.wi(command+0xc,99);m.wi(options+0x134,c.get('ilr',1))
 m.wq(obj,vtable);m.wq(vtable+0x70,m.stop+0x200);m.wq(vtable+0x20,m.stop+0x210);m.wi(obj+0x3c8,55);m.wq(owner+0xad0,array if c.get('stats',True) else 0);m.wi(owner+0x97c,c.get('locked',0));m.wq(owner+0x950,array);m.wq(owner+0x958,array)
 m.wq(popped,0x1000000000000001);u.mem_write(popped+0xa,struct.pack('<H',c.get('flags',0xabca)&65535));m.wf(popped+0xc,17);m.wi(popped+0x1c,c.get('spell',419));m.wq(obj+0x150,pool);m.wi(obj+0x158,len(c.get('ids',[])))
 for i,id_ in enumerate(c.get('ids',[])):
  ptr=records+i*0x200;m.wq(pool+i*8,ptr);m.wq(ptr,int(id_,16));m.wi(ptr+0x20,i+1)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,command)
 u.emu_start(0x14050fb00 if c['kind']=='add' else 0x14053b4a0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=signed(u.reg_read(UC_X86_REG_RAX)),trace=trace,durationType=int.from_bytes(u.mem_read(popped+0xa,2),'little'),seconds=m.rf(popped+0xc),exposed=[m.si(records+i*0x200+0x20) for i in range(len(c.get('ids',[])))])
rows=[]
for duration,flags,present,status,item in itertools.product([-1,0,1,2,3,9],[0,1,2,0xabca],[False,True],[0,1],[False,True]):rows.append(run(dict(kind='add',duration=duration,flags=flags,present=present,status=status,item=item)))
for ilr,owner_,stats,locked,spell,slot,level,minimum in itertools.product([0,1,2],[False,True],[False,True],[0,1],[1,419],[0,16],[1,3],[2]):rows.append(run(dict(kind='add',duration=2,ilr=ilr,owner=owner_,stats=stats,locked=locked,spell=spell,slot=slot,level=level,minimum=minimum)))
for seconds in [-2.5,0,0.0001,10000]:rows.append(run(dict(kind='add',duration=1,seconds=seconds)))
for present,status,item,null,ids in itertools.product([False,True],[0,1],[False,True],[False,True],[[],['0000000000000001'],['1000000000000001'],['1000000000000001','2000000000000002','1000000000000001']]):rows.append(run(dict(kind='remove',present=present,status=status,item=item,null=null,ids=ids)))
out=m.root/'backups/animations/native-item-property-command-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
