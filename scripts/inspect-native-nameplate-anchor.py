"""Execute unchanged original nameplate height803347..80337e and world-anchor
766ea0 instructions. Model-hook result, visual LerpFloat samples, camera position,
camera projection and final GUI placement are captured providers. Native vector
distance arithmetic executes; sqrtf is a captured finite math boundary. No game
process, private profile, GPU or network. This does not establish model-hook
lookup, visual-curve clocks, camera projection pixels, overlap or viewport policy.
"""
import importlib.util,itertools,json,re,struct,sys,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,popup,app,camera,vtable,tree,nil=[m.heap+n*0x1000 for n in range(7)]
camera_position,camera_projection=m.stop+0x100,m.stop+0x200

def vector(p):return [m.rf(p+i*4) for i in range(3)]
def put_vector(p,value):
 for i,v in enumerate(value):m.wf(p+i*4,v)
def floating(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,_):
 global samples,captured,projected
 if a in [m.stop,0x14080336f,0x14080337e]:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1406abea0:m.finish(app);return
 if a==0x1402e9a80:
  index=len(samples);assert index<5
  samples.append(x);floating([case['translation'][2],case['translation'][1],case['translation'][0],case['scale'],case['translation'][2]][index]);return
 if a==camera_position:put_vector(y,case['camera']);m.finish(y);return
 if a==camera_projection:
  projected=vector(z);put_vector(y,case['screen']+[0]);m.finish(y);return
 if a==0x1406e9820:captured=vector(y);m.finish();return
 if a==0x140c7d6d8:floating(math.sqrt(m.xmm(UC_X86_REG_XMM0)));return
 if a==0x140c10410:m.finish();return
 if not (0x140803347<=a<0x14080337e or 0x140766ea0<=a<=0x140767237 or 0x1402303d0<=a<=0x14023040c):raise AssertionError(f'Uncaptured anchor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset():
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);return rsp
heights=[]
for found,head in itertools.product([False,True],[0,0.25,1,1.7,2.4,4,20]):
 reset();u.reg_write(UC_X86_REG_RBX,actor);u.reg_write(UC_X86_REG_RBP,m.stack+0x10000);u.reg_write(UC_X86_REG_EAX,int(found));m.wf(m.stack+0x10000-0x29,head)
 u.emu_start(0x140803347,m.stop,count=1000)
 assert u.reg_read(UC_X86_REG_RIP) in [0x14080336f,0x14080337e]
 heights.append(dict(found=found,head=head,height=m.rf(actor+0xc0)))
rows=[]
for position,cam,height,screen in itertools.product([[0,0,0],[11,-5,2]],[[0,3,8],[100,25,50],[0,2,0]],[0,2.1,8],[[-1.8,-0.8],[0.49,0.5],[300.75,500.25]]):
 case=dict(position=position,camera=cam,height=height,screen=screen,translation=[0,0,0],scale=1)
 reset();samples=[];captured=None;projected=None
 m.wq(actor+0xb8,popup);m.wf(popup+300,1);m.wq(actor+0x138,tree);m.wq(tree+8,nil);u.mem_write(nil+0x19,b'\1')
 m.wq(0x1412df970,app);m.wq(app+0xe8,camera);m.wq(camera,vtable);m.wq(vtable+0x40,camera_position);m.wq(vtable+0x50,camera_projection)
 put_vector(actor+0x38,position);m.wf(actor+0x44,0);m.wf(actor+0x48,1);m.wf(actor+0xc0,height)
 u.reg_write(UC_X86_REG_RCX,actor);u.emu_start(0x140766ea0,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and captured is not None and projected is not None
 assert [p-samples[0] for p in samples]==[0,-0x40,-0x80,-0x200,0]
 rows.append(dict(input=case,projected=projected,screen=captured))
name=next((a.split('=',1)[1] for a in sys.argv[1:] if a.startswith('--report=')),'native-nameplate-anchor-v1.json')
assert re.fullmatch(r'native-nameplate-anchor-[a-z0-9-]+\.json',name)
out=m.root/'backups/animations'/name;assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,heights=heights,rows=rows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),heights=len(heights),anchors=len(rows),target=m.digest)))
