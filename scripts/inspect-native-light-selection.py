"""Read-only complete PrioritizeLights07ff60 and GetLightAdjustedRadius07f480.
Original magnitude/sqrt execute for finite cases. Candidate construction,
virtual sorting/shadow prioritization and shader configuration are explicit
boundaries. No scene visibility, fade history, final draw or live parity claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager,part,node,table,items,focus=[m.heap+n*0x1000 for n in range(1,7)]
def finish_float(v):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish()
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a in [0x14007fe40,0x14007ff40,0x1400801b0]:m.finish();return
 if a==0x1400bec20:m.finish(int(case['colorAdjusted']));return
 if a==0x1400bec10:finish_float(case['radiusScale']);return
 if not any(lo<=a<hi for lo,hi in [(0x14007ff60,0x1400801a5),(0x14007f480,0x14007f502),(0x1402303d0,0x14023040d),(0x140c7d6d8,0x140c7d783)]):raise RuntimeError(f'Unexpected light dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case
 case=c;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 m.wq(manager,table);m.wq(table+0x58,0x14007fe40);m.wq(table+0x48,0x14007ff40);m.wq(table+0x50,0x1400801b0);m.wq(manager+0x40,items);m.wi(manager+0x48,1);m.wq(items,part);m.wq(part+8,node)
 for offset,value in [(0x74,c['radius']),(0xa8,c['multiplier'])]:m.wf(part+offset,value)
 for i,value in enumerate(c['color']):m.wf(part+0x68+i*4,value)
 for i,value in enumerate(c['position']):m.wf(part+0xb0+i*4,value)
 for i,value in enumerate(c['focus']):m.wf(focus+i*4,value)
 m.wi(part+0x90,c['priorityOverride']);m.wi(node+0xf8,c['priority']);m.wi(part+0x8c,c['dynamic']);m.wi(node+0x110,c['fading']);m.wq(part+0x50,0x12345678);m.wq(0x141301720,0x12345678 if c['onlyOwner']else 0)
 def enter(address,rcx,rdx=0):
  rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
  for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,rcx),(UC_X86_REG_RDX,rdx)]:u.reg_write(reg,value)
  u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 enter(0x14007ff60,manager,focus);distance=m.rf(part+0x9c);priority=m.rf(part+0xa0)
 enter(0x14007f480,part);radius=m.xmm(UC_X86_REG_XMM0)
 return dict(case=c,distance=distance,priority=priority,radius=radius)
rows=[]
for color,radius,multiplier,dynamic,fading,override,only,adjusted in itertools.product([[.2,.4,.8],[2,-3,1],[0,0,0]],[0,10,1000],[0,.5,2],[0,1],[0,1],[0,11],[False,True],[False,True]):
 rows.append(run(dict(color=color,radius=radius,multiplier=multiplier,dynamic=dynamic,fading=fading,priorityOverride=override,priority=4,onlyOwner=only,position=[4.25,-3,2],focus=[1,.5,-.25],colorAdjusted=adjusted,radiusScale=1.25)))
out=m.root/'backups/animations/native-light-selection-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
