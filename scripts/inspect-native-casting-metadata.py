"""Original bounded spell-loader animation/path mapping and scalar stores.
2DA reads and ASCII CExoString lowercase are captured input boundaries;
original comparisons/branches and storage widths execute. CRT strcmp is
captured. Full loader allocation, other metadata and locale are not claimed.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,wi,wq,finish=[getattr(m,n) for n in ['q','wi','wq','finish']]
array,spell,text=[m.heap+n*0x1000 for n in range(1,4)]
ranges={'conjure':(0x1402b0862,0x1402b08f3,0x74,2),'cast':(0x1402b0fce,0x1402b11ab,0xdc,2),
    'path':(0x1402b1cb4,0x1402b1eba,0x140,4),'conjureTime':(0x1402b0778,0x1402b0786,0x70,4),
    'castTime':(0x1402b0eef,0x1402b0f00,0xe0,4),'projectile':(0x1402b19d0,0x1402b19e1,0x128,4),
    'userType':(0x1402b2422,0x1402b2434,0x184,1),'spontaneous':(0x1402b24c8,0x1402b24d9,0x188,4),
    'targetType':(0x1402b0196,0x1402b01a6,0x50,2),'concentration':(0x1402afde5,0x1402afdf6,0x174,4),
    'hasProjectile':(0x1402b27d3,0x1402b27e4,0x19c,4)}
def cstring(addr):return bytes(u.mem_read(addr,128)).split(b'\0')[0]
def hook(u,a,n,_):
    if a==end:u.emu_stop();return
    if a==0x140c799d0:
        x,y=[cstring(u.reg_read(reg)) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX]];finish(0 if x==y else 1)
    elif not start<=a<end:raise AssertionError(f'Uncaptured metadata dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(mode,inputValue):
    global start,end
    start,end,offset,size=ranges[mode];u.mem_write(m.heap,bytes(0x100000));wq(array+8,spell)
    rsp=m.stack+0x1e008;u.mem_write(rsp-0x400,bytes(0x1800));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0x100)
    u.reg_write(UC_X86_REG_RDI,array);u.reg_write(UC_X86_REG_RSI,0);u.reg_write(UC_X86_REG_R13,0);u.reg_write(UC_X86_REG_R12,0);u.reg_write(UC_X86_REG_RBX,8)
    if isinstance(inputValue,str):
        raw=inputValue.lower().encode('ascii')+b'\0';u.mem_write(text,raw);wq(rsp+0x40,text);wi(rsp+0x48,len(raw)-1)
    else:wi(rsp+0x908,inputValue)
    u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==end
    return dict(mode=mode,input=inputValue,value=int.from_bytes(u.mem_read(spell+offset,size),'little'))
rows=[]
for mode in ['conjure','cast','path']:
    for textValue in ['', '****','hand','head','out','self','up','area','point','touch','attack','creature','homing','ballistic','highballistic','accelerating','spiral','linked','bounce','burst','test','unknown','constructor','__proto__']:
        for variant in [textValue,textValue.upper(),textValue+'suffix',textValue+' ',textValue+'\0suffix']:rows.append(run(mode,variant))
for mode in ['conjureTime','castTime','projectile','userType','spontaneous','targetType','concentration','hasProjectile']:
    for value in [-2147483648,-1,0,1,255,256,65535,0x7fffffff]:rows.append(run(mode,value))
out=m.root/'backups/animations/native-casting-metadata-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
