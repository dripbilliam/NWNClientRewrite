"""Untouched EffectVisualEffect command14051c820. VM pops/push, allocation,
base effect constructor and creator tagging are captured. Real type/flag and
INT/FLOAT/vector setters execute; transforms and optional grouping are verified.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,wi,wq,si=[getattr(m,n) for n in ['q','wi','wq','si']]
command,vm,effect,integers=[m.heap+n*0x1000 for n in range(1,5)]
def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140286110:wi(y,args.pop(0));m.finish(1)
    elif a==0x1402860c0:u.mem_write(y,struct.pack('<f',c.get('scale',1)));m.finish(1)
    elif a==0x140286250:u.mem_write(y,struct.pack('<3f',*(c.get('translate',[1,2,3]) if not vectorReads else c.get('rotate',[4,5,6]))));vectorReads.append(1);m.finish(1)
    elif a==0x140c10324:m.finish(effect)
    elif a==0x1404233d0:
        u.mem_write(effect,bytes(0x110));wq(effect+0x48,integers);wi(effect+0x40,8);wi(effect+0x1c,-1);wi(effect+0x28,-1);m.finish(effect)
    elif a==0x140425110:wi(effect+0x18,y);wi(effect+0x1c,17);wi(effect+0x28,3);m.finish()
    elif a==0x140286330:
        output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=int.from_bytes(u.mem_read(z+10,2),'little'),creatorId=si(z+0x18)&0xffffffff,
          spellId=si(z+0x1c),casterLevel=si(z+0x28),integers=list(struct.unpack('<8i',u.mem_read(q(z+0x48),32))),floats=list(struct.unpack('<4f',u.mem_read(z+0x50,16))),vectors=[list(struct.unpack('<3f',u.mem_read(z+0xd0+i*12,12))) for i in range(2)])
        m.finish(1)
    elif a in [0x140423770,0x140c10360]:m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x14051c820,0x14051c9e0),(0x140425210,0x14042521c),(0x140425200,0x14042520a),(0x140425340,0x140425361)]):raise AssertionError(f'Uncaptured visual constructor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,args,output,vectorReads
    c=case;output=None;vectorReads=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df910,vm);wi(command+0xc,99)
    args=[c.get('id',1),c.get('miss',0)];rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,180,c.get('argc',2)]):u.reg_write(reg,value)
    u.emu_start(0x14051c820,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,output=output)
rows=[]
for argc,id,miss,scale in itertools.product([1,2,5],[-1,0,1,119,65536,2147483647],[-1,0,1,2],[-2,0,.5,1,2]):rows.append(run(dict(argc=argc,id=id,miss=miss,scale=scale)))
out=m.root/'backups/animations/native-visual-constructor-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
