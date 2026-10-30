"""Execute original1a3790 WORD/BYTE compatibility policy in isolation.
GFF field lookup/allocation/write, snprintf and cookie APIs are captured helper
boundaries. No original process, gameplay connection or user file is changed.
"""
import importlib,json,struct,itertools
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner=m.heap;root=m.heap+0x1000;field=m.heap+0x2000;label_at=m.heap+0x3000
calls=[];case={}
def cstr(at):
 b=bytearray()
 while len(b)<128:
  c=u.mem_read(at+len(b),1)[0]
  if c==0:return bytes(b)
  b.append(c)
 raise RuntimeError('Unbounded native field label')
def finish(value=0):
 rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,m.q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,value)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1401a2a80:calls.append(['byte',cstr(w).decode(),z&255]);finish(1);return
 if a==0x140085bd0:
  assert cstr(z)==b'%s%s';value=(cstr(w)+cstr(m.q(rsp+0x28)))[:y-1];u.mem_write(x,value+b'\0');finish(len(value));return
 if a==0x1401a05c0:calls.append(['initialize']);m.wi(owner+0x104,0);finish();return
 if a==0x14019fcc0:calls.append(['find',cstr(z).decode()]);finish(0);return
 if a==0x14019fc20:finish(field if case['mode']=='existing' else 0);return
 if a==0x14019edb0:calls.append(['add',cstr(z).decode(),w]);finish(0 if case['mode']=='add-failed' else field);return
 if a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX));return
 if not 0x1401a3790<=a<0x1401a38a0:raise RuntimeError('Unexpected original dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for label,value,mode,initial in itertools.product(['Appearance_Head','BodyPart_LShoul','ArmorPart_RFoot','abcdefghijklmnop'],[0,1,255,256,65535],['existing','new','add-failed'],[0,1]):
 case={'label':label,'value':value,'mode':mode,'initialize':initial};calls=[]
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(label_at,label.encode()+b'\0');m.wi(owner+0x104,initial)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in [(UC_X86_REG_RCX,owner),(UC_X86_REG_RDX,root),(UC_X86_REG_R8,value),(UC_X86_REG_R9,label_at)]:u.reg_write(reg,v)
 u.emu_start(0x1401a3790,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 extended=('x'+label)[:16];expected=[['byte',label,value if value<256 else 0]]
 if initial:expected.append(['initialize'])
 expected.append(['find',extended])
 if mode!='existing':expected.append(['add',extended,2])
 success=mode!='add-failed';stored=struct.unpack('<I',u.mem_read(field+8,4))[0]
 assert calls==expected,(case,calls,expected)
 assert u.reg_read(UC_X86_REG_RAX)==int(success) and stored==(value if success else 0),(case,u.reg_read(UC_X86_REG_RAX),stored)
 rows.append(dict(**case,byte=value if value<256 else 0,extended=extended,word=stored,success=success,calls=calls))
out=m.root/'backups/animations/native-customization-wordbyte-v1.json'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),binarySha256=m.digest)))
