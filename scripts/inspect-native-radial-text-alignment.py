"""Execute original FixAttachedText1f8ba0 and FixAlignment1fd480 unchanged.
GUI scale, positive roundf and model root get/set are captured leaves. The
original CRT SSE sine body executes. Synthetic bubble dimensions and viewport
centers prove alignment/root arithmetic, not font wrapping or original pixels.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
radial,bubble,model,vt,gui=[m.heap+n*0x1000 for n in range(5)]
get_root,set_root=m.stop+0x100,m.stop+0x110
ranges=[(0x1401f8ba0,0x1401f8fd6),(0x1401fd480,0x1401fd5a5),(0x140c7a2b0,0x140c7a9a8)]
def vec(ptr,values):
 for n,value in enumerate(values):m.wf(ptr+4*n,value)
def read(ptr,count):return[m.rf(ptr+4*n)for n in range(count)]
def scalar(reg,value):u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
def hook(u,a,n,_):
 global alignment,result,quaternion
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1400752c0:scalar(UC_X86_REG_XMM0,c['scale']);m.finish()
 elif a==0x140c8f234:
  value=m.xmm(UC_X86_REG_XMM0);assert value>=0
  scalar(UC_X86_REG_XMM0,math.floor(value+.5));m.finish()
 elif a==0x1401fd480:alignment=[m.xmm(UC_X86_REG_XMM1),m.xmm(UC_X86_REG_XMM2)]
 elif a==get_root:vec(z,[0,0,0]);vec(w,[1,0,0,0]);m.finish()
 elif a==set_root:result=read(z,3);quaternion=read(w,4);m.finish()
 elif not any(low<=a<high for low,high in ranges):raise RuntimeError(f'Unexpected native radial text dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for screen,edge,size,scale,slot,hide,center,mode in itertools.product([[800,600],[1424,921]],range(5),[[100,20],[150,48],[300,104],[300,454]],[.75,1,1.5],range(8),[0,1],[0,1],[1,2]):
 origin=[[155,155],[screen[0]-156,screen[1]-156],[screen[0]//2,screen[1]//2],[155,screen[1]-156],[screen[0]-156,155]][edge]
 c=dict(screen=screen,origin=origin,size=size,scale=scale,slot=slot,hide=hide,center=center,mode=mode)
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wi(0x1415d8224,0)
 m.wi(0x14140cd78,hide);m.wi(0x14140cd7c,center);m.wi(0x14128f4ac,mode);m.wq(0x1412df8b0,gui)
 m.wi(gui+0xb8,screen[0]);m.wi(gui+0xbc,screen[1]);m.wi(radial+0x7dc,origin[0]);m.wi(radial+0x7e0,origin[1])
 m.wq(radial+0xf8+slot*8,bubble);m.wf(bubble+0xf8,size[0]);m.wf(bubble+0xfc,size[1]);m.wq(bubble+0x10,model);m.wq(model,vt)
 m.wq(vt+0x148,get_root);m.wq(vt+0x140,set_root)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,radial);u.reg_write(UC_X86_REG_RDX,slot)
 alignment=result=quaternion=None;u.emu_start(0x1401f8ba0,m.stop,count=100000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and alignment is not None and result is not None and quaternion==[1,0,0,0]
 rows.append(dict(input=c,alignment=alignment,root=result))
output=m.root/'backups/animations/native-radial-text-alignment-v1.json'
assert not output.exists(),'Preserve existing original observations'
output.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2))
print(json.dumps(dict(output=str(output),rows=len(rows))))
