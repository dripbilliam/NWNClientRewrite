"""Read-only CNWSTile/surface path getters with original tile rotations.
GetTilePathNode resolves the previously instruction-captured graph arrays.
Loaded-mesh state is synthetic; loader/logging/uninitialized failed output
and negative/out-of-range indexed accesses are deliberately outside coverage.
"""
from pathlib import Path
import sys,struct,hashlib,json,re
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
tile,info,mesh,node,centres,exits,regions,output,app=[heap+n*0x1000 for n in range(9)]
ranges=[]
for file in ['live-native-path-getters-full-asm.txt','live-native-path-getter-rotation-asm.txt']:
    for line in (root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    if a==0x1402ca830:finish(node)
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped path getter dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
graphs=json.loads((root/'backups/animations/native-tile-path-node-observations.json').read_text())['graphs']
def run(case):
    c=case;graph=graphs[str(c['kind'])][c['nodeOrientation']];u.mem_write(heap,bytes(0x10000));wq(0x1412df970,app);wq(app+0x10,app);wq(tile+0x30,info);wi(tile+0x24,c['orientation']);wq(info+8,mesh);wq(mesh+0x78,centres);u.mem_write(mesh+0x39,bytes([c['kind']]));wi(mesh+0x3c,c['nodeOrientation'])
    wi(node,len(graph['centres']));wi(node+4,len(graph['entrances']));wq(node+8,centres);wq(node+0x10,exits);wq(node+0x18,regions)
    for n,point in enumerate(graph['centres']):wf(centres+n*8,point[0]);wf(centres+n*8+4,point[1])
    for n,point in enumerate(graph['entrances']):wf(exits+n*8,point[0]);wf(exits+n*8+4,point[1]);wi(regions+n*4,graph['regions'][n])
    rsp=stack+0xff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,tile)
    if c['mode'] in ['coords','exit']:
        u.reg_write(UC_X86_REG_RDX,c['index']);u.reg_write(UC_X86_REG_R8,output);u.reg_write(UC_X86_REG_R9,output+4)
        if c['mode']=='exit':wq(rsp+0x28,output+8)
        entry={'coords':0x1404fdb90,'exit':0x1404fdaa0}[c['mode']]
    elif c['mode']=='total':entry=0x1404fdd30
    else:
        for reg,value in zip([UC_X86_REG_XMM1,UC_X86_REG_XMM2],c['point']):u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
        entry={'number':0x1404fdb30,'entrance':0x1404fdc30}[c['mode']]
    try:u.emu_start(entry,stop,count=5000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,point=[rf(output),rf(output+4)],region=si(output+8))
rows=[]
for kind in range(65,121):
    for nodeOrientation,graph in enumerate(graphs[str(kind)]):
        for orientation in range(4):
            c=dict(kind=kind,nodeOrientation=nodeOrientation,orientation=orientation)
            rows.append(run(c|dict(mode='total')))
            for index in range(len(graph['centres'])):rows.append(run(c|dict(mode='coords',index=index)))
            for index in range(len(graph['entrances'])):rows.append(run(c|dict(mode='exit',index=index)))
            for point in [[0,0],[5,0],[10,5],[5,10],[0,5],[5,5],[.0001,5],[9.9999,5],[2,0],[8,10]]:
                for mode in ['number','entrance']:rows.append(run(c|dict(mode=mode,point=point)))
out=root/'backups/animations/native-path-getter-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
