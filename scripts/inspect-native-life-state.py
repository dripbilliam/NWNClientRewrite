"""Read-only native GetDead/GetIsPCDying/possessed-familiar oracle.

Executes complete owners; synthetic virtual AsCreature and HP queries and
client lookup are substituted. Validates flag/SHORT HP gates and query counts,
not HP calculation, client possession management or the complete death owner.
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
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
actor,vt=heap,heap+0x1000
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
case={};hp_queries=0;client_queries=0
def hook(u,a,n,_):
    global hp_queries,client_queries
    if a==stop:u.emu_stop();return
    if a==stop+0x10:finish(actor if case['creature'] else 0)
    elif a==stop+0x20:hp_queries+=1;finish(case['hp']&65535)
    elif a==0x14055b590:client_queries+=1;finish(case['client'])
    elif not(0x1404953b0<=a<0x140495461 or 0x140495620<=a<0x14049568d or 0x1403d54d0<=a<0x1403d5506):raise RuntimeError(f'Unmapped life-state dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
observations=[]
for creature,pc,associate,client,hp in itertools.product([0,1],[0,1,-1],[0,3,65539],[0,1],[-10,-9,0,1,32768,65526]):
    case={'creature':creature,'pc':pc,'associate':associate,'client':client,'hp':hp};result={}
    for name,address in [('dead',0x1404953b0),('dying',0x140495620)]:
        u.mem_write(heap,bytes(0x10000));wq(actor,vt);wq(vt+0x60,stop+0x10);wq(vt+0x138,stop+0x20)
        u.mem_write(actor+0x89c,struct.pack('<I',pc&0xffffffff));u.mem_write(actor+0x908,struct.pack('<H',associate&65535))
        wq(0x1412df970,heap+0x2000);hp_queries=0;client_queries=0
        rsp=stack+0xff08;wq(rsp,stop);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RSP,rsp)
        u.emu_start(address,stop,count=500);assert u.reg_read(UC_X86_REG_RIP)==stop
        result[name]={'value':u.reg_read(UC_X86_REG_RAX),'hpQueries':hp_queries,'clientQueries':client_queries}
    observations.append({'case':case,'result':result})
output=root/'backups/animations/native-life-state-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations),'executions':len(observations)*2}))
