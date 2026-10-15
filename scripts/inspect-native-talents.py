"""Read-only native feat/skill selector oracle for build89.8193.37-17.

Execute the two complete selector bodies in Unicorn. Synthetic native records
provide table metadata, ownership, remaining uses and effective skill ranks.
Allocator/container append/free and CRT rand are substituted. This verifies
candidate/rank/list/draw behavior, not full spell eligibility or encounter AI.
"""
from pathlib import Path
import sys,hashlib,struct,json
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
uc.mem_map(heap,0x200000);uc.mem_map(stack,0x10000);uc.mem_map(stop,0x1000)
cursor=heap+0x10000
def q(a):return struct.unpack('<Q',uc.mem_read(a,8))[0]
def i(a):return struct.unpack('<i',uc.mem_read(a,4))[0]
def wi(a,v):uc.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):uc.mem_write(a,struct.pack('<Q',v))
def alloc(n):
    global cursor
    p=cursor;cursor+=(max(n,1)+15)&~15;assert cursor<heap+0x200000
    uc.mem_write(p,bytes(max(n,1)));return p
def finish(v=0):
    rsp=uc.reg_read(UC_X86_REG_RSP);uc.reg_write(UC_X86_REG_RIP,q(rsp));uc.reg_write(UC_X86_REG_RSP,rsp+8);uc.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};draws=0;state=1;skill_calls=[];candidates=[];substitutions=set()
def hook(uc,a,n,_):
    global state,draws
    if a==stop:uc.emu_stop();return
    x,y,z=[uc.reg_read(r) for r in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8)]
    if a in [0x140c10324,0x140c10368]:finish(alloc(x))
    elif a in [0x140c10370,0x140c10360,0x140c4f024]:finish()
    elif a==0x14004bcf0:
        values=[i(q(x)+k*4) for k in range(i(x+8))]+[y&0xffffffff]
        p=alloc(len(values)*4)
        for k,v in enumerate(values):wi(p+k*4,v)
        wq(x,p);wi(x+8,len(values));wi(x+12,len(values));candidates.append(y&0xffffffff);finish()
    elif a==0x1402a3bd0:finish(heap+0x3000+(y&65535)*0x80 if y<len(case['feats']) and case['feats'][y].get('valid',1) else 0)
    elif a==0x14040b900:finish(case['feats'][y&65535].get('owned',1))
    elif a==0x1404012f0:finish(case['feats'][y&65535].get('uses',100)&255)
    elif a==0x140406a40:
        k=y&255;skill_calls.append(k);finish(case['skills'][k].get('rank',0)&255)
    elif a==0x140c7ed00:
        state=(state*214013+2531011)&0xffffffff;draws+=1;finish((state>>16)&32767)
    elif not (0x1403fb150<=a<0x1403fb32a or 0x1403fc050<=a<0x1403fc290):raise RuntimeError(f'Unmapped talent dependency {a:x}')
    else:return
    substitutions.add(hex(a))
uc.hook_add(UC_HOOK_CODE,hook)
observations=[]
for kind in ['feat','skill']:
    for word in [65535,0,4]:
        for maximum in [-1,0,1,20,-2]:
            for seed in [1,17]:
                case={'kind':kind,'word':word,'maxCR':maximum,'seed':seed,'category':16,
                  'feats':[{'category':16,'maxCR':1},{'category':16,'maxCR':9},{'category':16,'maxCR':9},
                    {'category':16,'maxCR':100,'uses':0},{'category':16,'maxCR':101,'valid':0},{'category':16,'maxCR':102,'owned':0},{'category':1,'maxCR':200}],
                  'ownedFeats':[2,0,1,2,3,4,5,6],
                  'skills':[{'category':16,'maxCR':1,'rank':1},{'category':16,'maxCR':9,'rank':0,'untrained':1},
                    {'category':16,'maxCR':9,'rank':257},{'category':16,'maxCR':100,'rank':-1},
                    {'category':1,'maxCR':200,'rank':2}]}
                cursor=heap+0x10000;uc.mem_write(heap,bytes(0x10000));draws=0;state=seed;skill_calls=[];candidates=[]
                stats,actor,rules=heap,heap+0x1000,heap+0x2000
                wq(stats+0x30,actor);uc.mem_write(actor+0x8d4,struct.pack('<H',word));wq(0x1412df8f8,rules)
                p=alloc(len(case['ownedFeats'])*2);uc.mem_write(p,struct.pack('<'+'H'*len(case['ownedFeats']),*case['ownedFeats']))
                wq(stats,p);wi(stats+8,len(case['ownedFeats']))
                for k,row in enumerate(case['feats']):wi(heap+0x3000+k*0x80+8,row['category']);wi(heap+0x3000+k*0x80+12,row['maxCR'])
                wq(rules+0x120,heap+0x4000);uc.mem_write(rules+0x107,bytes([len(case['skills'])]))
                for k,row in enumerate(case['skills']):
                    for offset,key in [(8,'category'),(12,'maxCR'),(0x28,'untrained')]:wi(heap+0x4000+k*0x38+offset,row.get(key,0))
                out=heap+0x5000;wi(out,-1);wi(out+4,-1)
                rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));wq(rsp,stop);wq(rsp+0x28,out+4);wq(rsp+0x30,out+8)
                for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[stats,case['category'],maximum&0xffffffff,out]):uc.reg_write(reg,value)
                uc.reg_write(UC_X86_REG_RSP,rsp);uc.emu_start(0x1403fb150 if kind=='feat' else 0x1403fc050,stop,count=100000)
                assert uc.reg_read(UC_X86_REG_RIP)==stop
                observations.append({**case,'result':{'found':uc.reg_read(UC_X86_REG_RAX)&0xffffffff,'type':i(out),'id':i(out+4),'draws':draws,'skillCalls':skill_calls}})
output=root/'backups/animations/native-talent-selector-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'substitutions':sorted(substitutions),'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
