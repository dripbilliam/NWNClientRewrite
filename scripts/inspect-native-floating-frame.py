"""Original CGuiInGameFloatyText frame972840..972a63, varied remaining time,
delta, shadow, owner/model/world availability and projected screen positions.
Lookup, camera projection, label color, panel position and destructor are
captured lower providers. Original float arithmetic, gates and rounding execute.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
widget,actor,model,world,camera,label,shadow,app,vtable=[m.heap+n*0x1000 for n in range(1,10)]
getModel,destroy,project=m.stop+0x100,m.stop+0x110,m.stop+0x120
def f(p):return struct.unpack('<f',u.mem_read(p,4))[0]
def wf(p,v):u.mem_write(p,struct.pack('<f',v))
def regf(r):return struct.unpack('<f',struct.pack('<I',u.reg_read(r)&0xffffffff))[0]
def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop:u.emu_stop();return
 if a==destroy:calls.append(['destroy',y]);m.finish();return
 if a==0x1406abb60:calls.append(['object',y&0xffffffff]);m.finish(actor if case['actor']else 0);return
 if a==getModel:calls.append(['model']);m.finish(model if case['model']else 0);return
 if a==0x1406abea0:calls.append(['world']);m.finish(world if case['world']else 0);return
 if a==project:
  calls.append(['project',list(struct.unpack('<fff',u.mem_read(z,12)))]);u.mem_write(y,struct.pack('<fff',case['screen'][0],case['screen'][1],0));u.reg_write(UC_X86_REG_RAX,y);m.finish(y);return
 if a==0x1401eb5c0:calls.append(['color','foreground'if x==label+0x80 else'background',regf(UC_X86_REG_XMM1),regf(UC_X86_REG_XMM2),regf(UC_X86_REG_XMM3),f(sp+0x28)]);m.finish();return
 if a==0x1401fced0:calls.append(['position',list(struct.unpack('<fff',u.mem_read(y,12)))]);m.finish();return
 if 0x140972840<=a<=0x140972a63:return
 raise RuntimeError(f'Unmodeled floaty frame lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for remaining,delta,shadowOn,available,screen in itertools.product([1.5,1.,.5,.25,.001,0.],[0.,.016,.25,.5,1.5,2.],[0,1],[(1,1,1),(0,1,1),(1,0,1),(1,1,0)],[(10.49,20.51),(-2.6,-3.4)]):
 case=dict(remaining=remaining,delta=delta,shadow=shadowOn,actor=available[0],model=available[1],world=available[2],screen=screen);calls=[];u.mem_write(m.heap,bytes(0x20000));u.mem_write(m.stack,bytes(0x20000));m.wq(widget,vtable);m.wq(vtable,destroy);m.wq(actor,vtable+0x100);m.wq(vtable+0x118,getModel);m.wq(world+0xe8,camera);m.wq(camera,vtable+0x200);m.wq(vtable+0x250,project);m.wq(0x1412df970,app);m.wq(app,app);m.wi(widget+0x110,0xffffffff);wf(widget+0x114,1.5);wf(widget+0x118,remaining);m.wi(widget+0x11c,shadowOn);m.wq(widget+0x100,label);m.wq(widget+0x108,shadow);u.mem_write(widget+0xf0,struct.pack('<fff',.25,.5,1.));u.mem_write(model+0x38,struct.pack('<fff',3.,4.,5.))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,widget);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',delta),'little'));error=None
 try:u.emu_start(0x140972840,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 except Exception as e:error=str(e)
 rows.append(dict(case=case,calls=calls,remaining=f(widget+0x118),error=error,rip=hex(u.reg_read(UC_X86_REG_RIP))))
 if error:break
out=m.root/'backups/animations/native-floating-text-frame-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),errors=sorted({r['error']for r in rows if r['error']}),output=str(out))))
