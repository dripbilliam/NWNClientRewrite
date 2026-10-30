"""Read-only isolated original projectile builders986db0 (11/12) and985f20
(13), with original magnitude, CHitInfo initialization and finite SSE CRT trig.
The sqrtf boundary is correctly rounded binary32. Object presence, scene ray
results, allocation/list ownership and CRT random
draws are explicit authored lower boundaries, not a real scene/server test.
No original process is touched and no executable bytes are written to disk.
"""
import importlib.util,itertools,json,struct,sys,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,app,area,render,scene,vt,linked=[m.heap+n*0x1000 for n in range(1,8)];ray=m.stop+0x10
ranges=[(0x140986db0,0x1409873bc),(0x140985f20,0x140986390),(0x1402303d0,0x14023040d),(0x1400c0c40,0x1400c0c9c),(0x1400c5a90,0x1400c5b44),(0x140c94418,0x140c945f9),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360)]
def vec(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def bits(a):return list(struct.unpack('<3I',u.mem_read(a,12)))
def write(a,v):u.mem_write(a,struct.pack('<3f',*v))
def node(a):return dict(point=bits(a),attachment=bits(a+12),targetId=m.si(a+24)&0xffffffff,childPath=m.si(a+28)&0xffffffff,duration=m.si(a+32)&0xffffffff,threshold=m.si(a+36)&0xffffffff,radiusBits=m.si(a+40)&0xffffffff,spawnCount=u.mem_read(a+44,1)[0],kind=u.mem_read(a+45,1)[0])
def hook(u,a,_n,_):
 global allocation,ray_index
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb60:calls.append(['clientObject',y&0xffffffff]);m.finish(actor if c['client'] else 0)
 elif a==0x1406abea0:m.finish(area)
 elif a==0x140169030:queue.append(y);m.finish()
 elif a==0x140c10324:
  assert x==48;calls.append(['allocate',48]);p=m.heap+0x10000+allocation*0x100;allocation+=1;u.mem_write(p,b'\xa5'*48);m.finish(p)
 elif a==ray:
  info=m.q(u.reg_read(UC_X86_REG_RSP)+0x28);calls.append(['ray',bits(y),bits(z),m.si(info),hex(m.q(info+8)),m.si(info+32)])
  value=c['hits'][ray_index];height=c['heights'][ray_index];ray_index+=1
  if value:write(w,[vec(y)[0],vec(y)[1],height])
  m.finish(value)
 elif a==0x140c7ed00:calls.append(['random']);m.finish(c['random'])
 elif a==0x140c7d6d8:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(value)),'little'));m.finish()
 elif a in [0x140c4f024,0x140cae8e0]:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured builder dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,queue,allocation,ray_index
 c=case;calls=[];queue=[];allocation=ray_index=0;u.mem_write(m.heap,bytes(0x20000));m.wq(0x1412df970,app);m.wq(area+0xf8,render);m.wq(render+0x248,scene if c['scene'] else 0);m.wq(scene,vt);m.wq(vt+0x58,ray);m.wq(actor+0x220,linked)
 for off,key in [(0x38,'position'),(0x44,'orientation'),(0x188,'endpoint')]:write(actor+off,c[key])
 m.wi(actor+0x198,c['targetId']);m.wi(actor+0x21c,c['duration']);m.wi(0x1415d8224,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,1 if c['path']==11 else 0)
 try:u.emu_start(0x140985f20 if c['path']==13 else 0x140986db0,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,nodes=[node(p)for p in queue])
default=dict(path=11,targetId=0x80000064,client=1,scene=1,position=[1.25,-2,3.5],endpoint=[4,5,6],orientation=[.5,.25,.75],duration=1000,hits=[1,1],heights=[.75,-.25],random=1)
rows=[run(default|dict(path=path,targetId=target,client=client,scene=scene,duration=duration,hits=hits,orientation=orientation))for path,target,client,scene,duration,hits,orientation in itertools.product([11,12,13],[0x7f000000,0x80000064],[0,1],[0,1],[0,1,78,1000,0xffffffff],[[0,0],[1,0],[0,1],[1,1]],[[.5,.25,.75],[-1,0,0],[0,1,0]])]
rows += [run(default|dict(path=13,orientation=[x,y,0],random=random))for x,y,random in itertools.product([-1,-.0001,.0001,1],[-1,0,1],[0,1,1569,1570,32767])]
out=m.root/'godot-client/reports/native-projectile-bounce-original-v1.json'
with out.open('x')as f:json.dump(dict(binarySha256=m.digest,limits=__doc__,rows=rows),f);f.write('\n')
print(json.dumps(dict(rows=len(rows),output=str(out))))
