"""Unchanged CResTGA::OnResourceServiced on synthetic unmapped TGA pixels.
No CRT/resource/codec calls are replaced in these type2/3 paths. This checks
raw RGB/gray row order and header behavior, not GL texture upload or pixels.
"""
import importlib,json,itertools,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not 0x1401a4730<=a<=0x1401a4966:raise RuntimeError('Unexpected native TGA dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for width,height,depth,origin,alpha,idlength in itertools.product([2,3],[2,3],[8,24,32],[0,16,32,48],[0,4,8],[0,3]):
 pixel=depth//8;kind=3 if depth==8 else 2;header=bytearray(18);header[0]=idlength;header[2]=kind;struct.pack_into('<HH',header,12,width,height);header[16]=depth;header[17]=origin|alpha
 raw=bytes(((i*37+11)&255)for i in range(width*height*pixel));tga=bytes(header)+bytes(idlength)+raw
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));resource,data=m.heap,m.heap+0x1000;u.mem_write(data,tga);m.wq(resource+0x20,data);m.wi(resource+0x30,len(tga));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,resource);u.emu_start(0x1401a4730,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 pointer=m.q(resource+0x80);output=bytes(u.mem_read(pointer,len(raw)));expected=bytearray(raw)
 if pixel>=3:
  for i in range(0,len(raw),pixel):expected[i],expected[i+2]=expected[i+2],expected[i]
 assert output==bytes(expected);rows.append(dict(width=width,height=height,depth=depth,descriptor=origin|alpha,idLength=idlength,returnValue=u.reg_read(UC_X86_REG_RAX)&0xffffffff,loaded=m.si(resource+0x6c),input=list(tga),rawRgb=list(output)))
out=m.root/'backups/animations/native-tga-origin-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),allIgnoreOrigin=True)))
