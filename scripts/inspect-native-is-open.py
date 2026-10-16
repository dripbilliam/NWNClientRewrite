"""Read-only full original GetIsOpen VM command and door open-state getter.
VM pop/push, canonical lookup and virtual casts are captured; successful
queries run the original door leaf including cached-state mutation.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,vtPtr,appPtr,commandPtr=[m.heap+n*0x1000 for n in range(1,5)]
def hook(u,a,n,_):
 global pushed
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140286160:calls.append(['popObject']);m.wi(y,c.get('id',100));m.finish(c.get('pop',1));return
 if a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(objectPtr if c.get('object',True) else 0);return
 if a==m.stop+0x10:calls.append(['asDoor']);m.finish(objectPtr if c.get('door',False) else 0);return
 if a==m.stop+0x18:calls.append(['asPlaceable']);m.finish(objectPtr if c.get('placeable',False) else 0);return
 if a==0x1404207f0:calls.append(['openState'])
 if a==0x140286410:pushed=y&0xffffffff;calls.append(['pushInteger',pushed]);m.finish(c.get('push',1));return
 if not any(lo<=a<hi for lo,hi in [(0x140527490,0x14052755f),(0x1404207f0,0x140420852)]):raise AssertionError(f'Uncaptured GetIsOpen dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,pushed
 c=case;calls=[];pushed=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(objectPtr,vtPtr);m.wq(vtPtr+0x30,m.stop+0x10);m.wq(vtPtr+0x98,m.stop+0x18);m.wi(objectPtr+0xd8,c.get('animation',75));m.wi(objectPtr+0x498,c.get('field498',1));u.mem_write(objectPtr+0x42c,bytes([c.get('cached',0)]))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,commandPtr)
 try:u.emu_start(0x140527490,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,pushed=pushed,cached=u.mem_read(objectPtr+0x42c,1)[0])
rows=[run(dict(door=door,placeable=placeable,animation=animation,field498=field,cached=cached)) for door,placeable,animation,field,cached in itertools.product([False,True],[False,True],[-1,0,22,50,51,72,73,75,76,255],[0,1,2],[0,1,2,3,7,255])]
rows += [run(dict(**{key:value})) for key,values in {'object':[False],'id':[0,0x7f000000,0x80000055],'pop':[0],'push':[0]}.items() for value in values]
out=m.root/'backups/animations/native-is-open-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
