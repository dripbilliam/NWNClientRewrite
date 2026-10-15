"""Untouched trigger facing and cast-round owners from the verified PE.
Captured boundaries: area lookup/height, linked-list storage and allocation.
The original polygon loop, round arithmetic, inline action construction and
spell-removal traversal execute. No spell impact, script or network claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
obj,points,out,area,outer,inner,newAction=[m.heap+n*0x1000 for n in range(1,8)]
ranges=[(0x140501780,0x140501913),(0x14037a000,0x14037a133),(0x140378f80,0x140379045)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
    if a==0x140494e80:calls.append(['area']);finish(area)
    elif a==0x14036a210:
        calls.append(['height',*struct.unpack('<3f',u.mem_read(y,12))]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['height']),'little'));finish()
    elif a==0x1401692a0:
        node=nodes.pop(0);wq(inner,nodes[0] if nodes else 0);calls.append(['remove-head',names[node]]);finish(node+0x100)
    elif a==0x140c10360:calls.append(['free',names.get(x,'new')]);finish()
    elif a==0x140c10324:u.mem_write(newAction,bytes([0xa5])*0x28);finish(newAction)
    elif a==0x140374280:
        calls.append(['add',si(y),int.from_bytes(u.mem_read(y+4,2),'little'),si(y+8),si(y+12),u.mem_read(y+16,1)[0],*[si(y+off)&0xffffffff for off in [20,24,28,32]],int.from_bytes(u.mem_read(y+36,2),'little')]);finish()
    elif a==0x1401690b0:finish(y+0x100)
    elif a==0x140169110:
        node=q(y);index=nodes.index(node);wq(y,nodes[index+1] if index+1<len(nodes) else 0);finish()
    elif a==0x1401691f0:nodes.remove(y);calls.append(['remove',names[y]]);finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured casting support dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,nodes,names
    c=case;calls=[];nodes=[];names={};u.mem_write(m.heap,bytes(0x100000))
    mode=c['mode'];rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if mode=='trigger':
        start=0x140501780;wq(obj+0x3b0,points);wi(obj+0x3a8,len(c['vertices']))
        for i,p in enumerate(c['vertices']):u.mem_write(points+i*12,struct.pack('<3f',*p))
        for off,value in zip([0x414,0x418,0x41c,0x420],c['bounds']):wf(obj+off,value)
        args=[obj,out]
    else:
        start=0x14037a000 if mode=='start' else 0x140378f80;wq(obj+0x2f70,outer);wq(outer,inner)
        for i,action in enumerate(c['actions']):
            node=m.heap+0x10000+i*0x1000;nodes.append(node);names[node]=names[node+0x100]=i;u.mem_write(node+0x110,bytes([action&255]))
        wq(inner,nodes[0] if nodes else 0)
        for off,value in [(0x2f04,0),(0x2f08,0),(0x2f0c,777),(0x2f10,333),(0x2f14,c.get('overlap',0)),(0x2f18,c.get('bleed',0)),(0x2f1c,1),(0x2f20,999),(0x2f24,123)]:wi(obj+off,value)
        args=[obj,c.get('length',0)&0xffffffff]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX],args):u.reg_write(reg,value)
    u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,point=list(struct.unpack('<3f',u.mem_read(out,12))) if mode=='trigger' else None,
        bounds=[rf(obj+off) for off in [0x414,0x418,0x41c,0x420]] if mode=='trigger' else None,
        round=[si(obj+off)&0xffffffff for off in range(0x2f04,0x2f28,4)] if mode!='trigger' else None,
        remaining=[names[node] for node in nodes])
rows=[]
for vertices,bounds,height in itertools.product([[[0,0,0]],[[3,7,99]],[[0,0,0],[8,0,0],[8,12,0],[0,12,0]],[[9,7,0],[-3,-8,0],[4,2,0]],[[100000,100000,0],[100000.01,100000.02,0]]],[[0,0,0,0],[-20,40,-60,80],[3,3,7,7]],[0,123.5]):rows.append(run(dict(mode='trigger',vertices=vertices,bounds=bounds,height=height)))
for length,overlap,bleed,actions in itertools.product([0,3000,6000,0xffffffff],[-1,0,1000,7000],[-20,0,900,1500],[[],[1,2,8]]):rows.append(run(dict(mode='start',length=length,overlap=overlap,bleed=bleed,actions=actions)))
for actions in [[],[1],[2],[2,2],[1,2,8,2,2,3,2],[258,1,2,8],[3,8,1]]:rows.append(run(dict(mode='remove',actions=actions)))
out=m.root/'backups/animations/native-casting-support-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
