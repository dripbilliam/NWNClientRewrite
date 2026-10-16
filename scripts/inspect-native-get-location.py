"""Original GetLocation wrapper and complete raw GetScriptLocation leaf.
VM pop/push and registry lookup are captured. Raw FLOAT vectors and area-ID
copy execute, including absent/nonworld defaults. No proprietary bytes emitted.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,app=m.heap,m.heap+0x1000
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140286160:m.wi(y,99);m.finish(c.get('pop',1))
 elif a==0x14055b850:m.finish(app)
 elif a==0x140296470:m.wq(z,actor if c.get('exists',True)else 0);m.finish(c.get('lookup',0))
 elif a==0x140286330:output=dict(position=list(struct.unpack('<3f',u.mem_read(z,12))),nativeOrientation=list(struct.unpack('<3f',u.mem_read(z+12,12))),areaId=m.si(z+24)&0xffffffff);m.finish(c.get('push',1))
 elif not any(lo<=a<hi for lo,hi in [(0x14052b130,0x14052b1fa),(0x140495f30,0x140495f7c)]):raise RuntimeError(f'Unexpected GetLocation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output
 c=case;output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app)
 u.mem_write(actor+12,bytes([c.get('type',5)]));m.wi(actor+0xa0,c.get('areaId',0x80000001));u.mem_write(actor+0xa4,struct.pack('<6f',*c.get('position',[1,2,3]),*c.get('orientation',[2,-3,4])))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(0x14052b130,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;return dict(case=c,result=result,output=output)
rows=[run(dict(type=typ,exists=exists,lookup=lookup,position=point,orientation=facing))for typ,exists,lookup,point,facing in itertools.product([0,4,5,6,9,10,14,255],[False,True],[0,1],[[0,0,0],[1,2,3],[-10,.125,400]],[[0,0,0],[1,0,0],[2,-3,4],[-1,-2,-3]])]
rows.extend([run(dict(pop=0)),run(dict(push=0)),run(dict(areaId=0x7f000000))])
out=m.root/'backups/animations/native-get-location-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
