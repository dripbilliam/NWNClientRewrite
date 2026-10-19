"""Complete ComputeModifiedMovementRate. Original mode/feat/rules gates, signed
stage arithmetic, sorted cache-range removals/restarts and effect construction/
delivery order execute. Capture independently checked HasFeat/rules lookup,
allocation/base+clearing-copy constructors, effect integer/creator and apply/
remove boundaries. Apply/remove update the synthetic canonical sorted array and
native range caches; full speed/icon side effects are installed-runtime checks.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,stats,storage,rules=[m.heap+i*0x1000 for i in range(4)]
body=json.loads((m.root/'backups/animations/rea-modified-movement-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body']['ranges'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in body]
def string(p):
 out=bytearray()
 while u.mem_read(p+len(out),1)[0]!=0:out+=u.mem_read(p+len(out),1)
 return out.decode()
def sync():
 m.wq(actor+0x150,storage);m.wi(actor+0x158,len(effects))
 for i,p in enumerate(effects):m.wq(storage+i*8,p)
 for off,type in[(0xdc2,59),(0xdc4,29)]:u.mem_write(stats+off,next((i for i,p in enumerate(effects)if int.from_bytes(u.mem_read(p+8,2),'little')>=type),len(effects)).to_bytes(2,'little'))
def effect(p,id,type,duration,creator,amount):
 u.mem_write(p,bytes(0x110));m.wq(p,id);u.mem_write(p+8,struct.pack('<HH',type,duration));m.wi(p+24,creator);m.wq(p+0x48,p+0x200);m.wi(p+0x40,8);u.mem_write(p+0x200,bytes(32));m.wi(p+0x200,amount)
def snapshot(p):return dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),durationType=int.from_bytes(u.mem_read(p+10,2),'little')&7,creatorId=m.si(p+24)&0xffffffff,integers=[m.si(m.q(p+0x48)+i*4)for i in range(8)])
def hook(u,a,n,_):
 global featIndex,allocations
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14040b900:trace.append(['feat',y&65535]);values=c.get('feats',[0,0]);m.finish(values[min(featIndex,len(values)-1)]);featIndex+=1
 elif a==0x1402ae870:key='M'+string(x);hashes[len(hashes)+1]=key;m.finish(len(hashes))
 elif a==0x1402a4130:key=hashes[y];trace.append(['rule',key,z&0xffffffff]);m.finish(c.get('rules',{}).get(key,z))
 elif a==0x140423fc0:m.finish(m.si(m.q(x+0x48)+y*4))
 elif a==0x140498280:
  trace.append(['remove',f'{y:016x}']);found=next(i for i,p in enumerate(effects)if m.q(p)==y);effects.pop(found);sync();m.finish()
 elif a==0x140c10324:allocations+=1;m.finish(m.heap+0x10000+allocations*0x1000)
 elif a==0x1404233d0:effect(x,1001,0,0,0x7f000000,0);trace.append(['create','00000000000003e9']);m.finish(x)
 elif a==0x140423570:
  value=snapshot(y);effect(x,int(value['id'],16),0,value['durationType'],value['creatorId'],0);trace.append(['copy',value['id'],z&0xffffffff]);m.finish(x)
 elif a==0x140425110:trace.append(['creator',f'{m.q(x):016x}',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a==0x140425210:m.wi(m.q(x+0x48)+y*4,z);m.finish()
 elif a==0x14048e350:trace.append(['apply',snapshot(y),z&0xffffffff,w&0xffffffff]);effects.append(y);effects.sort(key=lambda p:int.from_bytes(u.mem_read(p+8,2),'little'));sync();m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped modified movement dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,featIndex,allocations,effects,hashes
 c=case;trace=[];featIndex=allocations=0;hashes={};effects=[];u.mem_write(m.heap,bytes(0x40000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor+0xad0,stats);m.wq(0x1412df8f8,rules);m.wi(actor+8,0x80000042);m.wi(actor+0xd8,c.get('animation',0));u.mem_write(actor+0x6ec,bytes([c.get('detect',0)&255,c.get('stealth',0)&255]));m.wi(actor+0x970,c.get('encumbrance',0))
 initial=c.get('effects',[[1,28,1,77,130],[2,29,4,0x80000042,50],[3,29,1,0x80000042,25],[4,59,4,77,1],[5,59,4,77,0],[6,67,4,77,9]])
 for i,row in enumerate(initial):p=m.heap+0x4000+i*0x400;effect(p,*row);effects.append(p)
 sync();before=[snapshot(p)for p in effects];rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
 try:u.emu_start(0x1403889b0,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,before=before,after=[snapshot(p)for p in effects],trace=trace)
cases=[dict(animation=a,detect=d,stealth=s,encumbrance=e,feats=f)for a,d,s,e,f in itertools.product([0,1],[0,1,2],[0,1],[0,1,2,-1],[[0,0],[1,1],[1,0],[0,1]])]
cases +=[dict(detect=1,stealth=1,encumbrance=2,rules={name:value for name in['MOVEMENT_STAGE_PENALTY_DETECT_MODE','MOVEMENT_STAGE_PENALTY_STEALTH_MODE','MOVEMENT_STAGE_PENALTY_ENCUMBRANCE_OVERLOADED']})for value in[-3,-1,0,1,2,4,10]]
cases +=[dict(encumbrance=e,effects=fx)for e,fx in itertools.product([0,1,2],[[],[[1,29,4,77,50]],[[1,59,3,77,1]],[[1,29,4,0x80000042,50],[1,59,4,0x80000042,1]]])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-modified-movement-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
