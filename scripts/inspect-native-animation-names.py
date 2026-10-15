"""Read-only native animation name lookup, build89.8193.37-17.

Executes140961540..140963e86 with synthetic presentation context bytes,
substituted string allocation/copy/free and an empty override list. Walk helper
140965af0 executes with special-walk byte0. No game models/assets are copied.
"""
from pathlib import Path
import sys,hashlib,struct,json,itertools
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
uc=Uc(UC_ARCH_X86,UC_MODE_64);uc.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095)
uc.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
uc.mem_map(heap,0x10000);uc.mem_map(stack,0x10000);uc.mem_map(stop,0x1000)
actor,out=heap,heap+0x1000;cursor=heap+0x2000;substitutions=set()
def q(a):return struct.unpack('<Q',uc.mem_read(a,8))[0]
def wi(a,v):uc.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):uc.mem_write(a,struct.pack('<Q',v))
def alloc(n):
    global cursor
    p=cursor;cursor+=(max(n,1)+15)&~15;assert cursor<heap+0x10000
    uc.mem_write(p,bytes(max(n,1)));return p
def cstring(a):
    result=bytearray()
    if a:
        while (b:=uc.mem_read(a+len(result),1)[0])!=0:
            result.append(b);assert len(result)<256
    return bytes(result)
def copy(dst,src,length):
    b=cstring(src) if length&0xffffffff==0xffffffff else bytes(uc.mem_read(src,length&0xffffffff))
    ptr=alloc(len(b)+1);uc.mem_write(ptr,b+b'\0');wq(dst,ptr);wi(dst+8,len(b));wi(dst+12,len(b)+1)
def finish(v=0):
    rsp=uc.reg_read(UC_X86_REG_RSP);uc.reg_write(UC_X86_REG_RIP,q(rsp));uc.reg_write(UC_X86_REG_RSP,rsp+8);uc.reg_write(UC_X86_REG_RAX,v)
def hook(uc,a,n,_):
    if a==stop:uc.emu_stop();return
    x,y,z=[uc.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140c10368:finish(alloc(x))
    elif a==0x140c10370:finish()
    elif a==0x14003d8c0:copy(x,y,z);finish(x)
    elif a==0x140964530:copy(y,q(z),struct.unpack('<I',uc.mem_read(z+8,4))[0]);finish(y)
    elif not (0x140961540<=a<0x140963e86 or 0x140965af0<=a<0x140965c74):raise RuntimeError(f'Unmapped animation lookup dependency {a:x}')
    else:return
    substitutions.add(hex(a))
uc.hook_add(UC_HOOK_CODE,hook)
contexts=[]
for body,style,left in itertools.product([0,1],range(12),range(3)):
    names=[]
    for animation in range(426):
        uc.mem_write(heap,bytes(0x2000));cursor=heap+0x2000
        uc.mem_write(actor+0xdd,bytes([style,body,0,left]));wi(actor+0xec,0)
        rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));wq(rsp,stop)
        for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,out,animation]):uc.reg_write(reg,value)
        uc.reg_write(UC_X86_REG_RSP,rsp);uc.emu_start(0x140961540,stop,count=10000)
        assert uc.reg_read(UC_X86_REG_RIP)==stop
        names.append(cstring(q(out)).decode('ascii').lower())
    contexts.append({'fieldDE':body,'fieldDD':style,'fieldE0':left,'names':names})
output=root/'backups/animations/native-animation-name-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'substitutions':sorted(substitutions),'contexts':contexts},indent=2))
print(json.dumps({'output':str(output),'contexts':len(contexts),'executions':sum(len(c['names']) for c in contexts)}))
for context in contexts:
    if context['fieldE0']==0:print(json.dumps({**{k:v for k,v in context.items() if k!='names'},'samples':{str(i):context['names'][i] for i in [0,1,2,4,5,6,7,8,9,10,11,12,14,77,78,79,80,81,82,83,84,85,86,87,88,89]}}))
