"""Original EffectComplex ordinal467 and Time Stop64/immunity98 apply/remove.
Complete four handlers, seconds conversions, AddWorldTimes and SetExpiryTime
execute. VM/base allocation, server pause/exclusion/clock getters, creature cast
and DM query are captured lower boundaries. Synthetic effect lists include
unsorted and duplicate entries. Invalid-add outputs expose seeded native stack,
not deterministic initialized results; no full spell/AI/presentation proof.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,effect,ints,vt,app,commands,timer,active,items=[m.heap+n*0x2000 for n in range(10)]
entry={'apply':0x140434810,'remove':0x140439240,'immunityApply':0x1404347e0,'immunityRemove':0x1404391b0,'constructor':0x1405180b0}
ranges=[(0x1405180b0,0x140518a6e),(0x140597010,0x14059703e),(0x140597140,0x14059717a),(0x140596b40,0x140596bc9),(0x1404251f0,0x1404251f8),(0x140425210,0x14042521c)]
for name in ['apply','remove','immunity-apply','immunity-remove']:
 body=json.loads((m.root/f'backups/animations/rea-time-stop-{name}-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
symbols={m.base+e.address:e.name.decode('ascii')for e in m.pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name}
def label(ptr):return 'self'if ptr==effect else str((ptr-items-0x1000)//0x200)
def hook(u,a,n,_):
 global pauses,output,addReturn,addStatus
 if a==m.stop:u.emu_stop();return
 if a==addReturn:addStatus=(u.reg_read(UC_X86_REG_RAX)&0xffffffff);addReturn=None
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 name=symbols.get(a,'')
 if a==0x14055b2b0:
  value=c.get('pause',[0])[min(pauses,len(c.get('pause',[0]))-1)];pauses+=1;calls.append(['pause',value&255]);m.finish(value)
 elif a==0x14055afe0:calls.append(['add',y&0xffffffff,z&255]);m.finish()
 elif a==0x14055bdc0:calls.append(['remove',y&0xffffffff,z&255]);m.finish()
 elif a==0x14055c270:calls.append(['toggle',y&255]);m.finish()
 elif a==0x14055ba10:calls.append(['worldTimer']);m.finish(timer)
 elif a==0x14055b2c0:calls.append(['activeTimer',y&0xffffffff]);m.finish(active)
 elif a==0x140597180:calls.append(['time']);m.wi(y,c.get('now',[7,100])[0]);m.wi(z,c.get('now',[7,100])[1]);m.finish()
 elif a==0x140596b40:addReturn=m.q(u.reg_read(UC_X86_REG_RSP))
 elif a==0x1404251f0:calls.append(['expiry',label(x),y&0xffffffff,z&0xffffffff])
 elif a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True)else 0)
 elif a==0x140402f80:calls.append(['dm']);m.finish(c.get('dm',0))
 elif a==0x140c10324:m.finish(effect)
 elif a==0x1404233d0:
  u.mem_write(x,bytes(0x120));m.wq(x,101);m.wq(x+0x48,ints);m.wi(x+0x40,8);m.wi(x+24,0x7f000000);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+32,1);m.wi(x+36,1);m.finish(x)
 elif a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a==0x140286330:
  flags=int.from_bytes(u.mem_read(z+10,2),'little');output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(z+24)&0xffffffff,integers=[m.si(m.q(z+0x48)+i*4)for i in range(8)]);calls.append(['push']);m.finish(c.get('push',1))
 elif a in [0x140423770,0x140c10360]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected Time Stop dependency {a:x} {name} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,pauses,output,addReturn,addStatus
 c=case;calls=[];pauses=0;output=None;addReturn=None;addStatus=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes([0xa5])*0x20000)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(actor+8,c.get('id',0xf0000001));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,app);m.wi(commands+12,c.get('id',0xf0000001))
 m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',64,9));m.wf(effect+12,c.get('duration',1));m.wi(timer+0x30,c.get('length',7200000));m.wi(timer+0x34,c.get('length',7200000)//1000)
 effects=c.get('effects',[]);m.wq(actor+0x150,items);m.wi(actor+0x158,len(effects));pointers=[]
 for i,row in enumerate(effects):
  ptr=effect if row.get('self')else items+0x1000+i*0x200;pointers.append(ptr);m.wq(items+i*8,ptr);u.mem_write(ptr+8,struct.pack('<H',row['type']));m.wi(ptr+16,77);m.wi(ptr+20,88)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[commands,467,0,0]if c['mode']=='constructor'else[app,actor,effect,c.get('loading',0)]
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
 try:u.emu_start(entry[c['mode']],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,output=output,addStatus=addStatus,expiries=[[m.si(p+16)&0xffffffff,m.si(p+20)&0xffffffff]for p in pointers])
lists=[[],[{'type':64}],[{'type':1},{'type':64},{'type':64}],[{'type':99},{'type':64}],[{'type':98,'self':True}],[{'type':98,'self':True},{'type':98}],[{'type':99},{'type':98}],[{'type':1},{'type':98}]]
cases=[dict(mode='apply',pause=pause,effects=effects,duration=duration,loading=loading,now=now,length=length)for pause,effects,duration,loading,now,length in itertools.product([[0],[1],[2],[3],[1,0],[2,1]],lists,[0,.001,.2999,1.234,7200.5],[0,1],[[7,100],[0xffffffff,999]],[1000,7200000])]
cases += [dict(mode='apply',pause=[1],effects=[{'type':64}],duration=-1,now=[7,100],length=1000)]
cases += [dict(mode='apply',pause=[1],effects=effects,duration=1,now=[7,1000],length=1000)for effects in [[],[{'type':64}]]]
cases += [dict(mode=mode,effects=effects,creature=creature,dm=dm)for mode,effects,creature,dm in itertools.product(['remove','immunityRemove'],lists,[False,True],[0,1,2,-1])]
cases += [dict(mode='immunityApply',loading=v)for v in [0,1,-1,255]]+[dict(mode='constructor',push=v)for v in [0,1]]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-time-stop-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entry},invalidAdds=sum(r['addStatus']==0xfffffffe for r in rows))))
