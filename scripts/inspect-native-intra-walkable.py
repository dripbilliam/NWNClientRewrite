"""Read-only tile/area walkable wrappers with original location, rotation and
NoNonWalkPolys forwarding bodies. Surface clipping/denied triangles, detailed
object collision and creature queries are captured boundaries. Verifies FLOAT
padding, strict endpoint tolerance, flags, ID forwarding and query short-circuits.
"""
from pathlib import Path
import sys,struct,hashlib,json,re,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
surface,tile,area,path,output,vtable=[heap+n*0x1000 for n in range(6)]
ranges=[]
for file in ['live-native-intra-walkable-full-asm.txt','live-native-intra-walkable-rotation-asm.txt']:
    for line in (root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1402bb580:
        start=[xmm(UC_X86_REG_XMM2),xmm(UC_X86_REG_XMM3)];end=[rf(rsp+0x28),rf(rsp+0x30)];calls.append(['clipped',start,end])
        values=start+[f(end[0]+c['delta']),end[1],c['low'],c['high']]
        for off,value in zip([0x38,0x40,0x48,0x50,0x58,0x60],values):wf(q(rsp+off),value)
        finish(c['clipResult'])
    elif a==0x1402c3010:
        calls.append(['denied',[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)],[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)],rf(rsp+0x30),rf(rsp+0x38),rf(rsp+0x40),i(rsp+0x48)]);finish(c['denied'])
    elif a==0x140297c50:
        calls.append(['objects',[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)],[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)],rf(rsp+0x30),rf(rsp+0x38),rf(rsp+0x40),i(rsp+0x48),i(rsp+0x58),bool(q(rsp+0x60)),i(rsp+0x68)]);finish(c['objects'])
    elif a==stop+0x100:
        calls.append(['creatures',[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)],[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)],i(rsp+0x38),i(rsp+0x40),bool(q(rsp+0x48)),i(rsp+0x50)]);finish(c['creatures'])
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped intra-tile walkable dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(heap,bytes(0x10000));wi(tile+0x1c,c['x']);wi(tile+0x20,c['y']);wi(tile+0x24,c['orientation']);wf(tile+0x10,c['elevation']);wf(path+4,c['radius']);wf(path+0xc,c['height']);wi(path+0xc8,0x80000001);wq(area,vtable);wq(vtable+8,stop+0x100)
    rsp=stack+0xff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface)
    for reg,value in zip([UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3],c['from']+[c['to'][0]]):u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
    wf(rsp+0x28,c['to'][1])
    if c['mode']=='tile':entry=0x1402c5250;wq(rsp+0x30,output);wq(rsp+0x38,output+4);wq(rsp+0x40,path);wq(rsp+0x48,tile);wi(rsp+0x50,c['strict'])
    else:entry=0x1402c5060;wf(rsp+0x30,c['low']);wf(rsp+0x38,c['high']);wq(rsp+0x40,path);wq(rsp+0x48,tile);wq(rsp+0x50,area)
    try:u.emu_start(entry,stop,count=5000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,low=rf(output),high=rf(output+4))
default=dict(mode='tile',x=7,y=10,orientation=0,elevation=1.75,to=[5,0],radius=.6,height=.5,low=-1,high=2,strict=0,clipResult=1,denied=1,objects=1,creatures=1,delta=0,**{'from':[2.8,4.8]})
rows=[run(default|dict(x=x,strict=strict,clipResult=result,delta=delta,denied=denied,height=height)) for x,strict,result,delta,denied,height in itertools.product([0,7],[0,1,2],[0,1,2],[0,.000001,.00001,.001],[0,1,2],[.5,.000001])]
rows += [run(default|dict(mode='area',orientation=orientation,x=x,y=y,elevation=elevation,objects=objects,creatures=creatures)) for orientation,x,y,elevation,objects,creatures in itertools.product([0,1,2,3],[0,7],[0,10],[0,1.75,-5],[0,1,2],[0,1,2])]
out=root/'backups/animations/native-intra-walkable-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
