"""Execute unchanged original AnimateEvents14004fce0..14004fe88 using event
metadata independently extracted from active original animation resources.
The Gob virtual event callback is captured; it does not run the complete client
combat Hit listener, upper clock, action mutation or rendered native client.
No original executable/model bytes are written or patched.
"""
from pathlib import Path
import sys,json,struct,hashlib
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
assert len(sys.argv)==3
source=Path(sys.argv[1]).resolve();output=Path(sys.argv[2]).resolve()
assert source.is_relative_to(root/'godot-client/reports') and output.is_relative_to(root/'godot-client/reports') and not output.exists()
original=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(original).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=original);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
def wq(a,n):u.mem_write(a,struct.pack('<Q',n))
def wi(a,n):u.mem_write(a,struct.pack('<I',n&0xffffffff))
def text(a):
 b=bytearray()
 while u.mem_read(a+len(b),1)[0]:b.append(u.mem_read(a+len(b),1)[0])
 return b.decode('ascii')
def hook(u,a,_size,_data):
 if a==stop:u.emu_stop();return
 if a==stop+16:
  calls.append(text(u.reg_read(UC_X86_REG_RDX)));sp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,int.from_bytes(u.mem_read(sp,8),'little'));u.reg_write(UC_X86_REG_RSP,sp+8);return
 if not 0x14004fce0<=a<0x14004fe88:raise RuntimeError(f'Unexpected native event dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
metadata=json.loads(source.read_text());rows=[]
for model in metadata['models']:
 for clip in model['clips']:
  for start,end,flags in [(.4,.5,0),(.5,.6,0),(.6,.4,1),(0,0,2)]:
   calls=[];u.mem_write(heap,bytes(0x100000));u.mem_write(stack,bytes(0x20000));owner,animation,events,vt=heap,heap+0x1000,heap+0x2000,heap+0x3000
   wq(owner,vt);wq(vt+0x298,stop+16);wq(animation+0xd8,events);wi(animation+0xe0,len(clip['events']))
   for i,event in enumerate(clip['events']):u.mem_write(events+i*36,struct.pack('<f',event['time'])+event['name'].encode('ascii')+b'\0')
   sp=stack+0x1fe08;wq(sp,stop);wi(sp+0x28,flags);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,owner);u.reg_write(UC_X86_REG_RDX,animation)
   u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',start),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',end),'little'))
   u.emu_start(0x14004fce0,stop+1,count=100000);assert u.reg_read(UC_X86_REG_RIP)==stop
   rows.append(dict(model=model['name'],clip=clip['name'],events=clip['events'],start=start,end=end,flags=flags,calls=calls))
assert len(rows)==24
output.write_text(json.dumps(dict(success=True,target=digest,inputSha256=hashlib.sha256(source.read_bytes()).hexdigest(),scope=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(success=True,rows=len(rows),report=str(output))))
