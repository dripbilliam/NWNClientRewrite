"""Complete original server UpdateWind4ce930 sender with native float writers,
message allocation and GetWriteMessage. Transport is captured, with its header
prefix supplied at that boundary. No process writes or game connections.
"""
import importlib,json,struct
mwriter=importlib.import_module('inspect-native-message-writer');w=mwriter;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(w.hook_handle);sent=[]
def hook(u,a,n,data):
 if a==0x1404dc490:
  rsp=u.reg_read(UC_X86_REG_RSP);pointer=m.q(rsp+0x28);length=m.si(rsp+0x30)&0xffffffff
  sent.append(bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255])+bytes(u.mem_read(pointer,length))[3:]);m.finish(1);return
 if 0x1404ce930<=a<=0x1404cea52:return
 w.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format_ in [0,1]:
 for values in [[0,0,0,0,0,0],[.2,-.4,.6,3.4567,17.123456,2.345678],[-1,2,-3,-2,360,-90]]:
  w.run(dict(format=format_,ops=[]));sent.clear();vector=m.heap+0x9000;player=m.heap+0xa000
  for index,value in enumerate(values[:3]):m.wf(vector+index*4,value)
  m.wi(player+0x48,1);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[w.message,player,vector]):u.reg_write(reg,value)
  u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',values[3]),'little'));m.wf(rsp+0x28,values[4]);m.wf(rsp+0x30,values[5])
  u.emu_start(0x1404ce930,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(sent)==1
  rows.append(dict(format=format_,values=[struct.unpack('<f',struct.pack('<f',v))[0]for v in values],packet=sent[0].hex()))
output=m.root/'backups/animations/native-wind-message-observations-v1.json';assert not output.exists();output.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(output),rows=len(rows))))
