"""Original ReadFieldCExoString1a1130 and explicit-length assignment03d8c0.
Field-index/field lookup, allocator/free/memcpy are captured lower boundaries.
Actual field type, payload bounds, status/default and string storage execute.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
gffPtr,outPtr,rootPtr,keyPtr,fieldPtr,headerPtr,dataPtr,statusPtr,defaultPtr=[m.heap+n*0x1000 for n in range(1,10)]

def hook(u,at,n,_):
 global cursor
 if at==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if at==0x14019fcc0:m.finish(0);return
 if at==0x14019fc20:m.finish(fieldPtr if c['found'] else 0);return
 if at==0x140c10368:ptr=m.heap+cursor;cursor+=(x+31)&~15;m.finish(ptr);return
 if at==0x140c10370:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if not (0x1401a1130<=at<0x1401a1242 or 0x14003d8c0<=at<0x14003d9ab or 0x14019e620<=at<0x14019e653):raise AssertionError(f'Uncaptured GFF string dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,cursor
 c=case;cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));raw=c['value'].encode('cp1252');fallback=c['default'].encode('cp1252');m.wq(gffPtr+0x78,headerPtr);m.wq(gffPtr+0xb8,dataPtr if c.get('data',True) else 0);m.wi(headerPtr+0x24,c.get('size',len(raw)+4));m.wi(fieldPtr,c['type']);m.wi(fieldPtr+8,0);m.wi(dataPtr,len(raw));u.mem_write(dataPtr+4,raw+b'\0');u.mem_write(keyPtr,b'Value\0');m.wq(defaultPtr,m.heap+0xf000);u.mem_write(m.heap+0xf000,fallback+b'\0');m.wi(defaultPtr+8,len(fallback));m.wi(defaultPtr+12,len(fallback)+1)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);m.wq(rsp+0x28,statusPtr);m.wq(rsp+0x30,defaultPtr);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[gffPtr,outPtr,rootPtr,keyPtr]):u.reg_write(reg,value)
 u.emu_start(0x1401a1130,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 value=bytes(u.mem_read(m.q(outPtr),m.si(outPtr+8)&0xffffffff)).decode('cp1252') if m.q(outPtr) else ''
 return dict(case=c,status=m.si(statusPtr),value=value,length=m.si(outPtr+8))

rows=[]
for value,fallback,fieldType,found in itertools.product(['','text','\0tail','a\0tail','é€'],['','fallback','\0default'],[0,4,10,11,12],[False,True]):rows.append(run(dict(value=value,default=fallback,type=fieldType,found=found)))
for size,data in itertools.product([0,1,3,4,6,7],[False,True]):rows.append(run(dict(value='abc',default='fallback',type=10,found=True,size=size,data=data)))
out=m.root/'backups/animations/native-gff-string-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
