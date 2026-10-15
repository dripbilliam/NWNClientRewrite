"""Read-only native client melee selector oracle, build89.8193.37-17.

Executes complete distance-branch selector bodies plus native normalize/cross
vector helpers. Queries substitute synthetic class, equipment, target and
height records. CRT rand uses the original MSVC recurrence; sqrtf is replaced
by rounded IEEE sqrt. No rendering, timing/packets or full encounter oracle.
"""
from pathlib import Path
import sys,hashlib,struct,json,itertools,math
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
uc=Uc(UC_ARCH_X86,UC_MODE_64);uc.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);uc.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
uc.mem_map(heap,0x20000);uc.mem_map(stack,0x10000);uc.mem_map(stop,0x1000)
actor,target,context,record,out,stats,weapon,left,info,app,vt=[heap+n*0x1000 for n in range(11)]
cursor=heap+0x10000;case={};state=1;draws=0;substitutions=set()
def q(a):return struct.unpack('<Q',uc.mem_read(a,8))[0]
def wi(a,v):uc.mem_write(a,struct.pack('<I',v&0xffffffff))
def wh(a,v):uc.mem_write(a,struct.pack('<H',v&65535))
def wb(a,v):uc.mem_write(a,bytes([v&255]))
def wq(a,v):uc.mem_write(a,struct.pack('<Q',v))
def alloc(n):
    global cursor
    p=cursor;cursor+=(max(n,1)+15)&~15;assert cursor<heap+0x20000
    uc.mem_write(p,bytes(max(n,1)));return p
def finish(v=0):
    rsp=uc.reg_read(UC_X86_REG_RSP);uc.reg_write(UC_X86_REG_RIP,q(rsp));uc.reg_write(UC_X86_REG_RSP,rsp+8);uc.reg_write(UC_X86_REG_RAX,v)
def hook(uc,a,n,_):
    global state,draws
    if a==stop:uc.emu_stop();return
    if a==0x14042aff2 and case.get('kind')=='death':uc.emu_stop();return
    x,y,z,w=[uc.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if '--debug' in sys.argv and case==cases[12] and a in [0x140810e81,0x140810e95,0x140810fcd]:
        print(json.dumps({'debug':hex(a),'case':case,'actorID':struct.unpack('<I',uc.mem_read(actor+8,4))[0],'targetLock':struct.unpack('<I',uc.mem_read(target+0x3a8,4))[0],'r14':hex(uc.reg_read(UC_X86_REG_R14)),'rdi':hex(uc.reg_read(UC_X86_REG_RDI)),'eax':uc.reg_read(UC_X86_REG_RAX),'ecx':uc.reg_read(UC_X86_REG_RCX)}))
    if a==stop+0x100:wh(out,y);finish()
    elif a==0x1406abb60:finish(target)
    elif a==stop+0x10:finish(x)
    elif a==stop+0x20:finish(x if case['targetCreature'] else 0)
    elif a==0x1407630a0:finish(context)
    elif a==0x140763220:finish(case['targetBase'])
    elif a==0x140764300:finish()
    elif a==0x1407f0f60:finish(5 if case['monk'] else 0)
    elif a==0x1406abc80:finish(weapon if y==100 and case['weapon'] else left if y==101 and case['shield'] else 0)
    elif a==0x14029ca00:finish(info if case['validBase'] else 0)
    elif a==0x140c7ed00:
        state=(state*214013+2531011)&0xffffffff;draws+=1;finish((state>>16)&32767)
    elif a==0x140c10368:finish(alloc(x))
    elif a==0x140c10370:finish()
    elif a==0x1401a68f0:
        b=case['height'].encode('ascii');p=alloc(len(b)+1);uc.mem_write(p,b+b'\0');wq(w,p);wi(w+8,len(b));wi(w+12,len(b)+1);finish(1)
    elif a==0x140c7d6d8:
        bits=uc.reg_read(UC_X86_REG_XMM0)&0xffffffff;v=struct.unpack('<f',struct.pack('<I',bits))[0]
        result=struct.unpack('<I',struct.pack('<f',math.sqrt(v)))[0];uc.reg_write(UC_X86_REG_XMM0,result);finish()
    elif not (0x14080ffd0<=a<0x140810649 or 0x140810c20<=a<0x140810ffb or 0x14080f7b0<=a<0x14080fa59 or
              0x140230920<=a<0x1402309f5 or 0x14022fba0<=a<0x14022fbfa or
              case.get('kind')=='death' and 0x14042aedc<=a<0x14042aff2):raise RuntimeError(f'Unmapped combat-animation selector dependency {a:x}')
    else:return
    substitutions.add(hex(a))
uc.hook_add(UC_HOOK_CODE,hook)
cases=[]
for branch,side,style,has_weapon,has_shield,monk,reaction,target_base,seed in itertools.product(range(1,4),range(3),[1,3],[0,1],[0,1],[0,1],[1,11,12,14],[0,5],[1,17]):
    cases.append({'branch':branch,'side':side,'style':style,'weapon':has_weapon,'shield':has_shield,'monk':monk,
      'reaction':reaction,'targetBase':target_base,'seed':seed,'slashLeft':50,'slashRight':50,'validBase':1,
      'targetCreature':1,'lockTarget':21,'height':'H','position':[1,0,0],'orientation':[1,0,0]})
for branch,position,orientation,target_base,lock in itertools.product(range(1,4),[[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[1,1,0],[0,0,0]],[[1,0,0],[0,1,0]], [0,7,6,8],[21,0x7f000000]):
    cases.append({'branch':branch,'side':0,'style':3,'weapon':1,'shield':0,'monk':0,'reaction':14,'targetBase':target_base,'seed':1,
      'slashLeft':0,'slashRight':100,'validBase':1,'targetCreature':1,'lockTarget':lock,'height':'L','position':position,'orientation':orientation})
observations=[]
for case in cases:
    cursor=heap+0x10000;state=case['seed'];draws=0;uc.mem_write(heap,bytes(0x10000))
    wq(0x1412df970,app);wq(app,app+0x100);wq(0x1412df8f8,app);wq(app+0x130,app+0x200);wq(app+0x220,app+0x300)
    wq(actor+0x78,context);wb(actor+0x170,case['side']);wi(actor+8,21);wq(actor+0x3b0,stats);wb(stats+0x69,1)
    for k,v in enumerate(case['position']):uc.mem_write(actor+0x38+k*4,struct.pack('<f',v))
    wq(target,vt);wq(vt+0x18,stop+0x10);wq(vt+0x58,stop+0x20);wq(target+0x300,stats);wi(target+0x3a8,case['lockTarget'])
    for k,v in enumerate(case['orientation']):uc.mem_write(target+0x44+k*4,struct.pack('<f',v))
    wb(context+0xdd,case['style']);wb(context+0xe0,case['side']);wi(actor+0x318,100 if case['weapon'] else 0x7f000000);wi(actor+0x31c,101 if case['shield'] else 0x7f000000)
    wi(weapon+0x40,22);wi(left+0x40,14);wb(info+0x35,case['slashLeft']);wb(info+0x36,case['slashRight'])
    wh(out,9);wh(record+0x16,case['reaction']);wi(record+0x10,22);wb(record+0x24,1)
    rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));wq(rsp,stop)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,out,record]):uc.reg_write(reg,value)
    uc.reg_write(UC_X86_REG_RSP,rsp);uc.emu_start({1:0x140810c20,2:0x14080ffd0,3:0x14080f7b0}[case['branch']],stop,count=20000)
    assert uc.reg_read(UC_X86_REG_RIP)==stop
    observations.append({**case,'result':{'animation':struct.unpack('<H',uc.mem_read(out,2))[0],
      'reaction':struct.unpack('<H',uc.mem_read(record+0x16,2))[0],'side':uc.mem_read(actor+0x170,1)[0],
      'contextSide':uc.mem_read(context+0xe0,1)[0],'draws':draws}})
death_observations=[]
for body,source,orientation in itertools.product([0,3,4,5,6,259], [None,[1,0,0],[-1,0,0],[0,1,0],[1,1,0]], [[1,0,0],[0,1,0]]):
    case={'kind':'death','body':body,'source':source,'orientation':orientation};uc.mem_write(heap,bytes(0x10000))
    wq(actor,vt);wq(vt+0x100,stop+0x100);wb(actor+0x6b4,body);wh(out,65535)
    if source:
        for k,v in enumerate(source):uc.mem_write(target+0xa4+k*4,struct.pack('<f',v))
    for k,v in enumerate(orientation):uc.mem_write(actor+0xb0+k*4,struct.pack('<f',v))
    rsp=stack+0xff00;uc.mem_write(rsp-0x100,bytes(0x180))
    for reg,value in zip([UC_X86_REG_RDI,UC_X86_REG_R15,UC_X86_REG_R13,UC_X86_REG_RSP,UC_X86_REG_RBP],[actor,target if source else 0,1,rsp,rsp+0x50]):uc.reg_write(reg,value)
    uc.emu_start(0x14042aedc,stop,count=1000)
    assert uc.reg_read(UC_X86_REG_RIP)==0x14042aff2
    death_observations.append({**case,'result':{'body':uc.mem_read(actor+0x6b4,1)[0],'animation':struct.unpack('<H',uc.mem_read(out,2))[0]}})
output=root/'backups/animations/native-client-combat-animation-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__+' Death observations execute only the verified animation phase14042aedc..14042aff2, not the complete death owner.',
    'substitutions':sorted(substitutions),'observations':observations,'deathObservations':death_observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
