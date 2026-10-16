"""Original PWK ctor1402cdda0 and full LoadWalkMesh1402ce0b0, synthetic
dummy nodes only. Resource demand/release, libc strncmp/sscanf, heap and warning
logging are captured. Native line scan, naming offsets, node state, point slots
and warnings execute. Trimesh/quaternion grammar is not proved by these cases.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);surface,resource,input,ref=[m.heap+n*0x10000 for n in range(1,5)]
def string(ptr):
 result=bytearray()
 for i in range(2048):
  value=u.mem_read(ptr+i,1)[0]
  if not value:return bytes(result)
  result.append(value)
 raise AssertionError('Unbounded fixture string')
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14018ded0:m.finish(x)
 elif a==0x14018df10:m.finish(1)
 elif a in [0x14018f300,0x1402cb720]:m.finish(input)
 elif a==0x1402cb730:m.finish(len(c))
 elif a==0x140c10368:ptr=m.heap+0x80000+allocation*0x1000;allocation+=1;m.finish(ptr)
 elif a in [0x140c10370,0x1401912c0,0x14018f3a0]:m.finish()
 elif a==0x140115890:warnings.append(string(m.q(rsp+0x30)).decode());m.finish()
 elif a==0x140c4ee30:
  left=bytes(u.mem_read(x,z));right=bytes(u.mem_read(y,z));m.finish(next((a-b for a,b in zip(left,right) if a!=b),0))
 elif a==0x140047060:
  assert string(y)==b'%f %f %f';values=string(x).decode().split();count=0
  for ptr,value in zip([z,w,m.q(rsp+0x28)],values):
   try:number=float(value)
   except ValueError:break
   m.wf(ptr,number);count+=1
  m.finish(count)
 elif not any(lo<=a<hi for lo,hi in [(0x1402cdda0,0x1402cde3d),(0x140047300,0x14004730c),(0x1402ce0b0,0x1402ceaeb)]):raise AssertionError(f'Uncaptured PWK point-loader dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface);u.reg_write(UC_X86_REG_RDX,ref)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(text):
 global c,allocation,warnings
 c=text.encode('ascii');allocation=0;warnings=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(surface,bytes([0xa5])*0x100);invoke(0x1402cdda0);m.wq(surface+8,resource);u.mem_write(input,c+b'\0')
 try:invoke(0x1402ce0b0)
 except Exception:print(json.dumps(dict(text=text,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(text=text,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,points=[[m.rf(surface+0x48+side*12+i*4) for i in range(3)] for side in range(2)],warnings=warnings)
block=lambda name,value:f'node dummy {name}\n position {value}\n orientation 0 0 1 1.57\nendnode\n'
cases=['','node dummy root\nposition 9 8 7\nendnode\n']
cases += [block(f'{prefix}{stem}{side}',value) for prefix,stem,side,value in itertools.product(['plc_','pl_','plc__'],['pwk_use','pwk_dp_use_'],['01','02','03','01suffix'],['1 2 3','-1.25 0.125 3.1415926535'])]
cases += [block('plc_pwk_use01','1 2 3')+block('plc_pwk_use01','4 5 6'),block('plc_pwk_use01','1 2 3')+block('plc_pwk_use03','9 9 9'),block('plc_pwk_use02','4 5 6')+block('unrelated','9 9 9'),block('plc_pwk_dp_use_02','7 8 9').replace('\n','\r\n'),block('plc_pwk_use01','1 2 3').replace('node dummy','node  dummy')]
rows=[run(text) for text in cases];out=m.root/'backups/animations/native-placeable-point-loader-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
