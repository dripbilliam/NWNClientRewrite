"""Execute original CompareNoCase BOOL, Appearance inversion and native
enable/disable branch. The ASCII CRT stricmp call alone is captured. No GUI,
asset writes, renderer, network or original process is used.
"""
from pathlib import Path
import hashlib,json,struct,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
binary=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
sha=hashlib.sha256(binary).hexdigest();assert sha=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=binary);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
data,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(data,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
phase='';outcome=None
def string(at):
 value=bytearray()
 while True:
  b=u.mem_read(at+len(value),1)[0]
  if not b:return bytes(value)
  value.append(b)
def hook(_u,address,_size,_data):
 global outcome
 if address==stop:u.emu_stop();return
 if phase=='compare' and address==0x140c9a9fc:
  a=string(u.reg_read(UC_X86_REG_RCX)).lower();b=string(u.reg_read(UC_X86_REG_RDX)).lower()
  value=0 if a==b else -1 if a<b else 1
  rsp=u.reg_read(UC_X86_REG_RSP);ret=struct.unpack('<Q',u.mem_read(rsp,8))[0];u.reg_write(UC_X86_REG_RAX,value&0xffffffffffffffff);u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RIP,ret);return
 if phase=='invert' and address==0x1408eb5cb:u.emu_stop();return
 if phase=='gate' and address in [0x1408ec119,0x1408ec476]:outcome=address==0x1408ec476;u.emu_stop();return
 assert phase=='compare' and 0x14016ae00<=address<=0x14016ae46 or phase=='invert' and 0x1408eb5bd<=address<0x1408eb5cb or phase=='gate' and 0x1408ec103<=address<0x1408ec119,hex(address)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for model in ['P','p','S','s','PP','','****','p ']:
 for valid in [False,True]:
  u.mem_write(data,bytes(0x4000));raw=model.encode('ascii');u.mem_write(data+0x100,raw+b'\0');u.mem_write(data+0x200,b'P\0');u.mem_write(data+0x10,struct.pack('<QII',data+0x100,len(raw),len(raw)+1));u.mem_write(data+0x30,struct.pack('<QII',data+0x200,1,2))
  rsp=stack+0xf008;u.mem_write(rsp,struct.pack('<Q',stop));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,data+0x10);u.reg_write(UC_X86_REG_RDX,data+0x30)
  phase='compare';u.emu_start(0x14016ae00,stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==stop
  compared=u.reg_read(UC_X86_REG_RAX)&0xffffffff;u.reg_write(UC_X86_REG_R14,0);u.reg_write(UC_X86_REG_RDI,data)
  phase='invert';u.emu_start(0x1408eb5bd,stop,count=100);flag=struct.unpack('<I',u.mem_read(data+0x177c,4))[0]
  u.mem_write(data+0x1778,struct.pack('<I',int(valid)));u.reg_write(UC_X86_REG_R13,0);phase='gate';outcome=None;u.emu_start(0x1408ec103,stop,count=100);assert outcome is not None
  rows.append({'input':{'modelType':model,'appearanceValid':valid},'compareBool':compared,'nonPFlag':flag,'enabled':outcome})
output=root/'godot-client/reports/native-creation-appearance-model-gate-original-v1.json'
if output.exists():raise RuntimeError('Prior original evidence preserved')
result={'success':True,'binarySha256':sha,'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':len(rows),'scope':__doc__,'rows':rows}
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'success':True,'cases':len(rows),'network':False,'gpu':False,'report':str(output)}))
