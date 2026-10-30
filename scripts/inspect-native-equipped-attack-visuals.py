"""Read-only original7fd6b0 attack-visual transitions with equipped items.

Execute unchanged owner instructions; capture canonical lookup, base-row,
bounded CResRef, resource existence, Gob model-slot and colour boundaries.
No game process, renderer, server outcome or actual asset is modified/executed.
"""
from pathlib import Path
import sys,json,struct,hashlib,itertools
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
assert len(sys.argv)==2
output=Path(sys.argv[1]).resolve()
assert output.is_relative_to(root/'godot-client/reports') and not output.exists()
original=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(original).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=original);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
actor,item,info,app,rules,vt,colour=[heap+n*0x1000 for n in range(7)]
def wq(a,n):u.mem_write(a,struct.pack('<Q',n))
def wi(a,n):u.mem_write(a,struct.pack('<I',n&0xffffffff))
def rq(a):return int.from_bytes(u.mem_read(a,8),'little')
def reg(r):return u.reg_read(r)
def text(a):
 b=bytearray()
 while len(b)<64 and u.mem_read(a+len(b),1)[0]:b.append(u.mem_read(a+len(b),1)[0])
 assert len(b)<64
 return b.decode('ascii')
def ret(value=0):
 sp=reg(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RAX,value);u.reg_write(UC_X86_REG_RIP,rq(sp));u.reg_write(UC_X86_REG_RSP,sp+8)
def hook(_u,address,_size,_data):
 x,y,z,w=[reg(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==stop:u.emu_stop();return
 if address==0x1406abc80:assert y==55;ret(item if case['equipped'] else 0);return
 if address==0x14029ca00:assert y==99;ret(info);return
 if address==0x14018ded0:
  b=text(y).encode('ascii')[:16];u.mem_write(x,b+bytes(17-len(b)));ret(x);return
 if address==0x140c42060:assert 0<=z<=17;u.mem_write(x,bytes([y&255])*z);ret(x);return
 if address==0x14018f590:
  assert z==2002;calls.append(dict(operation='exists',resource=text(y)));ret(case['exists']);return
 if address==stop+16:
  assert x==item+0x48 and z&255==251 and w==0,(hex(x),hex(z),hex(w))
  calls.append(dict(operation='load',resource=text(y),slot=z&255,flags=w));ret(case['load']);return
 if address==stop+32:
  assert x==item+0x48 and y&255==251 and z==0 and w==0
  calls.append(dict(operation='configure',slot=y&255,arg2=z,arg3=w));ret();return
 if address==stop+48:
  assert x==item+0x48 and y==251;calls.append(dict(operation='remove',slot=y&255));ret();return
 if address==0x1407630a0:assert x==item+0x48;ret(colour);return
 if address==0x140965cf0:
  assert x==colour and z==4 and w==1
  calls.append(dict(operation='colour',rgb=list(struct.unpack('<fff',bytes(u.mem_read(y,12)))),scope=z,flags=w));ret();return
 if address==0x140968590:
  assert x==colour and y==4;calls.append(dict(operation='clear-colour',scope=y));ret();return
 if address==0x1407fdca0:assert x==actor and y==0;ret(0);return
 if address==0x140803c50:calls.append(dict(operation='special-load',kind=y&255));ret();return
 if address==0x1408074b0:calls.append(dict(operation='special-play',kind=y&255));ret();return
 if address==0x140c10410:ret();return
 if not 0x1407fd6b0<=address<=0x1407fdb0d:raise RuntimeError(f'Unexpected original dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def execute(c):
 global case,calls
 case=c;calls=[];u.mem_write(heap,bytes(0x20000));u.mem_write(stack,bytes(0x10000))
 wq(0x1412df8f8,app);wq(app,app);wq(0x1412df970,rules);wq(rules+0x20,rules)
 wi(actor+0x318,55);wi(actor+0x378,c['initial']);u.mem_write(actor+0x224,struct.pack('<H',c['attackType']&65535))
 wi(item+0x40,99);u.mem_write(item+0x2a8,bytes([c['itemFlag2a8']&255]));u.mem_write(info+0x16,bytes([c['modelType']&255]));u.mem_write(info+0x40,c['itemClass'].encode()+b'\0')
 wq(item+0x48,vt);wq(vt+0xf0,stop+16);wq(vt+0x168,stop+32);wq(vt+0xf8,stop+48)
 sp=stack+0xff08;wq(sp,stop)
 for r,v in [(UC_X86_REG_RCX,actor),(UC_X86_REG_RDX,c['enabled']&0xffffffff),(UC_X86_REG_RSP,sp)]:u.reg_write(r,v)
 u.emu_start(0x1407fd6b0,stop+1,count=20000);assert reg(UC_X86_REG_RIP)==stop
 return dict(input=c,calls=calls,enabled=int.from_bytes(u.mem_read(actor+0x378,4),'little',signed=True),attackType=int.from_bytes(u.mem_read(actor+0x224,2),'little'))
rows=[]
for initial,enabled,attack,model,flag,availability in itertools.product([0,1],[0,1],[0,6,9,16,17,23,31,39,296,301,65000,65001,65535],[0,2,3],[0,1],[(1,1),(0,1),(1,0)]):
 rows.append(execute(dict(initial=initial,enabled=enabled,attackType=attack,modelType=model,itemFlag2a8=flag,exists=availability[0],load=availability[1],itemClass='wswss',equipped=True)))
for prefix in ['', 'a','wplhc_t_001','abcdefghijklm']:
 rows.append(execute(dict(initial=0,enabled=1,attackType=6,modelType=2,itemFlag2a8=0,exists=1,load=1,itemClass=prefix,equipped=True)))
for initial,enabled,attack in itertools.product([0,1],[0,1],[0,39,296]):
 rows.append(execute(dict(initial=initial,enabled=enabled,attackType=attack,modelType=2,itemFlag2a8=0,exists=1,load=1,itemClass='wswss',equipped=False)))
result=dict(success=True,target=digest,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope=__doc__,functions=[dict(address='0x1407fd6b0',end='0x1407fdb0d',sha256=hashlib.sha256(bytes(u.mem_read(0x1407fd6b0,1118))).hexdigest())],cases=rows,limitations=['Original owner instructions execute with captured model/resource/colour boundaries, not actual rendering or full combat callers.','Only bounded ASCII DefaultModel inputs through13 bytes; malformed longer native buffer behavior is not acceptance.','item+2a8 is an opaque client flag, not assigned an invented semantic name. Constructor83c480 initializes it to0.','Unarmed fixtures keep preexisting special-model slots absent and gate0; complete unarmed loader/gate/play have their separate corpus.'])
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(success=True,cases=len(rows),report=str(output))))
