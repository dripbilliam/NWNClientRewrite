"""Complete Gob::GetPartPosition14008f4d0 and SetPartPosition1400950b0,
with actual quaternion inverse-sign/product/vector rotation/normalization,
and local-copy owners GetPartPositionLocal14008f470/Set140095050.
FindNode and the node's global-pose virtual are explicit synthetic providers.
Does not prove the lower scene hierarchy's pose calculation or animation.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
gob,node,vt,name,position,quaternion=[m.heap+n*0x1000 for n in range(6)]
ranges=[(0x14008f470,0x14008f4cc),(0x140095050,0x1400950a9),(0x14008f4d0,0x14008f55a),(0x1400950b0,0x1400951e3),(0x14022b0c0,0x14022b0e6),(0x14022ab00,0x14022ac34),(0x14022ae90,0x14022b0bb),(0x140230710,0x1402307b1)]
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x10:calls.append(['find','root']);m.finish(node if c['found']else 0)
 elif a==m.stop+0x20:
  calls.append(['globalPose',read(node+0x10),read(node+0x1c,4)])
  vector(y,c['basePosition']);vector(z,c['baseQuaternion']);m.finish(1)
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected node pose dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(gob,vt);m.wq(node,vt);m.wq(vt+0x230,m.stop+0x10);m.wq(vt+0x18,m.stop+0x20);u.mem_write(name,b'root\0')
 vector(node+0x10,[7.25,-8.5,9.75]);vector(node+0x1c,[.1,.2,.3,.4]);m.wi(node+0x60,7)
 vector(position,c['position']);vector(quaternion,c['quaternion'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,gob);u.reg_write(UC_X86_REG_RDX,name);u.reg_write(UC_X86_REG_R8,position if c['mode'].startswith('set')or c['outPosition']else 0);u.reg_write(UC_X86_REG_R9,quaternion if c['mode'].startswith('set')or c['outQuaternion']else 0)
 address={'set':0x1400950b0,'get':0x14008f4d0,'setLocal':0x140095050,'getLocal':0x14008f470}[c['mode']]
 try:u.emu_start(address,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,nodePosition=read(node+0x10),nodeQuaternion=read(node+0x1c,4),dirty=m.si(node+0x60),position=read(position),quaternion=read(quaternion,4))
quats=[[1,0,0,0],[.5,.5,.5,.5],[math.cos(.3),0,math.sin(.3),0],[0,0,0,0],[-2,.1,3,-.4],[1,.01,.02,.03]]
rows=[run(dict(mode='set',found=found,basePosition=basePosition,baseQuaternion=baseQuaternion,position=pos,quaternion=q))for found,basePosition,baseQuaternion,pos,q in itertools.product([0,1],[[0,0,0],[3.25,-4.75,5.5]],quats[:3],[[0,0,0],[1.234,-6.789,.321]],quats)]
rows.extend(run(dict(mode='get',found=found,basePosition=[3.25,-4.75,5.5],baseQuaternion=q,position=[.1,.2,.3],quaternion=[.4,.5,.6,.7],outPosition=outP,outQuaternion=outQ))for found,q,outP,outQ in itertools.product([0,1],quats,[0,1],[0,1]))
rows.extend(run(dict(mode=mode,found=found,basePosition=[3.25,-4.75,5.5],baseQuaternion=[1,0,0,0],position=[.1,.2,.3],quaternion=q,outPosition=outP,outQuaternion=outQ))for mode,found,q,outP,outQ in itertools.product(['setLocal','getLocal'],[0,1],quats,[0,1],[0,1]))
out=m.root/'backups/animations/native-visual-node-pose-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
