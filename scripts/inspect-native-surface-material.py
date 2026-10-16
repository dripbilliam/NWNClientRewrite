"""Original surface material1402bedf0, CNWSTile wrapper1404fdc90,
area14035eaf0 and PositionWalkable140364bc0, including original rotation leaf.
Only tile location, 2DA GetINTEntry, temporary allocation and free are captured.
Nonempty synthetic loaded surfaces avoid resource-demand/error branches.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);surface,vertices,faces,materials,area,point,rules,ruleData,table=[m.heap+n*0x1000 for n in range(1,10)];tiles=m.heap+0x10000;info=m.heap+0x60000
def vec(a):return[m.rf(a+i*4) for i in range(3)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402c55a0:index=(x-tiles)//0x68;m.wi(y,index%c['width']);m.wi(z,index//c['width']);m.finish()
 elif a==0x140c10368:m.finish(m.heap+0x70000)
 elif a==0x140c10370:m.finish()
 elif a==0x1401a7010:
  index=y&0xffffffff;calls.append(['intEntry',index]);m.wi(w,c['walk'].get(str(index),c['default']));m.finish(0)
 elif not any(lo<=a<hi for lo,hi in [(0x1402bedf0,0x1402bf05e),(0x1404fdc90,0x1404fdd1f),(0x14035eaf0,0x14035edb7),(0x140364bc0,0x140364c8a),(0x1402c5760,0x1402c57ca)]):raise AssertionError(f'Uncaptured material dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(surface+0x78,faces);m.wq(surface+0xd0,vertices);m.wq(surface+0x98,materials);m.wi(surface+0x64,len(c['faces']));m.wq(info+8,surface)
 for i,v in enumerate([[0,0,0],[10,0,1],[10,10,2],[0,10,3]]):
  for n,value in enumerate(v):m.wf(vertices+i*12+n*4,value)
 for i,face in enumerate(c['faces']):
  for n,value in enumerate(face):m.wi(faces+i*12+n*4,value)
  m.wi(materials+i*4,c['materials'][i])
 m.wi(area+0xc,c['width']);m.wi(area+0x10,c['height']);m.wq(area+0x1c8,tiles)
 for i in range(c['width']*c['height']):m.wi(tiles+i*0x68+0x24,c['orientation']);m.wq(tiles+i*0x68+0x30,info)
 for i,v in enumerate(c['point']):m.wf(point+i*4,v)
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,ruleData);m.wq(ruleData+0x110,table)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface if c['operation']=='surface' else area);u.reg_write(UC_X86_REG_RDX,point)
 start={'surface':0x1402bedf0,'area':0x14035eaf0,'walk':0x140364bc0}[c['operation']]
 try:u.emu_start(start,m.stop,count=20000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop;return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls)
if __name__=='__main__':
 default=dict(width=2,height=2,faces=[[0,1,2],[0,2,3]],materials=[1,2],walk={'0':0,'1':1,'2':-7},default=9)
 rows=[run(default|dict(operation=op,orientation=orientation,point=point,faces=faces,materials=materials)) for op,orientation,point,faces,materials in itertools.product(['surface','area','walk'],[0,1,2,3],[[0,0,999],[5,5,0],[2,8,-99],[8,2,0],[10,10,0],[10.000001,10,0],[-.00001,1,0],[15,15,0],[20,1,0],[320,1,0]],[[[0,1,2],[0,2,3]],[[0,1,2],[0,1,2]],[[0,2,1],[0,3,2]]],[[1,2],[2,1],[100,101]])]
 out=m.root/'backups/animations/native-surface-material-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
