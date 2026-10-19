"""Full original SetEmitterTarget0643c0 plus Lightning Initialize061d30.
Physical child order/reference casts, base init, listener registration/removal,
world pose/position and Lightning cast are captured lower boundaries. Original
distance helper executes. No full Gob construction/event scheduling/render proof.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,source,target,evt,svt,tvt,parts=[m.heap+n*0x1000 for n in range(7)]
def vector(ptr,v):
 for i,x in enumerate(v):m.wf(ptr+i*4,x)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def text(ptr):return bytes(u.mem_read(ptr,100)).split(b'\0')[0].decode()if ptr else ''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140061d80:calls.append(['base']);m.finish()
 elif a==m.stop+0x10:
  index=(x-(m.heap+0x10000))//0x100;calls.append(['reference',index]);m.finish(x if c['references'][index]else 0)
 elif a==m.stop+0x20:calls.append(['pose']);vector(y,c['globalPosition']);vector(z,[1,0,0,0]);m.finish()
 elif a==m.stop+0x30:calls.append(['position']);vector(y,c['targetPosition']);m.finish(y)
 elif a==m.stop+0x40:calls.append(['lightning']);m.finish(emitter if c['lightning']else 0)
 elif a==m.stop+0x50:calls.append(['remove',y]);m.finish()
 elif a==m.stop+0x60:calls.append(['listen',hex(y),text(z)]);m.finish(99)
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in[(0x1400643c0,0x140064597),(0x140061d30,0x140061d79),(0x1402303d0,0x14023040d)]):raise RuntimeError(f'Uncaptured emitter target dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x30000));u.mem_write(m.stack,bytes(0x20000));m.wq(emitter,evt);m.wq(source,svt);m.wq(target,tvt);m.wq(emitter+0x50,source);m.wq(emitter+0x38,parts);m.wi(emitter+0x40,len(c['references']));m.wq(emitter+0x128,88);m.wf(emitter+0xac,3);m.wi(emitter+0x1cc,0x12340001);vector(emitter+0x1e0,c['cachedPosition']);vector(emitter+0x248,[-7,-8,-9]);vector(emitter+0x254,[-1,-2,-3]);m.wf(emitter+0x20c,-1)
 for off,fn in[(0x18,m.stop+0x20),(0x108,m.stop+0x40)]:m.wq(evt+off,fn)
 m.wq(svt+0x290,m.stop+0x50);m.wq(svt+0x50,m.stop+0x60);m.wq(tvt+0xc0,m.stop+0x30)
 for i in range(len(c['references'])):part=m.heap+0x10000+i*0x100;m.wq(parts+i*8,part);m.wq(part,evt+0x500);m.wq(evt+0x500+0x70,m.stop+0x10);m.wq(part+0x68,target)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter if c['mode']=='initialize'else source);u.reg_write(UC_X86_REG_RDX,0);u.reg_write(UC_X86_REG_R8,emitter);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 u.emu_start(0x140061d30 if c['mode']=='initialize'else 0x1400643c0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,target=bool(m.q(emitter+0x1c0)),distance=m.rf(emitter+0x20c),previousDirection=read(emitter+0x248),previousPosition=read(emitter+0x254),life=m.rf(emitter+0xac),ageMode=int.from_bytes(u.mem_read(emitter+0x1cc,2),'little'),listener=m.q(emitter+0x128))
rows=[run(dict(mode='target',references=refs,lightning=lightning,cachedPosition=cached,globalPosition=world,targetPosition=targetpos))for refs,lightning,cached,world,targetpos in itertools.product([[],[0],[1],[0,1,1],[1,1,0],[0,0,0]],[0,1],[[0,0,0],[1,2,3]],[[-.5,.25,4],[0,0,0]],[[8,5,4],[0,0,0]])]
rows.append(run(dict(mode='initialize',references=[],lightning=1,cachedPosition=[1,2,3],globalPosition=[1,2,3],targetPosition=[8,5,4])))
out=m.root/'backups/animations/native-emitter-target-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
