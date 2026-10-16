"""Original three automap VM wrappers, with valid decoded stack arguments.
Stack pop/push, canonical lookup/type casts and map owners are captured helper
boundaries. Covers argument/body semantics, not VM underflow/type-error parity.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,area,app,vt=[m.heap+i*0x1000 for i in range(4)]
def signed(v):return m.struct.unpack('<i',m.struct.pack('<I',v&0xffffffff))[0]
def hook(u,a,n,_):
 global popped,pushed
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140286160,0x140286110]:m.wi(y,c['args'][popped]);popped+=1;m.finish(1)
 elif a==0x140286410:pushed=signed(y);m.finish(1)
 elif a==0x14055b2e0:calls.append(['area',y&0xffffffff]);m.finish(area if c['area'] else 0)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(app if c['client'] else 0)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c['creature'] else 0)
 elif a==0x14055b4c0:
  id=y&0xffffffff;calls.append(['object',id]);m.finish(area if id==88 and c['area'] else actor if id==99 and c['creature'] else 0)
 elif a==m.stop+0x100:calls.append(['asArea',88]);m.finish(area if c['areaType'] else 0)
 elif a==m.stop+0x110:calls.append(['asCreature',99]);m.finish(actor if c['creatureType'] else 0)
 elif a==0x1403a2ac0:calls.append(['reveal',99,y&0xffffffff,signed(z)]);m.finish()
 elif a==0x140393270:calls.append(['explored',99,y&0xffffffff,signed(z),signed(w)]);m.finish(c['previous'])
 elif a==0x1403a4330:calls.append(['setTile',99,y&0xffffffff,signed(z),signed(w),m.si(rsp+0x28)]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14051d830,0x14051d91e),(0x140548aa0,0x140548c34),(0x140510f30,0x140511010)]):raise RuntimeError(f'Unmapped automap VM dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,popped,pushed
 c=case;calls=[];popped=0;pushed=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vt);m.wq(area,vt);m.wi(area+0x140,88);m.wi(actor+0x6e0,c['old']);m.wq(vt+0x50,m.stop+0x100);m.wq(vt+0x60,m.stop+0x110)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[app,c['command'],len(c['args'])]):u.reg_write(reg,v)
 address=0x14051d830 if c['command']==403 else 0x140548aa0 if c['command'] in [866,867] else 0x140510f30
 u.emu_start(address,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;assert u.reg_read(UC_X86_REG_RAX)==0
 return dict(case=c,calls=calls,result=pushed,enabled=m.si(actor+0x6e0))
default=dict(area=True,client=True,creature=True,areaType=True,creatureType=True,previous=1,old=1);rows=[]
for area_,client,creature,value in itertools.product([False,True],[False,True],[False,True],[None,0,1,-2]):rows.append(run(default|dict(command=403,area=area_,client=client,creature=creature,args=[88,99]+([] if value is None else [value]))))
for command,area_,creature,atype,ctype,x,y,previous in itertools.product([866,867],[False,True],[False,True],[False,True],[False,True],[-1,0,31,32],[0,31],[0,1]):rows.append(run(default|dict(command=command,area=area_,creature=creature,areaType=atype,creatureType=ctype,previous=previous,args=[99,88,x,y]+([-2] if command==866 else []))))
for command,creature,ctype,old,value in itertools.product([868,869],[False,True],[False,True],[-2,0,1,27],[-4,0,2]):rows.append(run(default|dict(command=command,creature=creature,creatureType=ctype,old=old,args=[99]+([value] if command==868 else []))))
out=m.root/'backups/animations/native-automap-script-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
