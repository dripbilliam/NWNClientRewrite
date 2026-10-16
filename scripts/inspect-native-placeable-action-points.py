"""Original placeable ComputeBoundingBox1404b1bf0/GetNearestActionPoint1404b3f20,
actual Vector+=14022b180, magnitude1402303d0 and finite/infinite atanf140c94418.
GetArea, active PWK lookup, terrain height, scalar sqrt and CRT flag-raise are
lower boundaries. No PWK assets copied. NaN/CRT floating state is not proved.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,mesh,area,app,source,out=[m.heap+n*0x1000 for n in range(1,7)]
ranges=[(0x1404b1bf0,0x1404b1e0b),(0x1404b3f20,0x1404b4057),(0x14022b180,0x14022b1ae),(0x1402303d0,0x14023040d),(0x140c94418,0x140c945f9)]
def vec(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def wvec(ptr,v):u.mem_write(ptr,struct.pack('<3f',*v))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140494e80:calls.append(['area']);m.finish(area if c.get('area',True) else 0);return
 if a==0x14055b880:m.finish(app);return
 if a==0x1402cd9b0:calls.append(['mesh',y]);m.finish(mesh if c.get('mesh',True) else 0);return
 if a==0x14036a210:calls.append(['height',vec(y)]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['height']),'little'));m.finish();return
 if a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish();return
 if a==0x140cae8e0:assert x==32;m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured placeable point dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,mode):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);wvec(actor+0xa4,c.get('position',[10,20,3]));wvec(actor+0xb0,c.get('orientation',[0,1,0]));u.mem_write(actor+0x32c,struct.pack('<H',c.get('appearance',50)&65535))
 for i,point in enumerate(c.get('local',[[1,2,0],[-1,-2,0]])):wvec(mesh+0x48+i*12,point)
 for i,point in enumerate(c.get('old',[[7,8,9],[-7,-8,-9]])):wvec(actor+0x550+i*12,point)
 wvec(source,c.get('from',[10,20,3]));rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,out);u.reg_write(UC_X86_REG_R8,source)
 try:u.emu_start(0x1404b1bf0 if mode=='compute' else 0x1404b3f20,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,mode=mode,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(mode=mode,case=c,calls=calls,points=[vec(actor+0x550+i*12) for i in range(2)],point=vec(out) if mode=='nearest' else None)
rows=[]
for local,position,orientation,height,old in itertools.product([[[0,0,0],[0,0,0]],[[1,2,0],[-1,-2,0]],[[1,0,17],[0,1,-19]],[[0,0,0],[1,2,3]],[[.01,0,5],[100,0,0]]],[[10,20,3],[0,0,0],[16777216,.0001,30]],[[0,1,0],[.6,.8,0],[3,-4,0]],[-100,-5,0,3,100],[[[0,0,0],[0,0,0]],[[7,8,9],[-7,-8,-9]]]):rows.append(run(dict(local=local,position=position,orientation=orientation,height=height,old=old),'compute'))
for hasArea,hasMesh,appearance in itertools.product([False,True],[False,True],[0,65535,65536,65586]):rows.append(run(dict(area=hasArea,mesh=hasMesh,appearance=appearance,height=0),'compute'))
for points,fromp,position in itertools.product([[[0,0,0],[0,0,0]],[[0,0,0],[1,2,3]],[[1,2,3],[0,0,0]],[[1,2,3],[-1,-2,-3]],[[1,0,0],[-1,0,0]],[[1000,0,0],[1000,0,0]]],[[0,0,0],[10,20,3],[1,2,3],[-1,-2,-3]],[[10,20,3],[0,0,0]]):rows.append(run(dict(old=points,fromp=fromp,**{'from':fromp},position=position),'nearest'))
outpath=m.root/'backups/animations/native-placeable-action-point-observations.json';outpath.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,angleLimit=struct.unpack('<d',u.mem_read(0x140df3778,8))[0],rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(outpath))))
