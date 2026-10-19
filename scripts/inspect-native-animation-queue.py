"""Complete native Insert/GetNext/RemoveFireForgetAnimation executions.

Entry construction, growth/copy/shift, duplicate-pointer detection and timer
arithmetic execute unchanged. Timer is explicitly paused at synthetic dates;
allocation/free, app timer lookup and warning output are lower boundaries.
No native AI, animation selection/rendering, packet dispatch or live mutation.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,timer,out=m.heap+0x3000,m.heap+0x4000,m.heap+0x5000
ranges=[]
for name in ['rea-network-combat-set-visual-animation','rea-network-combat-next-animation','rea-network-animation-entry-constructor','rea-network-animation-queue-remove','rea-network-animation-elapsed']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
ranges.extend([(0x140596b40,0x140596bca),(0x140596e50,0x140596e90),(0x140597180,0x140597224)])
def hook(u,a,n,data):
 if a==0x1406ac330:m.finish(timer);return
 if a==0x140115890:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def word(a):return int.from_bytes(u.mem_read(a,2),'little')
def clock(day,time):m.wi(timer+0x1c,day);m.wi(timer+0x20,time)
def snapshot():
 p=m.q(actor+0x68);count=u.mem_read(actor+0x70,1)[0]
 return dict(capacity=word(actor+0x66),entries=[dict(animation=word(p+i*32+4),start=dict(day=m.si(p+i*32+8)&0xffffffff,time=m.si(p+i*32+12)&0xffffffff),duration=m.si(p+i*32+16)&0xffffffff,speed=m.rf(p+i*32+20),record=m.q(p+i*32+24))for i in range(count)])
rows=[]
for length,day,time in [(1000,7,100),(1000,7,990),(7200000,7,100),(7200000,0xffffffff,7199990)]:
 for duration,speed in itertools.product([0,49,50,500,10001],[0,.75,1.75]):
  t.reset(dict(format=1));u.mem_write(actor+12,bytes([5]));m.wi(timer+0x18,1);m.wi(timer+0x30,length);clock(day,time);operations=[]
  # >8 entries grows the native backing array; repeated record 101 is a
  # duplicate pointer, while null records and identical payloads are retained.
  for i,delay in enumerate([100,0,50,0,99,1,88,0,5,10,0,0]):
   rec=101 if i in [0,10]else 0 if i in [3,7,11]else 100+i
   delay=min(delay,length-1);m.wq(m.stack+0x1fe08+0x28,rec);m.wi(m.stack+0x1fe08+0x30,delay);u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',speed),'little'))
   w.call(0x1407635a0,[actor,200+i,duration,0]);operations.append(dict(kind='insert',animation=200+i,duration=duration,speed=speed,record=rec,delay=delay,state=snapshot()))
  for elapsed in [0,1,49,50,100,499,500,600]:
   clock((day+(time+elapsed)//length)&0xffffffff,(time+elapsed)%length)
   # Inspect and then consume head like its presentation owner. Empty backing
   # entries retain the native defaults after removal.
   m.wq(m.stack+0x1fe08+0x28,out+16);result=w.call(0x1407632d0,[actor,out,out+4,out+8])
   observed=dict(ready=result,animation=word(out),speed=m.rf(out+4),duration=m.si(out+8)&0xffffffff,record=m.q(out+16))
   operations.append(dict(kind='next',now=dict(day=m.si(timer+0x1c)&0xffffffff,time=m.si(timer+0x20)&0xffffffff),observed=observed))
   w.call(0x140763fb0,[actor]);operations.append(dict(kind='remove',state=snapshot()))
  while u.mem_read(actor+0x70,1)[0]:w.call(0x140763fb0,[actor])
  m.wq(m.stack+0x1fe08+0x28,out+16);result=w.call(0x1407632d0,[actor,out,out+4,out+8]);operations.append(dict(kind='empty',observed=dict(ready=result,animation=word(out),speed=m.rf(out+4),duration=m.si(out+8)&0xffffffff,record=m.q(out+16))))
  rows.append(dict(length=length,now=dict(day=day,time=time),operations=operations))
outpath=m.root/'backups/animations/native-animation-queue-observations.json';outpath.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(outpath))))
