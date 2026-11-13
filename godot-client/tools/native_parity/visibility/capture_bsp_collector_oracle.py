"""Original NWN InitBSP/grid/volume/ordered/fit/camera/DeltaT instructions.
Only heap allocation/reallocation/free, API draw setup, bin creation and callback
collection are captured. No renderer, original process, server or native build.
Camera tanf explicitly selects the original SSE branch; AVX/FMA is not claimed.
"""
import argparse, hashlib, importlib, json, math, struct, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
SHA='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if m.digest!=SHA:raise RuntimeError('Original identity differs')
SCENE,CAMERA,TABLE,PLANES,POSITION,PARTS=[m.heap+n*0x1000 for n in range(1,7)]
CALLBACK,BINS=[m.stop+n*0x100 for n in [1,2]]
RANGES=[(0x1400ca3b0,0x1400caea1),(0x1400d63d0,0x1400d69e6),(0x140229420,0x14022947b),
 (0x1400da330,0x1400da3c6),(0x140229c60,0x140229caf),(0x140229cb0,0x140229dbe),
 (0x140229dc0,0x14022a224),(0x140229690,0x14022970e),(0x1400dd340,0x1400dd72f),
 (0x140047300,0x14004730b),(0x14004bfe0,0x14004c0bb),(0x140057330,0x14005733c),(0x1400576b0,0x14005777f),(0x140c7ed44,0x140c7edbf),
 (0x14005a971,0x14005aee5),(0x14022c210,0x14022c218),(0x14022d960,0x14022da0a),
 (0x140230920,0x1402309f4),(0x14022ae90,0x14022b0ba),(0x140c7d6d8,0x140c7d782),
 (0x140c7d790,0x140c7ddf4),(0x1406db9b7,0x1406db9dd)]
next_alloc=0;allocations={};callbacks=[];phase='';snapshot=0;visited=set()
def fw(v):return struct.unpack('<I',struct.pack('<f',v))[0]
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def floats(a,values):u.mem_write(a,struct.pack('<'+'f'*len(values),*values))
def words(a,n):return list(struct.unpack('<'+'I'*n,u.mem_read(a,n*4)))
def allocate(size,old=0):
 global next_alloc
 if size<0 or size>0x80000:raise RuntimeError('Allocation bound')
 ptr=m.heap+next_alloc;next_alloc+=(size+15)&~15
 if next_alloc>0xf0000:raise RuntimeError('Total heap bound')
 u.mem_write(ptr,bytes(size));allocations[ptr]=size
 if old:u.mem_write(ptr,bytes(u.mem_read(old,min(size,allocations[old]))))
 return ptr
def hook(_u,address,_size,_data):
 global callbacks
 visited.add(address)
 if address==m.stop or phase=='camera' and address==0x14005aee5 or phase=='delta' and address==0x1406db9dd:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif address in [0x140c4f038,0x140ca9ba0]:m.finish(allocate(y,x))
 elif address==0x140c10370:m.finish()
 elif address in [0x140c417f0,0x140c417f8]:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x)
 elif address in [0x1400bf1e0,0x1400bf1f0,0x1400bf370,BINS]:m.finish()
 elif address==0x140597050:
  if phase!='delta':raise AssertionError('Unexpected clock request')
  m.finish(snapshot)
 elif address==CALLBACK:
  count=m.si(z+8);callbacks.append(dict(node=x,planes=[words(m.q(z)+i*16,4) for i in range(count)]));m.finish()
 elif not any(a<=address<=b for a,b in RANGES):raise RuntimeError(f'Uncaptured BSP dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
GPRS=[UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_R10,UC_X86_REG_R11,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]
XMMS=[UC_X86_REG_XMM0,UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3,UC_X86_REG_XMM4,UC_X86_REG_XMM5,UC_X86_REG_XMM6,UC_X86_REG_XMM7,UC_X86_REG_XMM8,UC_X86_REG_XMM9,UC_X86_REG_XMM10,UC_X86_REG_XMM11,UC_X86_REG_XMM12,UC_X86_REG_XMM13,UC_X86_REG_XMM14,UC_X86_REG_XMM15]
def registers():
 u.mem_write(m.stack,bytes(0x20000))
 for reg in GPRS+XMMS:u.reg_write(reg,0)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 return sp
def call(address,rcx=0,rdx=0,r8=0,r9=0):
 sp=registers()
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[rcx,rdx,r8,r9]):u.reg_write(reg,value)
 return sp
def execute(address,count=5000000):
 u.emu_start(address,m.stop,count=count)
 if u.reg_read(UC_X86_REG_RIP) not in [m.stop,0x14005aee5,0x1406db9dd]:raise RuntimeError('Instruction bound/no return')
def reset():
 global next_alloc,allocations,callbacks,visited
 next_alloc=0x20000;allocations={};callbacks=[];visited=set();u.mem_write(m.heap,bytes(0x100000))
 u.mem_write(0x14141e310,b'\0\0');m.wi(0x1415d8224,0)
def native_tree():
 addresses=[]
 def visit(a):
  if not a:return
  addresses.append(a);visit(m.q(a+0x10));visit(m.q(a+0x18))
 visit(m.q(SCENE+0x188));lookup={a:i for i,a in enumerate(addresses)};rows=[]
 for a in addresses:
  count=m.si(a+0x68)
  rows.append(dict(plane=words(a,4),leaf=m.si(a+0x20),negative=lookup.get(m.q(a+0x10),-1),positive=lookup.get(m.q(a+0x18),-1),low=words(a+0x24,3),high=words(a+0x30,3),vertices=[words(m.q(a+0x60)+i*12,3) for i in range(count)]))
 return rows,lookup
def camera_planes(camera):
 global phase
 tangent=None
 if camera['angle']>0:
  phase='math';sp=call(0x14022c210);u.reg_write(UC_X86_REG_XMM0,fw(f(f(camera['angle'])*.5)));execute(0x14022c210,1000)
  angle=u.reg_read(UC_X86_REG_XMM0)&0xffffffff;sp=call(0x140c7d790);u.reg_write(UC_X86_REG_XMM0,angle);execute(0x140c7d790,15000);tangent=u.reg_read(UC_X86_REG_XMM0)&0xffffffff
 phase='camera';call(0x14005a971);u.reg_write(UC_X86_REG_RBX,CAMERA);u.reg_write(UC_X86_REG_RBP,m.stack+0x18000);u.reg_write(UC_X86_REG_RSP,m.stack+0x17000);u.reg_write(UC_X86_REG_XMM7,fw(camera['aspect']))
 m.wq(CAMERA+0x4f0,PLANES);m.wi(CAMERA+0x4f8,6);floats(CAMERA+0xb0,camera['position']);floats(CAMERA+0xbc,camera['quaternion_wxyz'])
 for key,offset in [('angle',0x4c8),('near',0x4d0),('far',0x4d4),('orthographic_scale',0x4cc)]:m.wf(CAMERA+offset,camera.get(key,0))
 execute(0x14005a971,50000)
 return dict(camera=camera,half_tangent_word=tangent,plane_words=[words(PLANES+i*16,4) for i in range(6)])
def build_case(width,height,margin,cell):
 global phase,callbacks
 reset();phase='build';sp=call(0x1400ca3b0,SCENE,width,height,margin);m.wq(SCENE,TABLE);m.wq(TABLE+0x260,BINS);u.mem_write(sp+0x28,b'\1');m.wf(sp+0x30,cell);execute(0x1400ca3b0)
 rows,lookup=native_tree();bindings=[]
 for y in range(height):
  for x in range(width):
   token=y*width+x;point=[f(x*cell+cell*.5),f(y*cell+cell*.5),0];tile=m.heap+0x8000+token*0x100
   phase='bind';floats(POSITION,point);call(0x1400dd340,SCENE,tile,PARTS,POSITION);execute(0x1400dd340,10000)
   call(0x140229690,m.q(SCENE+0x188),POSITION);u.reg_write(UC_X86_REG_XMM2,0);execute(0x140229690,10000)
   bindings.append(dict(tile=token,position=point,node=lookup[u.reg_read(UC_X86_REG_RAX)]))
 aliases=[]
 if width*height>1:
  point=[f((width-.5)*cell),f((height-.5)*cell),0]
  phase='bind';floats(POSITION,point);call(0x1400dd340,SCENE,m.heap+0x8000,PARTS,POSITION);execute(0x1400dd340,10000)
  aliases.append(dict(tile=0,position=point))
 fits=[]
 for point in [[0,0,0],[cell,cell,0],[-margin*cell,-margin*cell,-30],[(width+margin)*cell,(height+margin)*cell,0],[(width+margin)*cell+.125,0,0],[0,0,-30.125],[0,0,(max(width+margin*2,height+margin*2)+1)*10]]:
  phase='fit';floats(POSITION,point);call(0x140229690,m.q(SCENE+0x188),POSITION);u.reg_write(UC_X86_REG_XMM2,0);execute(0x140229690,10000)
  fits.append(dict(position=point,node=lookup[u.reg_read(UC_X86_REG_RAX)]))
 cameras=[dict(position=[width*cell*.5,-20,20],quaternion_wxyz=[1,0,0,0],angle=45,aspect=f(16/9),near=.1,far=200),dict(position=[5,5,20],quaternion_wxyz=[f(math.sqrt(.5)),f(math.sqrt(.5)),0,0],angle=90,aspect=f(4/3),near=.5,far=100),dict(position=[-2,3,7],quaternion_wxyz=[1,.25,.5,.75],angle=0,aspect=2,near=.1,far=80,orthographic_scale=15)]
 camera_rows=[camera_planes(c) for c in cameras];collect_rows=[]
 raw=[([],[-20,5,0]),([[1,0,0,-cell]],[0,0,0]),([[-1,0,0,cell],[1,0,0,-2*cell]],[3*cell,4,5]),([[0,0,1,30]],[0,0,-30])]
 for row in camera_rows:raw.append(([list(struct.unpack('<4f',struct.pack('<4I',*w))) for w in row['plane_words']],row['camera']['position']))
 for planes,camera in raw:
  phase='collect';callbacks=[];plane_ptr=m.heap+0x18000;floats(POSITION,camera);m.wq(PLANES,plane_ptr);m.wi(PLANES+8,len(planes));m.wi(PLANES+12,len(planes))
  for i,p in enumerate(planes):floats(plane_ptr+i*16,p)
  sp=call(0x140229dc0,m.q(SCENE+0x188),POSITION,PLANES,CALLBACK);m.wq(sp+0x28,SCENE);execute(0x140229dc0)
  tokens={m.heap+0x8000+t*0x100:t for t in range(width*height)};tile_list=[]
  for c in callbacks:
   pointer=m.q(m.q(c['node']+0x70)+0x98)
   if pointer:tile_list.append(tokens[pointer])
  collect_rows.append(dict(camera=camera,planes=planes,nodes=[lookup[c['node']] for c in callbacks],plane_counts=[len(c['planes']) for c in callbacks],tiles=tile_list))
 return dict(input=dict(width=width,height=height,margin=margin,cell=cell),tree=rows,bindings=bindings,aliases=aliases,fits=fits,cameras=camera_rows,collections=collect_rows,heap_bytes=next_alloc)
def delta_case(value):
 global phase,snapshot
 phase='delta';snapshot=value;call(0x1406db9b7);u.reg_write(UC_X86_REG_RSI,SCENE);m.wq(SCENE+0x50,CAMERA);execute(0x1406db9b7,1000)
 return dict(hi=value>>32,lo=value&0xffffffff,delta_t_word=words(0x14128e030,1)[0])
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);args=p.parse_args();out=Path(args.output).resolve();boundary=(ROOT/'godot-client/.cache/native-presentation-parity/loading-agent').resolve()
 if not out.is_relative_to(boundary) or out.exists():raise RuntimeError('Fresh owned output required')
 cases=[build_case(*v) for v in [(1,1,0,10),(3,2,0,10),(2,3,1,5),(3,3,5,10),(8,5,5,10)]]
 deltas=[delta_case(v) for v in [0,1,999,1000,16666,500000,0x7fffffff,0x80000000,0xffffffff,0x100000001,0xffffffffffffffff]]
 result=dict(binary_sha256=m.digest,scope=__doc__,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),cases=cases,deltas=deltas,limitations=['Synthetic immutable scene/camera inputs; allocator/API/bin/callback boundaries captured, not original renderer execution.','Camera tanf original SSE CPU branch only; AVX/FMA output remains an explicit separate lower.','No meshes, viewport scheduler, live timing, server, production hook or final native visual acceptance.'])
 out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(cases),nodes=sum(len(c['tree']) for c in cases),collections=sum(len(c['collections']) for c in cases),deltas=len(deltas))))
if __name__=='__main__':main()
