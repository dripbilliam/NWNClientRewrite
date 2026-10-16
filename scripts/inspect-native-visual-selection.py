"""Complete original visual selection140761d90..140761ff7 plus actual
program-type/retirement/cessation getters. Linked-list traversal, controlled
object/view-gate queries and attach/detach/start/stop are captured providers.
Synthetic ordered records verify selection/state ordering, not lower rendering.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,listing,manager,controlled,viewGate1407dadb0=[m.heap+n*0x1000 for n in range(5)]
ranges=[(0x140761d90,0x140761ff7),(0x140762c10,0x140762ccf),(0x14096c450,0x14096c458),(0x14096c5d0,0x14096c606),(0x14096c610,0x14096c637)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x140169110:
  index=indices.get(m.q(y),-1)+1;ptr=nodes[index]if index<len(nodes)else 0;m.wq(y,ptr);m.finish(models[index]if ptr else 0)
 elif a==0x140169180:
  index=indices[m.q(y)]-1;ptr=nodes[index]if index>=0 else 0;m.wq(y,ptr);m.finish(models[index]if ptr else 0)
 elif a==0x1406ac1c0:calls.append(['selectedObjectId1406ac1c0']);m.finish(c['controlledId'])
 elif a==0x1406abea0:calls.append(['controlled']);m.finish(controlled)
 elif a==0x1407dadb0:calls.append(['viewGate1407dadb0']);m.finish(c['viewGate1407dadb0'])
 elif a in [0x14096c180,0x14096ed70,0x140971530,0x140970e20]:
  name={0x14096c180:'detach',0x14096ed70:'attach',0x140971530:'stop',0x140970e20:'start'}[a];calls.append([name,models.index(x)]+([y&0xffffffff]if name=='stop'else[]))
  if name in ['detach','attach']:m.wi(x+0x114,int(name=='attach'))
  if name in ['stop','start']:m.wi(x+0xec,int(name=='stop'))
  m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected visual selection dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,ptr,type=0):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,ptr);u.reg_write(UC_X86_REG_RDX,type);u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def run(case):
 global c,calls,nodes,models,indices
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(controlled+0xf8,viewGate1407dadb0);m.wq(actor+0x80,listing);m.wi(actor+8,123);m.wi(actor+0x108,c['suppressed']);nodes=[];models=[]
 for i,e in enumerate(c['entries']):
  ptr=m.heap+0x10000+i*0x1000;node=m.heap+0x8000+i*0x100;models.append(ptr);nodes.append(node);m.wq(node+0x10,ptr)
  for field,key in [(0xf4,'finished'),(0x110,'field110'),(0x114,'attached'),(0xec,'closed')]:m.wi(ptr+field,e[key])
  u.mem_write(ptr+0x10c,bytes([e['scope'],e['type']]));u.mem_write(ptr+0xf8,int(e['visual']).to_bytes(2,'little'))
  for j,v in enumerate(e['retired']):m.wi(ptr+0xdc+j*4,v)
  u.mem_write(ptr+0xfa,bytes([e['phase']]))
  for j,v in enumerate(e['states']):u.mem_write(ptr+0x68+j*2,int(v).to_bytes(2,'little'));m.wq(ptr+0x88+j*8,ptr+0x500 if e['models'][j]else 0)
 indices={ptr:i for i,ptr in enumerate(nodes)};m.wq(listing,nodes[0]if nodes else 0);m.wq(listing+8,nodes[-1]if nodes else 0)
 try:invoke(0x140762c10 if 'remove' in c else 0x140761d90,actor,models[c['remove']]if 'remove' in c else c['type'])
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 return dict(case=c,calls=calls,attached=[m.si(ptr+0x114)for ptr in models],closed=[m.si(ptr+0xec)for ptr in models],retired=[invoke(0x14096c5d0,ptr)for ptr in models],cessation=[invoke(0x14096c610,ptr)for ptr in models])
def entry(**kw):
 e=dict(finished=0,field110=0,attached=0,closed=0,scope=0,type=0,visual=456,retired=[1,1,1],phase=0,models=[1,1,1],states=[0,0,0]);e.update(kw);return e
def profile(entries,**kw):
 c=dict(entries=entries,suppressed=0,controlledId=123,viewGate1407dadb0=1,type=0);c.update(kw);return c
rows=[run(profile([entry(scope=scope,attached=attached,closed=closed,field110=field110,type=kind,finished=finished)],type=kind,viewGate1407dadb0=viewGate1407dadb0,suppressed=suppressed))for scope,attached,closed,field110,kind,finished,viewGate1407dadb0,suppressed in itertools.product([0,1,255],[0,1],[0,1],[0,1],[0,4,7],[0,1],[0,1],[0,1])]
rows.extend(run(profile([entry(scope=s,type=kind,attached=attached)for s in scopes],type=kind))for scopes,kind,attached in itertools.product([[3,1,2],[1,1,1],[255,255],[0,3,0,1],[3,0,1,0]],[0,4,7],[0,1]))
rows.extend(run(profile([entry(visual=visual,scope=scope)],controlledId=id))for visual,scope,id in itertools.product([181,182,183,241,242,243,244,245],[0,1],[123,789]))
rows.extend(run(profile([entry(finished=finished,retired=retired,phase=phase,models=models,states=states)]))for finished,retired,phase,models,states in itertools.product([0,1],[[1,1,1],[0,1,1],[1,0,1],[1,1,0]],[0,1,2,3],[[1,1,1],[0,1,0]],[[0,0,0],[3,0,0],[0,3,0],[0,0,3]]))
rows.append(run(profile([])))
out=m.root/'backups/animations/native-visual-selection-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
removals=[]
for kind,candidate,scope,attached,finished,index in itertools.product([0,4,7],[0,4,7],[0,1,255],[0,1],[0,1],[0,1,2]):
 entries=[entry(type=candidate,scope=scope,attached=attached,finished=finished)for _ in range(3)];entries[index]=entry(type=kind,scope=1,attached=1)
 removals.append(run(profile(entries,remove=index)))
for attached in [0,1]:
 removals.append(run(profile([entry(type=4,scope=1,attached=1),entry(type=4,scope=1,attached=attached),entry(type=4,scope=1,attached=1)],remove=2)))
out=m.root/'backups/animations/native-visual-competing-removal-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits='Complete140762c10..140762ccf; actual type getter, native linked-list shape and traversal provider. Other rendering is captured, not emulated.',rows=removals),indent=2));print(json.dumps(dict(output=str(out),rows=len(removals))))
