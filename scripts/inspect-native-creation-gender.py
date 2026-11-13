"""Unchanged original Gender prepare/select/OK/Cancel callbacks in isolation.
Original programmatic SelectTab and SetChecked also execute, without turning
initialization into a click callback. Object lookup, layout import, text/update
delivery, tab-array insertion and modal lifetime are explicit GUI providers.
No live game, GPU or save.
"""
import importlib.util,json,struct,itertools
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,creature,stats,vtable=[m.heap+n for n in[0x1000,0x5000,0x9000,0xd000]]
ranges=[(0x1408ede10,0x1408edfa6),(0x1408e14a0,0x1408e1501),(0x1408e56e0,0x1408e5758),(0x1408e1290,0x1408e12c1),(0x1401eff30,0x1401eff8c),(0x1401e5ae0,0x1401e5b38)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140800c90:m.finish(creature if present else 0)
 elif a in[0x1401fe0b0,0x1401fb540,m.stop+0x10]:m.finish()
 elif a==0x1401ed880:
  count=m.si(x+0x20);array=m.heap+0xe000;m.wq(x+0x18,array);m.wq(array+count*8,y);m.wi(x+0x20,count+1);m.finish()
 elif a==0x1401fb890:texts[hex(x-panel)]=y&0xffffffff;m.finish()
 elif a==0x1401fc440:codes.append(y&0xffffffff);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped original Gender dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(gender,selected,exists,cancel):
 global present,texts,codes
 present=exists;texts={};codes=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(panel,vtable);m.wq(vtable,m.stop+0x10);m.wq(creature+0x3b0,stats);u.mem_write(stats+0x68,bytes([gender]));m.wi(panel+0x9b8,42);m.wi(panel+0x9d0,-1)
 call(0x1408ede10,[panel]);initial=dict(selected=m.si(panel+0x9d0),help=dict(texts),gender=int(u.mem_read(stats+0x68,1)[0]))
 m.wi(panel+0x9d0,selected)
 if selected in[0,1]:call(0x1408e14a0,[panel,selected])
 selection=dict(help=dict(texts),gender=int(u.mem_read(stats+0x68,1)[0]))
 call(0x1408e1290 if cancel else 0x1408e56e0,[panel]);assert len(codes)==1
 return dict(input=dict(gender=gender,selected=selected,present=exists,cancel=cancel),initial=initial,selection=selection,output=dict(gender=int(u.mem_read(stats+0x68,1)[0]),code=codes[0]))
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-gender-observations-v2.json';assert not out.exists(),'Preserve prior evidence'
 rows=[run(*args)for args in itertools.product([0,1,2,255],[-1,0,1,2],[False,True],[False,True])]
 out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,procedures=['0x1408ede10','0x1408e14a0','0x1408e56e0','0x1408e1290','0x1401eff30','0x1401e5ae0'],rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
