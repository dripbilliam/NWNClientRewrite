"""Read-only GetShadowLights14007f840 modes 1/0 on synthetic light lists.
Executes the original selection, shared fades and previous-list ordering.
Allocation/list storage and memory copy/free are explicit helper boundaries.
Candidate construction/sorting, mode 2, drawing and live GPU parity are excluded.
"""
import importlib,json,random
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager=m.heap+0x1000
allocation=m.heap+0x50000
def alloc():
 global allocation
 p=allocation;allocation+=0x4000
 assert allocation<m.heap+0x100000
 return p
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14007db60:
  count=m.si(x+8);pointer=m.q(x)
  if not pointer:pointer=alloc();m.wq(x,pointer);m.wi(x+12,128)
  m.wq(pointer+count*8,y);m.wi(x+8,count+1);m.finish();return
 if a==0x140080f00:
  pointer=m.q(x)
  if not pointer:pointer=alloc();m.wq(x,pointer);m.wi(x+12,128)
  m.wi(x+8,y);m.finish();return
 if a==0x140c417f0:
  u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x140c4f024:m.finish();return
 if a==0x140c4f038:
  p=alloc()
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x4000))))
  m.finish(p);return
 if not 0x14007f840<=a<0x14007fe33:raise RuntimeError('Unexpected dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global allocation
 allocation=m.heap+0x50000
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 lights=[m.heap+0x10000+i*0x200 for i in range(len(case['lights']))]
 lookup={p:i for i,p in enumerate(lights)}
 for i,(p,c) in enumerate(zip(lights,case['lights'])):
  m.wf(p+0x74,c['radius']);m.wf(p+0x7c,c['shadowRadius']);m.wi(p+0x8c,c['dynamic']);m.wf(p+0x9c,c['distance']);m.wf(p+0xac,case['fades'][i])
 def store(offset,indices):
  p=alloc();m.wq(manager+offset,p);m.wi(manager+offset+8,len(indices));m.wi(manager+offset+12,128)
  for i,index in enumerate(indices):m.wq(p+i*8,lights[index])
 store(0x50,case['candidates']);store(0x80,[]);store(0xa8,case['previous'][0]);store(0xb8,case['previous'][1])
 m.wi(0x14128e58c,case['maximum']);m.wf(0x14128e030,case['delta'])
 lists={}
 for mode in [1,0]:
  rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,manager);u.reg_write(UC_X86_REG_RDX,mode)
  u.emu_start(0x14007f840,m.stop,count=50000)
  assert u.reg_read(UC_X86_REG_RIP)==m.stop
  lists[str(mode)]=[lookup[m.q(m.q(manager+0x80)+i*8)] for i in range(m.si(manager+0x88))]
 return dict(case=case,lists=lists,fades=[m.rf(p+0xac) for p in lights])
rng=random.Random(819337);rows=[]
for n in range(500):
 lights=[dict(radius=rng.choice([0,2,8,20]),shadowRadius=rng.choice([-1,0,4,12]),dynamic=rng.randrange(2),distance=rng.choice([0,2,4,8,12,20,21])) for i in range(9)]
 candidates=rng.sample(range(9),rng.randrange(10));previous=[rng.sample(range(9),rng.randrange(4)) for mode in range(2)]
 rows.append(run(dict(lights=lights,candidates=candidates,previous=previous,fades=[rng.choice([0,.01,.2,.5,.99,1]) for i in lights],maximum=n%3+1,delta=rng.choice([0,.001,.016,.05,.1,.3]))))
out=m.root/'backups/animations/native-shadow-selection-observations-v1.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2))
print(json.dumps(dict(output=str(out),cases=len(rows))))
