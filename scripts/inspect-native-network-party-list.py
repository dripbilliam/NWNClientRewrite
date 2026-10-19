"""Original4dddb0 sender -> full7a7440 receiver -> original party list owners
851220/852ac0/852f90/853060/851c60/851700. Native wire scalars and array mutation
execute. Object lookup is absent; GUI constructors/labels/models/layout/scroll,
virtual draw/destruction, memory copy, net permission and transport are captured
lowers. Existing/new member layout is explicit fixture memory, not real GUI.
Normal-player path only. No proxy creation, original renderer or live mutation.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
app,client,net,appvt=[m.heap+n*0x1000 for n in range(20,24)]
appObject=m.heap+0x18000
bar=m.heap+0x30000;vt=m.heap+0x3a000;model=m.heap+0x3b000;string=m.heap+0x3c000;array=m.heap+0x50000;source=m.heap+0x54000
ranges=[(0x1409737c0,0x1409737e8)]
for name in ['network-party-list-sender','network-party-client-dispatch','network-party-add','network-party-clear','network-party-full-finish','network-party-remove','network-party-entry-initialize','network-party-array-remove']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def member(ptr,oid,stale):
 m.wq(ptr,vt);m.wq(ptr+0x10,model);m.wi(ptr+0x328,oid);m.wi(ptr+0x80,int(stale))
def hook(u,a,n,data):
 global allocated
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;sent.append(bytes([80,z&255,k&255])+bytes(u.mem_read(m.q(sp+0x28),size))[3:]);m.finish(1);return
 if a==0x1406ac020:m.finish(bar);return
 if a in [0x1406acc10,0x1402377b0,0x1406ac1a0,0x140115890]:m.finish(0);return
 if a==0x140296470:m.finish(1);return
 if a==m.stop+0x38:m.finish(net);return
 if a==m.stop+0x100:m.finish(0);return
 if a==m.stop+0x110:destroyed.append(m.si(x+0x328)&0xffffffff);m.finish();return
 if a==0x140c10324:ptr=m.heap+allocated;allocated+=0x1000;assert allocated<0x90000;m.finish(ptr);return
 if a==0x1408509c0:member(x,0x7f000000,False);m.finish(x);return
 if a==0x1401e80b0:m.wq(x+0x90,string);m.finish(x);return
 if a in [0x1401f0990,0x1401fb710,0x1401e8f60,0x1401fafa0,0x1401fb630,0x140852e50,0x1408547b0,0x140853520,0x1408535b0]:m.finish();return
 if a==0x140c417f0:
  assert z<0x100000
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,sent,destroyed,allocated
 c=case;sent=[];destroyed=[];allocated=0x60000;t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 for i,oid in enumerate(c['ids']):m.wi(source+i*4,oid)
 m.wi(sp+0x28,c['minor']);m.wi(sp+0x30,c['exclude']);w.call(0x1404dddb0,[w.message,7,len(c['ids']),source]);assert len(sent)==1;packet=sent[0]
 m.wq(0x1412df970,app);m.wi(app+0x28,c['format']);m.wq(app,appObject);m.wq(appObject,appvt);m.wq(appvt+0x38,m.stop+0x38);m.wq(appObject+8,client);m.wq(client+0x28,m.heap+0x28000)
 for offset in [0x30,0x78,0xc0]:m.wq(vt+offset,m.stop+0x100)
 m.wq(vt,m.stop+0x110);m.wq(model,vt);m.wq(string,vt);m.wq(bar+0x1190,array);m.wi(bar+0x1198,len(c['prior']));m.wi(bar+0x119c,128);m.wq(bar+0x11a0,model);m.wi(bar+0x11dc,-1);m.wi(bar+0x11d8,0);m.wi(bar+0x11f8,0x7f000000);m.wi(bar+0x15b0,0xffffffff)
 for i,e in enumerate(c['prior']):ptr=m.heap+0x90000+i*0x400;member(ptr,e['id'],e['stale']);m.wq(array+i*8,ptr)
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 result=w.call(0x1407a7440,[w.message,c['minor']]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 entries=[dict(id=m.si(m.q(array+i*8)+0x328)&0xffffffff,stale=bool(m.si(m.q(array+i*8)+0x80)))for i in range(m.si(bar+0x1198))]
 return dict(case=c,packet=packet.hex(),result=result,entries=entries,destroyed=list(destroyed))
priors=[[],[dict(id=0x80000064,stale=False),dict(id=0x80000065,stale=False)],[dict(id=0x80000065,stale=False),dict(id=0x80000064,stale=False)],[dict(id=0,stale=False),dict(id=0x7f000000,stale=True),dict(id=0xffffffff,stale=False)],[dict(id=0x80000064,stale=True),dict(id=0x80000065,stale=True)]]
lists=[[],[100],[101,100],[100,100],[0x7f000000,101,0x7f000000],list(range(100,112)),[0,0x7fffffff,0x80000002]]
rows=[]
for f,minor,prior,ids,exclude in itertools.product([0,1],[1,3,4],priors,lists,[0x7f000000,100,0xffffffff]):
 c=dict(format=f,minor=minor,prior=prior,ids=ids,exclude=exclude)
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-party-list-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
