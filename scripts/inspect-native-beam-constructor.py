"""Untouched EffectBeam140517cb0: capture VM/resource/allocation boundaries;
execute native admission, type, argument grouping and effect setters unchanged.
No game executable or assets are copied or modified.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,vm,effect,integers,app,rules,table,string=[m.heap+n*0x1000 for n in range(1,9)]
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140286110,0x140286160]:m.wi(y,args.pop(0));m.finish(1)
 elif a==0x1402860c0:u.mem_write(y,struct.pack('<f',c.get('scale',1)));m.finish(1)
 elif a==0x140286250:u.mem_write(y,struct.pack('<3f',*([1,2,3] if not vectors else [-4,5,6])));vectors.append(1);m.finish(1)
 elif a==0x140c10324:m.finish(effect)
 elif a==0x140c10368:m.finish(string+0x200)
 elif a==0x1404233d0:
  u.mem_write(effect,bytes(0x110));m.wq(effect+0x48,integers);m.wi(effect+0x40,8);m.wi(effect+0x18,0x7f000000);m.wi(effect+0x1c,-1);m.wi(effect+0x28,-1);m.finish(effect)
 elif a==0x140425110:m.wi(effect+0x18,y);m.wi(effect+0x1c,17);m.wi(effect+0x28,3);m.finish()
 elif a==0x1401a68f0:m.wq(w,string);u.mem_write(string,c['kind'].encode()+b'\0');m.finish(c.get('found',1))
 elif a==0x14016c8c0:m.wq(y,string);u.mem_write(string,c['kind'].upper().encode()+b'\0');m.finish(y)
 elif a==0x140286330:
  output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=int.from_bytes(u.mem_read(z+10,2),'little'),creatorId=m.si(z+0x18)&0xffffffff,
   spellId=m.si(z+0x1c),casterLevel=m.si(z+0x28),integers=list(struct.unpack('<8i',u.mem_read(m.q(z+0x48),32))),objectIds=list(struct.unpack('<4I',u.mem_read(z+0xc0,16))),
   floats=list(struct.unpack('<4f',u.mem_read(z+0x50,16))),vectors=[list(struct.unpack('<3f',u.mem_read(z+0xd0+i*12,12))) for i in range(2)]);m.finish(1)
 elif a in [0x140423770,0x140c10360,0x140c10370]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140517cb0,0x140517fe3),(0x140425210,0x14042521c),(0x140425200,0x14042520a),(0x140425340,0x140425361),(0x140425300,0x140425314)]):raise AssertionError(f'Uncaptured beam dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,args,output,vectors
 c=case;args=[c['id'],0x80000001,c['body'],c['miss']];output=None;vectors=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,vm);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x280,table);m.wi(command+0xc,99)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,143,c['argc']]):u.reg_write(reg,v)
 u.emu_start(0x140517cb0,m.stop,count=4000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,output=output)
rows=[run(dict(argc=argc,id=id,body=body,miss=miss,kind=kind,found=found,scale=scale)) for argc,id,body,miss,kind,found,scale in itertools.product([4,7],[-1,100,65536],[-1,0,4],[0,1],['B','b','BA','D',''],[0,1],[0,.5,2])]
out=m.root/'backups/animations/native-beam-constructor-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
