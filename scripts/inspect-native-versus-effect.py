"""Original ExecuteCommandVersusEffect14054ac30 and SetInteger140425210.
Typed stack pop/push and effect destruction are captured ABI boundaries; no
effect application, combat or campaign completion claim. Synthetic inputs only.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);effect=m.heap+0x1000;storage=m.heap+0x2000;rules=m.heap+0x3000

def hook(u,a,n,_):
 global pop_index,pushed
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140286030:
  calls.append(['pop-effect']);m.wq(z,effect if c['effect'] else 0);m.finish(int(c['failure']!='effect'))
 elif a==0x140286110:
  pop_index+=1;calls.append(['pop-int',pop_index]);m.wi(y,c['first'] if pop_index==1 else c['second']);m.finish(int(c['failure']!=f'int{pop_index}'))
 elif a==0x140286330:
  calls.append(['push-effect',bool(z)]);pushed=bool(z);m.finish(int(c['failure']!='push'))
 elif a==0x140423770:calls.append(['destroy']);m.finish()
 elif a==0x140c10360:calls.append(['free',y]);m.finish()
 elif not (0x14054ac30<=a<0x14054ae96 or 0x140425210<=a<0x14042521c):raise AssertionError(f'Uncaptured versus dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,pop_index,pushed
 c=case;calls=[];pop_index=0;pushed=None;u.mem_write(m.heap,bytes(0x10000));m.wq(0x1412df8f8,rules)
 u.mem_write(rules+0x106,bytes([c['raceCount']&255]));u.mem_write(effect+8,struct.pack('<H',c['type']&65535));m.wq(effect+0x48,storage)
 initial=[100+i for i in range(8)]
 for i,v in enumerate(initial):m.wi(storage+i*4,v)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[m.heap+0x4000,c['ordinal'],c['argc']]):u.reg_write(reg,v)
 u.emu_start(0x14054ac30,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,integers=[m.si(storage+i*4) for i in range(8)],calls=calls)

default=dict(ordinal=355,argc=3,type=48,first=2,second=5,raceCount=28,effect=True,failure='')
rows=[]
for ordinal,type,first,second in itertools.product([355,356,0],list(range(100))+[65535,65549],[-1,0,1,2,3,4,5,6,28,29,255,256],[-7,0,5]):
 rows.append(run(default|dict(ordinal=ordinal,argc=3 if ordinal!=356 else 2,type=type,first=first,second=second)))
for count,first in itertools.product([0,1,28,255,256,257],[-1,0,1,27,28,29,254,255,256]):rows.append(run(default|dict(ordinal=356,argc=2,raceCount=count,first=first)))
for ordinal,present,fail in itertools.product([355,356],[False,True],['','effect','int1','int2','push']):rows.append(run(default|dict(ordinal=ordinal,effect=present,failure=fail)))
out=m.root/'backups/animations/native-versus-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
