"""Unchanged original CGuiCGColSelect8e3170 release coordinate conversion,
range checks and callback. Mouse/GUI object operations are captured boundaries;
all floating operations, signed division and removal-before-callback execute.
"""
from pathlib import Path
import hashlib,json,struct,sys
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
binary=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();sha=hashlib.sha256(binary).hexdigest();assert sha=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=binary);base=pe.OPTIONAL_HEADER.ImageBase;u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
panel,gui,render,vtable,origin,stack,stop=0x200000000,0x200002000,0x200004000,0x200005000,0x200006000,0x300000000,0x400000000
u.mem_map(panel,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
def finish(value=0):
 rsp=u.reg_read(UC_X86_REG_RSP);ret=struct.unpack('<Q',u.mem_read(rsp,8))[0];u.reg_write(UC_X86_REG_RAX,value&0xffffffffffffffff);u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RIP,ret)
def hook(_u,address,_size,_data):
 if address==stop:u.emu_stop();return
 if address==0x1401f4cc0:
  u.mem_write(u.reg_read(UC_X86_REG_RDX),struct.pack('<i',0));u.mem_write(u.reg_read(UC_X86_REG_R8),struct.pack('<i',0));finish();return
 if address in [0x1401f4e30,0x1401f6440]:finish();return
 if address==stop+0x100:finish(origin);return
 if address==0x1401fb630:calls.append({'kind':'removed'});finish();return
 if address==stop+0x200:calls.append({'kind':'callback','index':u.reg_read(UC_X86_REG_RDX)&0xffffffff});finish();return
 assert 0x1408e3170<=address<=0x1408e327c,hex(address)
u.hook_add(UC_HOOK_CODE,hook)
u.mem_write(0x1412df8b0,struct.pack('<Q',gui));u.mem_write(panel+0x10,struct.pack('<Q',render));u.mem_write(render,struct.pack('<Q',vtable));u.mem_write(vtable+0xc0,struct.pack('<Q',stop+0x100));u.mem_write(origin,struct.pack('<fff',0,0,0));u.mem_write(panel+0x80,struct.pack('<Q',panel));u.mem_write(panel+0x88,struct.pack('<Q',stop+0x200));u.mem_write(panel+0x90,struct.pack('<i',11))
def f(value):return struct.unpack('<f',struct.pack('<f',value))[0]
rows=[]
for px in [-33,-16,-15.5,-.5,0,.5,15.49,15.5,15.51,16,127.5,255.49,255.5,256,272]:
 for py in [-17,-.5,0,.5,8,15.49,15.5,16,16.5,175.49,175.5,176,192]:
  world=[f(px*.01),f((176-py)*.01)];u.mem_write(gui+0x108,struct.pack('<ff',*world));calls=[]
  rsp=stack+0xf008;u.mem_write(rsp,struct.pack('<Q',stop));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel);u.emu_start(0x1408e3170,stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==stop
  assert calls and calls[0]['kind']=='removed';indices=[x['index']for x in calls if x['kind']=='callback'];assert len(indices)<=1
  rows.append({'pixel':[px,py],'worldDelta':world,'index':indices[0]if indices else None,'calls':calls})
output=root/'godot-client/reports/native-creation-palette-release-original-v1.json'
if output.exists():raise RuntimeError('Prior evidence preserved')
output.write_text(json.dumps({'success':True,'binarySha256':sha,'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':len(rows),'scope':__doc__,'rows':rows},indent=2)+'\n');print(json.dumps({'success':True,'cases':len(rows),'network':False,'gpu':False,'report':str(output)}))
