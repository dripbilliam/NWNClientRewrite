"""Read-only full CanEquipWeapon1403d19c0 build89 oracle. Synthetic base
rows, equipment lookup and feedback captured; client lookup returns NULL.
Does not validate client preview mutation, acquisition or property effects.
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
actor,item,right,left,app,slot,info=[heap+n*0x1000 for n in range(7)]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,int.from_bytes(u.mem_read(rsp,8),'little'));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
case={};calls=[]
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
    if a==0x14055b390:finish()
    elif a==0x14029ca00:
        entry=case['base'] if y==case['base']['id'] else case['rightBase'] if y==100 else case['leftBase']
        pointer=info+(0 if y==case['base']['id'] else 0x100 if y==100 else 0x200)
        u.mem_write(pointer,bytes(0x100));wi(pointer+4,entry.get('equipableSlots',0x3ffff));u.mem_write(pointer+8,bytes([entry['weaponWield']]));u.mem_write(pointer+9,bytes([entry['weaponType']]));u.mem_write(pointer+0x18,bytes([entry['ranged']]));u.mem_write(pointer+0x19,bytes([entry['weaponSize']]));finish(pointer)
    elif a==0x140462bd0:finish((right if case['rightBase'] else 0) if y==16 else (left if case['leftBase'] else 0) if y==32 else 0)
    elif a==0x1403a2480:calls.append(y&65535);finish()
    elif a==0x140402f80:finish(case.get('dm',0))
    elif a==0x1403d54d0:finish()
    elif a in [0x1403d2830,0x1403d2c00,0x1403d2ce0]:finish(case.get('restrictions',1))
    elif a==0x1403d2d90:finish(case.get('proficient',1))
    elif a==0x140392fd0:finish(case['rightBase']['weaponSize']-3)
    elif not(0x1403d19c0<=a<0x1403d22a6 or 0x1403d12c0<=a<0x1403d178e):raise RuntimeError(f'Unmapped weapon gate {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def row(id=3,wield=0,kind=1,ranged=0,size=3):return dict(id=id,weaponWield=wield,weaponType=kind,ranged=ranged,weaponSize=size)
bases=[row(),row(4),row(47),row(30),row(31,7),row(32,0,0),row(33,10,1,1),row(34,11,1,1),row(35,0,1,1)]
rights=[None,row(100),row(100,size=4),row(100,ranged=1),row(100,10,1,1),row(100,11,1,1)]
lefts=[None,row(101),row(101,7),row(101,0,0)]
observations=[]
for b,r,l,s,relative,flags in itertools.product(bases,rights,lefts,[16,32],[-3,-2,0,1,2],[(0,0),(1,0),(1,1)]):
    b=dict(b,weaponSize=3+relative);case=dict(base=b,rightBase=r,leftBase=l,slot=s,check=flags[0],feedback=flags[1]);calls=[]
    u.mem_write(heap,bytes(0x10000));wq(0x1412df8f8,app);wq(0x1412df970,app);wq(app+8,app);wq(app+0x20,app)
    wi(actor+8,99);wi(actor+0x718,3);wi(item+0x40,b['id']);wi(item+0x50,1);wi(right+0x40,100);wi(right+0x50,2);wi(left+0x40,101);wi(left+0x50,3);wi(slot,s)
    rsp=stack+0xff08;wq(rsp,stop);wi(rsp+0x28,flags[1]);wq(rsp+0x30,0)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP],[actor,item,slot,flags[0],rsp]):u.reg_write(reg,val)
    u.emu_start(0x1403d19c0,stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'case':case,'result':u.reg_read(UC_X86_REG_RAX)&255,'slot':int.from_bytes(u.mem_read(slot,4),'little'),'feedback':calls})
output=root/'backups/animations/native-equipment-weapon-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2));print(json.dumps({'observations':len(observations),'output':str(output)}))
observations=[]
for b,r,l,s,relative in itertools.product(bases+[row(14,7,0),row(56,7,0),row(57,7,0)],rights,lefts,[1,2,16,32,2048,4096,8192],[-2,0,1,2]):
    b=dict(b,weaponSize=3+relative);case=dict(base=b,rightBase=r,leftBase=l,slot=s,check=1,feedback=1);calls=[]
    u.mem_write(heap,bytes(0x10000));wq(app+8,app);wq(app+0x20,app);wq(actor+0xad0,app+0x1000)
    wi(actor+8,99);wi(actor+0x718,3);wi(item+0x40,b['id']);wi(item+0x50,1);wi(right+0x40,100);wi(right+0x50,2);wi(left+0x40,101);wi(left+0x50,3);wi(slot,s)
    rsp=stack+0xff08;wq(rsp,stop);wi(rsp+0x28,1);wi(rsp+0x30,1);wq(rsp+0x38,0)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP],[actor,item,slot,1,rsp]):u.reg_write(reg,val)
    u.emu_start(0x1403d12c0,stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'case':case,'result':u.reg_read(UC_X86_REG_RAX)&255,'slot':int.from_bytes(u.mem_read(slot,4),'little'),'feedback':calls})
output=root/'backups/animations/native-equipment-import-gate-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__+' Import gates execute with restrictions/proficiency true, DM/possessed false, stats-PC0 and flags(1,1,1,NULL).','observations':observations},indent=2));print(json.dumps({'observations':len(observations),'output':str(output)}))
observations=[]
for b,r,l,s,dm,locked,restrictions,proficient in itertools.product([row(),row(35,0,1,1),row(14,7,0)],rights[:3],lefts[:2],[16,32,2],[0,1],[0,1,2],[0,1],[0,1]):
    case=dict(base=b,rightBase=r,leftBase=l,slot=s,check=0,feedback=1,dm=dm,locked=locked,restrictions=restrictions,proficient=proficient);calls=[]
    u.mem_write(heap,bytes(0x10000));wq(app+8,app);wq(app+0x20,app);wq(actor+0xad0,app+0x1000)
    wi(actor+8,99);wi(actor+0x718,3);wi(actor+0x97c,locked);wi(item+0x40,b['id']);wi(item+0x50,1);wi(right+0x40,100);wi(right+0x50,2);wi(left+0x40,101);wi(left+0x50,3);wi(slot,s)
    rsp=stack+0xff08;wq(rsp,stop);wi(rsp+0x28,0);wi(rsp+0x30,1);wq(rsp+0x38,0)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP],[actor,item,slot,0,rsp]):u.reg_write(reg,val)
    u.emu_start(0x1403d12c0,stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'case':case,'result':u.reg_read(UC_X86_REG_RAX)&255,'slot':int.from_bytes(u.mem_read(slot,4),'little'),'feedback':calls})
output=root/'backups/animations/native-equipment-ai-gate-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__+' AI gates execute with explicit restriction/proficiency/DM and inventory lock fixtures, stats-PC0, possessed0 and flags(0,0,1,NULL).','observations':observations},indent=2));print(json.dumps({'observations':len(observations),'output':str(output)}))
