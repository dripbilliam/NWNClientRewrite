"""Read-only original emitter radius and plane observations.
Unchanged CalculateRadius, SphereAbovePlane, vector magnitude and complete
BSP collection callback1400dc140 execute in Unicorn. Synthetic transform/
target/chunk views, CRT sqrt and unrelated mesh processing are explicit lower
boundaries. Empty unrelated BSP lists and bounded preallocated emitter buckets
avoid allocation. This is not BSP traversal, camera construction or renderer replay.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,source,model,wind,target,vt,point,planes,node,nd,items,bucket,particles,children=[m.heap+n*0x1000 for n in range(14)]
transform_stub,target_stub,view_stub=[m.stop+n*0x10 for n in [1,2,3]]
ranges=[(0x140061710,0x1400619ee),(0x14022e360,0x14022e392),(0x1402303d0,0x140230415),(0x1400dc140,0x1400dc8f4),(0x1400cafe0,0x1400cafe8),(0x140092000,0x140092005)]
field_offsets={'mass':0xb0,'lifeexp':0xac,'velocity':0xdc,'randvel':0xc0,'sizestart':0xc4,'sizeend':0xc8,'sizemid':0x228,'sizestart_y':0xcc,'sizeend_y':0xd0,'sizemid_y':0x22c}
def vec(ptr,values):
 for j,v in enumerate(values):m.wf(ptr+j*4,v)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==transform_stub:vec(y,c.get('origin',[0,0,0]));vec(z,[1,0,0,0]);m.finish()
 elif a==target_stub:vec(y,c['target']);m.finish(y)
 elif a==view_stub:m.finish(x if c.get('chunk_views',[1]*len(c.get('chunks',[])))[int((x-particles)//0x100)] else 0)
 elif a==0x140c7d6d8:
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif a==0x1400dc900:m.finish() # Explicit unrelated mesh-processing boundary.
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected emitter admission dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset(case):
 global c
 c=case;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter,vt);m.wq(vt+0x18,transform_stub);m.wq(vt+0xc0,target_stub);m.wq(vt+8,view_stub)
 for name,off in field_offsets.items():m.wf(emitter+off,c.get(name,0))
 m.wq(0x14140b0c8,bucket);m.wi(0x14140b0d0,0);m.wi(0x14140b0d4,128);m.wi(0x14140afcc,0)
def call(address,args=(),floats=()):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 for reg,value in floats:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,address=hex(address),rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
def radius(case):
 reset(case)
 if 'source_flags' in c:m.wq(emitter+0x50,source);m.wq(source+0x68,model);u.mem_write(model+0x92,bytes([c['source_flags']]))
 if 'wind' in c:m.wq(emitter+0x1f8,wind);vec(wind+0x20,c['wind'])
 if 'target' in c:m.wq(emitter+0x1c0,target);m.wq(target,vt)
 chunks=c.get('chunks',[]);m.wq(emitter+0x188,items);m.wi(emitter+0x190,len(chunks))
 for j,chunk in enumerate(chunks):
  ptr=particles+j*0x100;child=children+j*0x200;m.wq(items+j*8,ptr);m.wq(ptr,vt)
  if chunk is not None:m.wq(ptr+0x78,child);vec(child+0xa8,chunk[:3]);m.wf(child+0x178,chunk[3])
 call(0x140061710,[emitter]);return dict(input=c,radius=m.rf(emitter+0x20c),radius_word=bytes(u.mem_read(emitter+0x20c,4)).hex(),acceleration=m.rf(emitter+0x210))
def sphere(case):
 reset(case);vec(point,c['point']);vec(planes,c['plane']);call(0x14022e360,[point,0,planes],[(UC_X86_REG_XMM1,c['radius'])]);return dict(input=c,result=m.xmm(UC_X86_REG_XMM0),word=struct.pack('<f',m.xmm(UC_X86_REG_XMM0)).hex())
def admission(case):
 reset(case);m.wq(0x14140ac50,0) # currentscene from callback1400dc181.
 m.wq(node+0x70,nd);m.wq(nd+0x30,items);m.wi(nd+0x38,1);m.wq(items,emitter)
 m.wq(point,planes);m.wi(point+8,len(c['planes']));m.wi(0x14140afcc,c['start_plane']);m.wf(emitter+0x20c,c['radius'])
 for j,plane in enumerate(c['planes']):vec(planes+j*16,plane)
 call(0x1400dc140,[node,0,point]);count=m.si(0x14140b0d0)
 return dict(input=c,admitted=count==1,identity_valid=count==0 or m.q(bucket)==emitter,last_plane=m.si(0x14140afcc))
if __name__=='__main__':
 base=dict(mass=0,lifeexp=2,velocity=1,randvel=.25,sizestart=1,sizeend=2,sizemid=.5,sizestart_y=0,sizeend_y=0,sizemid_y=0)
 rows=[radius(base|dict(mass=mass,lifeexp=life,wind=wind,sizemid=mid,sizemid_y=y))for mass,life,wind,mid,y in itertools.product([0,.1,-2],[0,.25,3,-1],[[0,0,0],[.5,-1,2]],[0,4],[0,3])]
 rows +=[radius(base|dict(source_flags=flags,target=[9,8,7],chunks=[[100,0,0,5]]))for flags in [0,1,2,4,8,255]]
 rows +=[radius(base|dict(origin=[1,2,3],target=[5,7,9])),radius(base|dict(chunks=[[3,4,0,2],None,[100,0,0,5]])),radius(base|dict(chunks=[[3,4,0,2],[100,0,0,5]],chunk_views=[1,0]))]
 spheres=[sphere(dict(point=p,plane=plane,radius=r))for p,plane,r in itertools.product([[0,0,0],[1,2,3],[-5,.001,20]],[[1,0,0,-1],[0,1,0,-2],[0,0,1,-3],[.26726124,.53452248,.80178373,-4]],[0,1,2.5,1000])]
 admissions=[admission(dict(origin=p,radius=r,planes=ps,start_plane=start))for p,r,ps in itertools.product([[0,0,0],[1,2,3],[-5,.001,20]],[0,1,2.5,1000],[[],[[1,0,0,-1]],[[1,0,0,-1],[0,1,0,-2],[0,0,1,-3]]])for start in range(max(1,len(ps)))]
 out=m.root/'backups/animations/native-emitter-admission-observations-v2.json'
 assert not out.exists(),'Preserve existing observations'
 out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,radii=rows,spheres=spheres,admissions=admissions),indent=2));print(json.dumps(dict(output=str(out),radii=len(rows),spheres=len(spheres),admissions=len(admissions))))
