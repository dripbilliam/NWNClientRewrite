"""Unchanged GetActionPoint1404201e0 and GetNearestActionPoint140420360.
Point transforms, magnitude, state/side narrowing, selection/fallback execute.
Only GetArea, PositionWalkable and scalar sqrt runtime are captured boundaries.
The native DWK loader and walkability owners are compared separately.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);door,surface,fromPoint,out,area=[m.heap+n*0x2000 for n in range(1,6)]
def vec(a):return[m.rf(a+i*4) for i in range(3)]
def writevec(a,v):
 for i,n in enumerate(v):m.wf(a+i*4,n)
def hook(u,a,n,_):
 global walkIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140494e80:calls.append(['area']);m.finish(area if c.get('area',True) else 0)
 elif a==0x140364bc0:calls.append(['walkable',vec(y)]);results=c.get('walk',[1,1,1,1]);m.finish(results[min(walkIndex,len(results)-1)]);walkIndex+=1
 elif a==0x140c7d6d8:
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1404201e0,0x1404202da),(0x140420360,0x1404207e3),(0x1402303d0,0x14023040d),(0x14022b180,0x14022b1ae)]):raise AssertionError(f'Uncaptured door action-point dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,walkIndex
 c=case;calls=[];walkIndex=0;u.mem_write(m.heap,bytes(0x100000));m.wq(door+0x4c0,surface);m.wi(door+0xd8,c['animation']);writevec(door+0xa4,c.get('position',[10,20,3]));writevec(door+0xb0,c.get('orientation',[0,1,0]));writevec(fromPoint,c.get('from',[10,19,3]))
 for i,p in enumerate(c['points']):writevec(surface+0x90+i*12,p)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,door);u.reg_write(UC_X86_REG_RDX,out)
 if c['operation']=='point':u.reg_write(UC_X86_REG_R8,c['animation']&0xffffffff);u.reg_write(UC_X86_REG_R9,c['side']&0xffffffff);start=0x1404201e0
 else:u.reg_write(UC_X86_REG_R8,fromPoint);u.reg_write(UC_X86_REG_R9,c['force']&0xffffffff);start=0x140420360
 try:u.emu_start(start,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop;return dict(case=c,calls=calls,point=vec(out))
if __name__=='__main__':
 points=[[[-1,-2,0],[1,2,0],[-2,1,1],[2,-1,2],[-3,1,3],[3,1,3]],[[0,0,0]]*6,[[-10,-20,-3]]*6,[[1001,1001,0],[-1001,-1001,0],[1,0,0],[0,1,0],[2,2,0],[-2,-2,0]]]
 rows=[run(dict(operation='point',animation=animation,side=side,orientation=orientation,points=points[0])) for animation,side,orientation in itertools.product([-1,0,22,50,51,72,278],[0,1,256,257],[[0,1,0],[1,0,7],[.6,.8,0],[3,-4,0]])]
 rows += [run(dict(operation='nearest',animation=animation,force=force,area=area,points=points,orientation=orientation,walk=walk,position=position)) for animation,force,area,points,orientation,walk,position in itertools.product([22,50,51,72,23],[0,1,-7],[False,True],points,[[0,1,0],[3,-4,0]],[[0,0,0,0],[0,1,0,1],[1,0,1,0],[1,1,1,1],[2,2,2,2]],[[10,20,3],[0,0,0]])]
 out=m.root/'backups/animations/native-door-action-point-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
