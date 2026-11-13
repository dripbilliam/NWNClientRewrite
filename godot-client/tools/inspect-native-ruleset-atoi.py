"""Read-only execution of the original ruleset atoi and complete decimal parser.

Only the default C-locale descriptor and errno storage are supplied service
boundaries. No current client, server, private profile, key or network is used.
The pinned original instruction bodies execute unchanged, including saturation.
"""
from pathlib import Path
import sys,struct,hashlib,json
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
source=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(source).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=source);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
def q(at):return int.from_bytes(u.mem_read(at,8),'little')
def wq(at,value):u.mem_write(at,struct.pack('<Q',value))
def finish(value=0):
 sp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(sp));u.reg_write(UC_X86_REG_RSP,sp+8);u.reg_write(UC_X86_REG_RAX,value&0xffffffffffffffff)
def hook(u,at,n,_):
 if at==stop:u.emu_stop();return
 if at==0x140c56200:
  destination=u.reg_read(UC_X86_REG_RCX);assert u.reg_read(UC_X86_REG_RDX)==0
  wq(destination,heap+0x6000);wq(destination+8,heap+0x4000);wq(destination+16,0);u.mem_write(destination+24,b'\0');finish();return
 if at==0x140c847a0:finish(heap+0x7000);return
 assert 0x140c81d54<=at<=0x140c81d7c or 0x140c8047c<=at<=0x140c807b5,f'Uncaptured original dependency {at:x}'
u.hook_add(UC_HOOK_CODE,hook)
def run(text):
 raw=text.encode('cp1252');assert len(raw)<0x3000
 u.mem_write(heap,bytes(0x10000));u.mem_write(heap,raw+b'\0')
 wq(heap+0x4000,heap+0x5000);u.mem_write(heap+0x4008,struct.pack('<I',1))
 for byte in [9,10,11,12,13,32]:u.mem_write(heap+0x5000+byte*2,struct.pack('<H',8))
 sp=stack+0x1fe08;u.mem_write(sp-0x500,bytes(0x600));wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,heap)
 u.emu_start(0x140c81d54,stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==stop
 value=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return {'text':text.split('\0',1)[0],'inputHex':raw.hex(),'value':value-0x100000000 if value>=0x80000000 else value,'errno':int.from_bytes(u.mem_read(heap+0x7000,4),'little')}
inputs=['','****','0','1','-1','+1','  -7tail','0x12','-0x12','1.9','1e9','words','+ 3','--3','\0'+'9','\xa0'+'5']
inputs += [prefix+str(value)+suffix for prefix in ['','+','-',' \t\r\n\v\f'] for value in [2147483646,2147483647,2147483648,2147483649,4294967295,4294967296,9999999999999999999999999999999] for suffix in ['','tail']]
rows=[run(text)for text in inputs]
output=root/'godot-client/reports/native-ruleset-atoi-observations-v2.json'
assert not output.exists(),'Preserve prior original-instruction evidence'
output.write_text(json.dumps({'binarySha256':digest,'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scope':__doc__,'rows':rows},indent=2)+'\n')
print(json.dumps({'output':str(output),'rows':len(rows),'binarySha256':digest}))
