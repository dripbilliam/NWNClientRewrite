"""Original initialize987f10 random kinds4/9/12, with actual normalize,
magnitude, acosf, positive logf and embedded SSE sinf/cosf. Object/model/part
lookups, CRT draw stream, sqrtf/FP status and kind12 newRef(null) are captured.
Explicit SSE dispatch0/round-nearest; kind12 graph parenting is not executed.
"""
import importlib.util,json,struct,itertools,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,node,obj,ovt,model,mvt,app,argument=[m.heap+n*0x1000 for n in range(1,9)]
modelHandle,partPose=m.stop+0x10,m.stop+0x20
ranges=[(0x140987f10,0x140988d59),(0x140230920,0x1402309f6),(0x1402303d0,0x14023040d),(0x140c79a38,0x140c79c87),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360)]
r=json.loads((m.root/'backups/animations/rea-client-projectile-special-distance-round.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(e['start'],16),int(e['end'],16)+1)for e in r['ranges'])
def vector(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def bits(a):return list(struct.unpack('<3I',u.mem_read(a,12)))
def write(a,v):u.mem_write(a,struct.pack('<3f',*v))
def hook(u,a,n,_):
 global seed
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb70:m.finish(m.heap+0x9000)
 elif a==0x140296470:calls.append(['getObject',y&0xffffffff]);m.wq(z,obj);m.finish(c['lookup'])
 elif a==modelHandle:calls.append(['model']);m.finish(model)
 elif a==partPose:
  calls.append(['nodePose']);assert m.q(w)==0x3f800000
  if c['pose']:write(z,[10,11,12])
  m.finish(c['pose'])
 elif a==0x140c7ed00:seed=(seed*214013+2531011)&0xffffffff;draw=(seed>>16)&0x7fff;calls.append(['random',draw]);m.finish(draw)
 elif a==0x140c7d6d8:
  v=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(v)),'little'));m.finish()
 elif a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x1400931f0:
  text=lambda p:bytes(u.mem_read(p,32)).split(b'\0')[0].decode('ascii');calls.append(['newRef',text(x),text(y)]);m.finish(0)
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured random initializer dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,seed
 c=case;calls=[];seed=c['seed'];u.mem_write(m.heap,bytes(0x10000));m.wq(0x1412df970,app);m.wi(0x1415d8224,0);m.wi(0x141428e7c,c['angleSide']);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 write(actor+0x38,c['position']);write(actor+0x44,c['orientation']);write(actor+0x188,[8,9,10]);write(actor+0x204,[2,3,4]);write(actor+0x210,[5,6,7]);m.wi(actor+0x194,c['remaining']);m.wi(actor+0x198,c['targetId']);m.wq(actor+0x228,node);u.mem_write(node+0x2d,bytes([c['kind']]));write(node,[4,5,6]);m.wq(obj,ovt);m.wq(ovt+0x140,modelHandle);u.mem_write(obj+0xc,b'\x05');write(obj+0x38,[21,22,23]);m.wq(model,mvt);m.wq(mvt+0x138,partPose);m.wq(actor+0x1a0,m.heap+0xa000);u.mem_write(m.heap+0xa000,b'impact\0')
 ptr=actor+0x44 if c['alias'] else argument;write(ptr,c['orientation']);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,ptr)
 try:u.emu_start(0x140987f10,m.stop,count=20000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,argument=bits(ptr),orientation=bits(actor+0x44),velocity=bits(actor+0x204),acceleration=bits(actor+0x210),angleSide=m.si(0x141428e7c)&0xffffffff,seed=seed,auxiliary=bool(m.q(actor+0x230)))
default=dict(position=[1.25,-2,3.5],alias=False)
rows=[run(default|dict(kind=kind,angleSide=side,seed=seed,remaining=time,orientation=orientation,targetId=target,lookup=lookup,pose=pose))for kind,side,seed,time,orientation,target,lookup,pose in itertools.product([4,9,12],[0,1,2],[1,77,0x7fffffff],[0,16,1000],[[1,0,0],[0,1,0],[0,-1,0],[.5,.25,.75]],[0x7f000000,0x80000063],[0,1],[0,1])]
rows += [run(default|dict(kind=kind,angleSide=0,seed=1,remaining=1000,orientation=[.5,.25,.75],targetId=0x7f000000,lookup=0,pose=0,alias=True))for kind in [4,9,12]]
rows += [run(default|dict(kind=kind,angleSide=1,seed=1,remaining=0,orientation=[.5,.25,.75],targetId=0x7f000000,lookup=0,pose=0,position=position))for kind,position in itertools.product([4,9,12],[[4,5,6],[4.0000005,5,6]])]
out=m.root/'backups/animations/native-client-projectile-random-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
