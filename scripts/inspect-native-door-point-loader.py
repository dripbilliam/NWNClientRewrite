"""Unchanged door-surface ctor1402cecf0 and DWK loader1402cf720, synthetic
ASCII dummy nodes. Resource demand/release, libc strncmp/sscanf and heap are
captured. Native line scan, grammar/state/index and vector storage execute.
No proprietary DWK bytes are copied into the report.
"""
import importlib.util,json,re,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);surface,resource,input,ref=[m.heap+n*0x10000 for n in range(1,5)]
def string(a):
 result=bytearray()
 for i in range(2048):
  b=bytes(u.mem_read(a+i,1))
  if b==b'\0':return bytes(result)
  result.extend(b)
 raise AssertionError('Unbounded fixture string')
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14018ded0:m.finish(x)
 elif a==0x14018df10:m.finish(1)
 elif a==0x14018f300:m.finish(input)
 elif a==0x1402cb620:m.finish(input)
 elif a==0x1402cb630:m.finish(len(c))
 elif a==0x140c10368:ptr=m.heap+0x80000+allocation*0x1000;allocation+=1;m.finish(ptr)
 elif a in [0x140c10370,0x1401912c0,0x14018f3a0]:m.finish()
 elif a==0x140c4ee30:
  left=bytes(u.mem_read(x,z));right=bytes(u.mem_read(y,z));result=next((a-b for a,b in zip(left,right) if a!=b),0);m.finish(result)
 elif a==0x140047060:
  fmt=string(y).decode('ascii');assert fmt=='%f %f %f';values=string(x).decode('ascii').split();pointers=[z,w,m.q(rsp+0x28)];count=0
  for ptr,value in zip(pointers,values):
   try:number=float(value)
   except ValueError:break
   m.wf(ptr,number);count+=1
  m.finish(count)
 elif not any(lo<=a<hi for lo,hi in [(0x1402cecf0,0x1402cedb8),(0x140047300,0x14004730c),(0x1402cf720,0x1402d0100)]):raise AssertionError(f'Uncaptured loader dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface);u.reg_write(UC_X86_REG_RDX,ref)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(text):
 global c,allocation
 c=text.encode('ascii');allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(surface,bytes([0xa5])*0x100);invoke(0x1402cecf0);m.wq(surface+8,resource);u.mem_write(input,c+b'\0')
 try:invoke(0x1402cf720)
 except Exception:print(json.dumps(dict(text=text,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(text=text,points=[[[m.rf(surface+0x90+(state*2+side)*12+i*4) for i in range(3)] for side in range(2)] for state in range(3)])
if __name__=='__main__':
 block=lambda name,value:f'node dummy {name}\n position {value}\n orientation 0 0 1 1.57\nendnode\n'
 cases=['','node dummy root\nposition 9 8 7\nendnode\n']
 cases += [block(f'{prefix}_DWK_dp_{state}_{side}',value) for prefix in ['D0','D','ABC'] for state in ['closed','open1','open2'] for side in ['01','02'] for value in ['1 2 3','-1.25 0.125 3.1415926535']]
 cases += [block('D0_DWK_dp_closed_01','1 2 3')+block('D0_DWK_dp_closed_01','4 5 6'), 'node dummy D0_DWK_dp_closed_02\nendnode\n', block('D0_DWK_dp_open1_02extra','7 8 9'),block('D0_DWK_dp_closed_01','1 2 3').replace('node dummy','node  dummy'),block('D0_DWK_dp_closed_01','1 2 3').replace('\n','\r\n')]
 rows=[run(text) for text in cases];out=m.root/'backups/animations/native-door-point-loader-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
