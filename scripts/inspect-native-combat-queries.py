"""Read-only build89 combat script-query oracle. Original feat/spell-effect
queries, arcane-failure wrapper, IntToFloat wrapper, ability-modifier wrapper
and DEX(param0) execute. VM stack, creature/feat lookup are captured substitutes.
Cached input bytes are synthetic; cache initialization/equipment effects and
original encounter execution are not validated by these runs.
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
actor,stats,info,pool,vm,command=[heap+n*0x1000 for n in range(6)]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,int.from_bytes(u.mem_read(rsp,8),'little'));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};pushed=None
allowed=[(0x140495480,0x1404954e8),(0x140495f80,0x140495fbd),(0x14051ece0,0x14051ed90),(0x140314080,0x1403140cc),(0x14051e340,0x14051e44f),(0x1403fd280,0x1403fd3da)]
def hook(u,a,n,_):
    global pushed
    if a==stop:u.emu_stop();return
    x,y=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
    if a==0x1402a3bd0:finish(info if case['valid'] else 0)
    elif a in [0x140286110,0x140286160]:wi(y,case.get('input',0));finish(1)
    elif a==0x14055b3d0:finish(actor if case.get('present',True) else 0)
    elif a==0x140286410:pushed=struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0];finish(1)
    elif a==0x1402863b0:pushed=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM1)&0xffffffff))[0];finish(1)
    elif not any(start<=a<end for start,end in allowed):raise RuntimeError(f'Unmapped query {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(address,first,second=0):
    global pushed
    pushed=None;rsp=stack+0xff08;u.mem_write(rsp-0x400,bytes(0x480));wq(rsp,stop)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSP],[first,second,rsp]):u.reg_write(reg,val)
    u.reg_write(UC_X86_REG_MXCSR,0x1f80);u.emu_start(address,stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==stop
    return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def reset():
    u.mem_write(heap,bytes(0x10000));wq(0x1412df8f8,vm);wq(0x1412df910,vm);wq(0x1412df970,vm);wq(vm+8,vm);wq(command+0x10,vm);wq(actor+0xad0,stats)
effects=[]
for valid,spell,entries in itertools.product([False,True],[-1,0,1,-2147483648], [[],[-1],[0],[1],[-2147483648],[2,1,2]]):
    case=dict(valid=valid,spell=spell,entries=entries);reset();wi(info+0x60,spell);wq(actor+0x150,pool);wi(actor+0x158,len(entries))
    for index,value in enumerate(entries):p=pool+0x100+index*0x40;wq(pool+index*8,p);wi(p+0x1c,value)
    feat=run(0x140495480,actor,0);spell_result=run(0x140495f80,actor,spell&0xffffffff)
    effects.append({'case':case,'feat':feat,'spell':spell_result})
arcane=[]
for values in itertools.product([0,1,50,100,127,128,255],repeat=3):
    case={'input':0};reset();u.mem_write(stats+0xd78,bytes(values));run(0x14051ece0,command)
    arcane.append({'bytes':values,'result':pushed})
scalar=[]
for value in [-2147483648,-16777219,-16777217,-1,0,1,16777215,16777216,16777217,16777219,2147483647,4294967295]:
    case={'input':value};reset();run(0x140314080,command);scalar.append({'input':value,'result':pushed})
abilities=[]
for present,index,value in itertools.product([False,True],[-1,0,1,2,3,4,5,6,256],[0,1,127,128,255]):
    case={'input':index,'present':present};reset()
    for offset in [0xd39,0xd3b,0xd3d,0xd3f,0xd41,0xd43]:u.mem_write(stats+offset,bytes([value]))
    run(0x14051e340,command);abilities.append({'case':dict(case,value=value),'result':pushed})
output=root/'backups/animations/native-combat-query-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'effects':effects,'arcane':arcane,'scalar':scalar,'abilities':abilities},indent=2))
print(json.dumps({'output':str(output),'observations':len(effects)*2+len(arcane)+len(scalar)+len(abilities)}))
