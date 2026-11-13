"""Original CG_MAIN callback/reset instructions over synthetic native control state.
GUI/string, draft/rule query, child opening and summary refresh are captured
boundaries. No game, GPU, original save, live process or network is executed.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,random
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
panel,sheet,creature,stats,rules,version,vtable=[heap+i*0x2000 for i in range(7)]
offsets=dict(align=0x1a8,abilities=0x298,**{'class':0x470},customize=0x560,play=0x650,packages=0x740,portrait=0x830,race=0x920,gender=0xaf8)
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
    if a==0x1401eb800:wi(x+8,(si(x+8)&~1)|(0 if y else 1));finish()
    elif a==0x1401e5d20:wi(x+0xc8,y);finish()
    elif a==0x1401eb5c0:finish()
    elif a==0x140800c90:finish(creature if c['present'] else 0)
    elif a==0x1407edcc0:calls.append('reset_derived');finish()
    elif a==0x14088b180:calls.append('refresh');finish()
    elif a==0x1407f0f60:finish(c['classBase'])
    elif a==0x1406aba60:finish(c['appMode'])
    elif a==0x1408e25c0:calls.append('appearance');finish()
    elif a==0x1408e3f90:calls.append('finish');finish()
    elif a==0x1408e58c0:calls.append('portrait');finish()
    elif a==0x1401fc470:calls.append('deactivate:'+str(y&0xffffffff));finish()
    elif a==stop+16:calls.append('delete');finish()
    elif a==0x1408e0970:calls.append('retire_draft');finish()
    elif a==0x1408e0840:calls.append('initialize_draft');finish(1)
    elif not(0x1408e9be0<=a<=0x1408ea63d or 0x1408ef940<=a<=0x1408ef993 or 0x1408e6780<=a<0x1408e6b00):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def setup(c):
    u.mem_write(heap,bytes(0x20000));wq(panel,vtable);wq(vtable,stop+16);wq(panel+0x1a0,sheet);wq(creature+0x3b0,stats);wq(0x1412df8f8,rules);wq(rules+0x110,version)
    wq(0x1412df970,heap+0xe000);wq(heap+0xe000,heap+0xf000)
    # Physical Paladin class row6, stride0x530: alignment mask/type/invert.
    u.mem_write(version+0x23c1,bytes([21 if c['paladinRuleDefault'] else 20,3]));wi(version+0x23c4,0);wi(panel+0xf4,c['customizeMode']);u.mem_write(sheet+0x150,bytes([c['summaryMask']]))
    for tag,offset in offsets.items():
        wi(panel+offset+8,0 if c['enabled'][tag] else 1);wi(panel+offset+0xe8,int(c['completed'][tag]));wi(panel+offset+0xc8,int(c['encouraged'][tag]))
    wq(panel+0xc08,panel+offsets[c['recommended']] if c['recommended'] else 0)
def invoke(entry,code=0):
    rsp=stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel);u.reg_write(UC_X86_REG_RDX,code&0xffffffff)
    try:u.emu_start(entry,stop,count=20000)
    except Exception as error:raise RuntimeError(dict(input=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))) from error
    assert u.reg_read(UC_X86_REG_RIP)==stop
def state():
    recommended=q(panel+0xc08)-panel
    return dict(enabled={tag:not bool(si(panel+off+8)&1) for tag,off in offsets.items()},completed={tag:bool(si(panel+off+0xe8)) for tag,off in offsets.items()},encouraged={tag:bool(si(panel+off+0xc8)) for tag,off in offsets.items()},recommended=next((tag for tag,off in offsets.items() if off==recommended),''),summaryMask=int.from_bytes(u.mem_read(sheet+0x150,1),'little'),alignment=[int.from_bytes(u.mem_read(stats+off,2),'little') for off in [0xc6,0xc8]],calls=calls)
rng=random.Random(19331);cases=[]
codes=[-2147483646,2,3,0x8001,0x8002,0x8003,0x8004,0x8005,0x8007,0x8008,0x8009,0x800a,0x800d,0x800e,0x8017,0x9999]
for code,custom,pattern,app in itertools.product(codes,[0,1],range(4),[0,1]):
    recommended=['','gender','class','play'][pattern]
    enabled={tag:bool(rng.getrandbits(1)) if pattern==3 else pattern!=0 for tag in offsets}
    completed={tag:bool(rng.getrandbits(1)) if pattern==3 else pattern==2 for tag in offsets}
    c=dict(code=code,customizeMode=custom,appMode=app,present=True,classBase=6 if pattern%2 else 0,paladinRuleDefault=pattern%2==1,summaryMask=pattern*7,enabled=enabled,completed=completed,encouraged={tag:tag==recommended for tag in offsets},recommended=recommended)
    setup(c);calls=[];invoke(0x1408e9be0,code);cases.append(dict(input=c,output=state()))
for pattern in range(4):
    c=dict(cases[pattern]['input']);c['enabled']=dict(c['enabled']);c['enabled']['packages']=False;c['code']=0x8004;c['present']=False;setup(c);calls=[];invoke(0x1408e9be0,c['code']);cases.append(dict(input=c,output=state()))
for custom,app,class_base,default,downstream in itertools.product([0,1],[0,1],[0,6],[False,True],[False,True]):
    c=dict(cases[2]['input']);c['enabled']=dict(c['enabled']);c['enabled']['packages']=downstream;c.update(code=0x8004,customizeMode=custom,appMode=app,classBase=class_base,paladinRuleDefault=default)
    setup(c);calls=[];invoke(0x1408e9be0,c['code']);cases.append(dict(input=c,output=state()))
resets=[]
for pattern in range(4):
    c=dict(cases[pattern+30]['input']);setup(c);calls=[];invoke(0x1408e6780);resets.append(dict(input=c,output=state()))
path=root/'backups/animations/native-creation-main-flow-v2.json'
if path.exists():raise RuntimeError('Evidence already exists')
path.write_text(json.dumps(dict(target=digest,scope=__doc__,entry='0x1408e9be0',resetEntry='0x1408e6780',cases=cases,resets=resets),indent=2)+'\n')
print(json.dumps(dict(cases=len(cases),resets=len(resets),target=digest)))
