"""Read-only build89 SetGold/AddGold/RemoveGold oracle. Full native bodies execute;
message allocation, integer payload setter and feedback delivery are captured
substitutions. No live game or packet execution.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x4000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,int.from_bytes(u.mem_read(rsp,8),'little'));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
calls=[];payload=0
def hook(u,a,n,_):
    global payload
    if a==stop:u.emu_stop();return
    if a==0x140c10324:finish(heap+0x2000)
    elif a==0x1402da730:payload=signed(u.reg_read(UC_X86_REG_R8));finish()
    elif a==0x1403a2480:
        calls.append({'code':u.reg_read(UC_X86_REG_RDX)&65535,'integers':[payload]});finish()
    elif not(0x14037eda0<=a<0x14037eed0 or 0x1403a3180<=a<0x1403a3191 or 0x14039e9b0<=a<0x14039eabf):raise RuntimeError(f'Unmapped gold owner {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
values=[-2147483648,-100,-1,0,1,100,999999998,999999999,1000000000,2147483647]
observations=[]
for method,old,amount,feedback in itertools.product(['set','add','remove'],values,values,[0,1,2]):
    calls=[];u.mem_write(heap,bytes(0x4000));wi(heap+0x898,old);rsp=stack+0xff08;u.mem_write(rsp,struct.pack('<Q',stop))
    for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_RSP],[heap,amount&0xffffffff,feedback,rsp]):u.reg_write(r,v)
    u.emu_start({'set':0x1403a3180,'add':0x14037eda0,'remove':0x14039e9b0}[method],stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'method':method,'old':old,'amount':amount,'feedback':feedback,'balance':int.from_bytes(u.mem_read(heap+0x898,4),'little',signed=True),'calls':calls})
output=root/'backups/animations/native-gold-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
