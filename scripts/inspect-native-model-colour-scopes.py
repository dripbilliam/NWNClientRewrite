"""Read-only original965cf0/968590/966170 colour-scope instruction cases.

The original composer calls controlled Gob virtual colour boundaries. No shader,
real model, game process or GPU runs. Method offsets are retained as raw evidence.
"""
from pathlib import Path
import sys,json,struct,hashlib,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
assert len(sys.argv)==2
output=Path(sys.argv[1]).resolve();assert output.is_relative_to(root/'godot-client/reports') and not output.exists()
original=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(original).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=original);base=pe.OPTIONAL_HEADER.ImageBase;u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
owner,gob,vt,vector,app=[heap+n*0x1000 for n in range(5)]
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def reg(r):return u.reg_read(r)
def ret(v=0):
 sp=reg(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RAX,v);u.reg_write(UC_X86_REG_RIP,int.from_bytes(u.mem_read(sp,8),'little'));u.reg_write(UC_X86_REG_RSP,sp+8)
entries=[(0x140965cf0,0x140965d5b),(0x140968590,0x1409685c6),(0x140966170,0x140966406)]
def hook(_u,a,_size,_data):
 if a==stop:u.emu_stop();return
 if a in [stop+16,stop+32]:
  assert reg(UC_X86_REG_RCX)==gob
  rgb=list(struct.unpack('<fff',bytes(u.mem_read(reg(UC_X86_REG_RDX),12))))
  if a==stop+16:
   assert reg(UC_X86_REG_R8)==1;calls.append(dict(method='0x180',rgb=rgb,flags=1))
  else:
   assert reg(UC_X86_REG_R9)==1;calls.append(dict(method='0x178',rgb=rgb,alpha=struct.unpack('<f',struct.pack('<I',reg(UC_X86_REG_XMM2)&0xffffffff))[0],flags=1))
  ret(1);return
 if a==0x1406abea0:ret(0);return
 if not any(lo<=a<=hi for lo,hi in entries):raise RuntimeError(f'Unexpected colour boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for operation,scope,mask,present in itertools.product(['set','clear'],[0,1,2,3,4,5,255,256],range(32),[False,True]):
 calls=[];u.mem_write(heap,bytes(0x10000));u.mem_write(stack,bytes(0x10000))
 wq(owner+0xc8,gob if present else 0);wq(gob,vt);wq(vt+0x180,stop+16);wq(vt+0x178,stop+32)
 wq(0x1412df970,app);wq(app,app);wi(0x141296cb0,1);wi(0x141296cb4,0)
 colours=[[i/8.0,(i+1)/8.0,(i+2)/8.0]for i in range(5)]
 for i,rgb in enumerate(colours):u.mem_write(owner+0x60+i*12,struct.pack('<fff',*rgb));wi(owner+0x9c+i*4,int(bool(mask&(1<<i))))
 u.mem_write(owner+0xd8,struct.pack('<f',0.625));u.mem_write(vector,struct.pack('<fff',0.25,0.5,0.75))
 sp=stack+0xff08;wq(sp,stop)
 for r,v in [(UC_X86_REG_RCX,owner),(UC_X86_REG_RDX,vector if operation=='set' else scope),(UC_X86_REG_R8,scope),(UC_X86_REG_R9,1),(UC_X86_REG_RSP,sp)]:u.reg_write(r,v)
 u.emu_start(0x140965cf0 if operation=='set' else 0x140968590,stop+1,count=20000);assert reg(UC_X86_REG_RIP)==stop
 active=[bool(int.from_bytes(u.mem_read(owner+0x9c+i*4,4),'little'))for i in range(5)]
 actual_colours=[list(struct.unpack('<fff',bytes(u.mem_read(owner+0x60+i*12,12))))for i in range(5)]
 rows.append(dict(input=dict(operation=operation,scope=scope,mask=mask,present=present,colours=colours,colour=[0.25,0.5,0.75],alpha=0.625),result=reg(UC_X86_REG_RAX)&0xffffffff,active=active,colours=actual_colours,calls=calls))
output.write_text(json.dumps(dict(success=True,target=digest,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),functions=[dict(address=hex(a),end=hex(b),sha256=hashlib.sha256(bytes(u.mem_read(a,b-a+1))).hexdigest())for a,b in entries],cases=rows,scope=__doc__,limitations=['Model virtual methods0x180/0x178 captured, not the complete original material shader.','Optional renderer registration is disabled through original global flag141296cb4; application lookup returnsNULL.','The composer selects the lowest active scope; this is priority selection, not RGB accumulation.']),indent=2)+'\n');print(json.dumps(dict(success=True,cases=len(rows),report=str(output))))
