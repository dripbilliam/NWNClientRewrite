"""Original CNWCProjectile basic9845c0 and spiral9848d0, including actual
normalize230920. Imported sqrtf and position/orientation virtual calls are
captured boundaries; sqrtf returns a correctly rounded binary32 square root.
Synthetic native state does not exercise path construction, AI or model assets.
All inputs are finite; zero remaining time intentionally preserves native NaNs.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
projectile,vtable,node=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000
setPosition,setOrientation=m.stop+0x10,m.stop+0x20
ranges=[(0x1409845c0,0x1409848cc),(0x1409848d0,0x140984c14),(0x140230920,0x1402309f6)]
def point(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def bits(a):return list(struct.unpack('<3I',u.mem_read(a,12)))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a in [setPosition,setOrientation]:
  x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]];assert x==projectile
  calls.append(dict(kind='position' if a==setPosition else 'orientation',bits=bits(y)))
  u.mem_write(projectile+(0x38 if a==setPosition else 0x44),bytes(u.mem_read(y,12)));m.finish()
 elif a==0x140c7d6d8:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0]
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(value)),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured motion dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global calls
 calls=[];u.mem_write(m.heap,bytes(0x10000));m.wq(projectile,vtable);m.wq(vtable+0x120,setOrientation);m.wq(vtable+0x128,setPosition);m.wq(projectile+0x228,node)
 for off,key in [(0x38,'position'),(0x188,'endpoint'),(0x210,'acceleration')]:u.mem_write(projectile+off,struct.pack('<3f',*c[key]))
 u.mem_write(node+0xc,struct.pack('<3f',*c['attachment']));m.wi(projectile+0x194,c['remaining']);m.wi(projectile+0x58,c['elapsed']);u.mem_write(projectile+0x238,bytes([c['spiralSide'],c['facing']]))
 observations=[]
 for _ in range(c['steps']):
  rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,projectile)
  u.emu_start(0x1409845c0 if c['kind']=='basic' else 0x1409848d0,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
  observations.append(dict(position=bits(projectile+0x38),velocity=bits(projectile+0x204),calls=list(calls)));calls=[]
  m.wi(projectile+0x194,max(0,m.si(projectile+0x194)-c['elapsed']))
 return dict(case=c,observations=observations)
default=dict(position=[1.25,-2,3.5],endpoint=[4,5,6],acceleration=[0,0,-9.8],attachment=[7,-2,9],remaining=1000,elapsed=16,spiralSide=0,facing=0,steps=1)
rows=[run(default|dict(kind=kind,remaining=remaining,elapsed=elapsed,facing=facing,spiralSide=side))for kind,remaining,elapsed,facing,side in itertools.product(['basic','spiral'],[0,1,17,999,1000,0x80000000,0xffffffff],[0,1,16,1000,0xffffffff],[0,1,2,3,255],[0,1,255])]
rows += [run(default|dict(kind=kind,position=position,endpoint=endpoint,acceleration=acceleration,facing=facing,spiralSide=side))for kind,position,endpoint,acceleration,facing,side in itertools.product(['basic','spiral'],[[0,0,0],[1.25,-2,3.5]],[[0,0,0],[1.25,-2,3.5],[1e-6,1e-6,0],[1,0,0]],[[0,0,0],[1,2,3]],[0,1,2,3],[0,1])]
rows += [run(default|dict(kind=kind,steps=60,remaining=1000,elapsed=16,facing=facing,spiralSide=side))for kind,facing,side in itertools.product(['basic','spiral'],[0,1,2],[0,1])]
out=m.root/'backups/animations/native-client-projectile-motion-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),steps=sum(len(r['observations'])for r in rows),output=str(out))))
