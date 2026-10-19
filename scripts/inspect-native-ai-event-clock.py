"""Complete original AI AddEventAbsoluteTime556eb0, ViaTail556fb0,
AddEventDeltaTime5570b0, EventPending557fe0 and GetPendingEvent5580d0.
Original world-time add/compare execute. Heap/free, linked-list storage,
world-time/pause getters and log sink are captured boundaries. Synthetic
metadata/payload identities; no full AI dispatch/budget, script wrapper,
native payload destruction, saved event queue, protocol or campaign claim.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
master,server,timer,owner,app,output=[m.heap+n*0x1000 for n in range(6)]
entry={'absolute':0x140556eb0,'tail':0x140556fb0,'delta':0x1405570b0,'pending':0x140557fe0,'pop':0x1405580d0};ranges=[(0x140596b40,0x140596bc9),(0x140596e50,0x140596e90)]
for name in ['add-absolute','add-tail','add-delta','pending-check','pending']:
 body=json.loads((m.root/f'backups/animations/rea-pause-event-{name}-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
def allocate(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~31;assert cursor<0xf0000;u.mem_write(ptr,bytes([0xa5])*size);return ptr
def refresh():
 m.wq(owner,nodes[0][0]if nodes else 0);m.wq(owner+8,nodes[-1][0]if nodes else 0);m.wi(owner+16,len(nodes))
 for i,(ptr,data)in enumerate(nodes):m.wq(ptr,nodes[i+1][0]if i+1<len(nodes)else 0);m.wq(ptr+8,nodes[i-1][0]if i else 0);m.wq(ptr+16,data)
def add(data,index):nodes.insert(index,(allocate(24),data));refresh()
def event(ptr):return dict(day=m.si(ptr)&0xffffffff,time=m.si(ptr+4)&0xffffffff,caller=m.si(ptr+8)&0xffffffff,target=m.si(ptr+12)&0xffffffff,eventId=m.si(ptr+16)&0xffffffff,payload=f'{m.q(ptr+24):016x}')
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c10324:
  assert x==32;ptr=allocate(x);names[ptr]='new';allocations.append(x);m.finish(ptr)
 elif a==0x14055b2b0:m.finish(c['pause'])
 elif a==0x140115890:calls.append('paused-warning');m.finish()
 elif a==0x140597180:m.wi(y,c['now'][0]);m.wi(z,c['now'][1]);m.finish()
 elif a==0x1401690b0:m.finish(m.q(y+16))
 elif a in [0x140169110,0x140169180]:
  node=m.q(y);node=m.q(node+(0 if a==0x140169110 else 8));m.wq(y,node);m.finish(m.q(node+16)if node else 0)
 elif a in [0x140168ed0,0x140168df0]:
  index=next(i for i,(ptr,_)in enumerate(nodes)if ptr==z);add(y,index+(a==0x140168df0));m.finish()
 elif a==0x140168fb0:add(y,0);m.finish()
 elif a==0x140169030:add(y,len(nodes));m.finish()
 elif a==0x1401692a0:
  _,data=nodes.pop(0);refresh();m.finish(data)
 elif a==0x140c10360:freed.append(dict(name=names[x],payloadAfterClear=f'{m.q(x+24):016x}'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unknown AI queue dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,nodes,names,allocations,calls,freed
 c=case;cursor=0x50000;nodes=[];names={};allocations=[];calls=[];freed=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(master,server);m.wq(master+0x80,owner);m.wq(server+0x10098,timer);m.wi(timer+0x30,1000);m.wq(0x1412df970,app);m.wq(app+8,server)
 for index,(day,time)in enumerate(c['queue']):
  ptr=allocate(32);names[ptr]='old'+str(index)
  for offset,value in [(0,day),(4,time),(8,100+index),(12,200+index),(16,300+index)]:m.wi(ptr+offset,value)
  m.wq(ptr+24,0x12340000+index);add(ptr,len(nodes))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,master)
 if c['mode']=='pop':
  u.mem_write(output,bytes([0xa5])*64)
  for reg,value in zip([UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[output,output+4,output+8]):u.reg_write(reg,value)
  for offset,value in [(0x28,output+12),(0x30,output+16),(0x38,output+24)]:m.wq(rsp+offset,value)
 else:
  a,b=c['delta']if c['mode']=='delta'else c['now']if c['mode']=='pending'else c['deadline'];u.reg_write(UC_X86_REG_RDX,a);u.reg_write(UC_X86_REG_R8,b);u.reg_write(UC_X86_REG_R9,0xf0000001);m.wi(rsp+0x28,0x80000001);m.wi(rsp+0x30,999);m.wq(rsp+0x38,0xdeadbeef)
 try:u.emu_start(entry[c['mode']],m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,allocations=allocations,order=[names[data]for _,data in nodes],events=[event(data)for _,data in nodes],freed=freed)
 if c['mode']=='pop'and result['result']:result['output']=event(output)
 return result
queues=[[],[[1,100]],[[1,100],[1,100],[1,300]],[[1,300],[1,100]],[[0xffffffff,999],[0,0]],[[1,1000],[1,10]]]
cases=[dict(mode=mode,queue=queue,deadline=deadline)for mode,queue,deadline in itertools.product(['absolute','tail'],queues,[[0,0],[1,0],[1,100],[1,101],[1,1000],[0xffffffff,999]])]
cases += [dict(mode='delta',queue=queue,now=now,delta=delta,pause=pause)for queue,now,delta,pause in itertools.product(queues,[[1,0],[1,999],[0xffffffff,999],[1,1000]],[[0,0],[0,1],[0,100],[0,1000],[1,0],[1,100],[0xffffffff,999]],[0,1,2,3])]
cases += [dict(mode='pending',queue=queue,now=now)for queue,now in itertools.product(queues,[[0,0],[1,0],[1,100],[1,101],[1,1000],[0xffffffff,999]])]
cases += [dict(mode='pop',queue=queue)for queue in queues]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-ai-event-clock-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entry})))
