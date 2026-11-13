"""Execute original9c69a0 class-dependent creation/level-up routing and its
reached class/level getters. UI constructors, allocation, object lookup,
activation/deactivation and resource assignment are explicit service boundaries;
this proves routing/phase/callback transfer, not child panel behavior or pixels.
No original process, renderer, server or private profile is used.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,rules,classes,parent,created,application=[m.heap+n for n in [0x1000,0x2000,0x10000,0x20000,0x30000,0x40000,0x50000]]
counter=0x14142958c
ranges=[(0x1409c69a0,0x1409c6e62),(0x1407f0f60,0x1407f0fc9),(0x1407f1080,0x1407f109f)]
constructors={0x1401fbb80,0x140822b60,0x1401e7ef0,0x1401eca80,0x1401ec5d0,0x140707960,0x1401e7dc0}
factories={0x1409c2d80:'school',0x1409c3250:'spells'}
sizes={0xe80:'domains',0x1060:'school',0x1ac0:'spells',0xaa8:'associate'}
services={0x140800c90:'actor lookup',0x140c10324:'panel allocation',0x14018de80:'resource assignment',0x14018ded0:'resource assignment',0x1401fbe70:'panel activation',0x1401fc440:'modal deactivation',0x1406acc60:'UI registration',0x1406abe10:'client UI owner'}
case=None;calls=[];allocated=None
def byte(address,value):u.mem_write(address,bytes([value&255]))
def hook(_u,address,_size,_):
 global allocated
 if address==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if address==0x140800c90:m.finish(actor if case['present'] else 0)
 elif address==0x140c10324:
  assert x in sizes,f'Unexpected UI allocation {x:x}'
  allocated=sizes[x];calls.append(['allocate',allocated]);m.finish(created)
 elif address in constructors:m.finish(x)
 elif address in factories:
  calls.append(['factory',factories[address],y&0xffffffff,z&0xffffffff]);m.finish(x)
 elif address in [0x14018de80,0x14018ded0]:
  value=bytes(u.mem_read(y,17)).split(b'\0',1)[0];u.mem_write(x,(value+b'\0'*17)[:17]);calls.append(['resource',value.decode('ascii')]);m.finish(x)
 elif address==0x1401fc440:calls.append(['deactivate',y&0xffffffff]);m.finish()
 elif address==0x1401fbe70:calls.append(['activate',allocated]);m.finish()
 elif address==0x1406acc60:calls.append(['register',allocated]);m.finish()
 elif address==0x1406abe10:m.finish(application)
 elif not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original routing instruction {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
 global case,calls,allocated
 case=value;calls=[];allocated=None
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(counter,value['stage']);m.wq(actor+0x3b0,stats);byte(stats+0x69,1);byte(stats+0x6a,0);byte(stats+0x295,1);byte(stats+0x296,value['level'])
 m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);byte(rules+0x105,2)
 m.wq(0x1412df970,m.heap+0x60000);m.wq(m.heap+0x60000,m.heap+0x61000)
 cp=classes+0x530
 for key,offset in dict(PickDomains=0x4f4,PickSchool=0x4f8,SpellbookRestricted=0x4f0,SkipSpellSelection=0x528,Arcane=0x500).items():m.wi(cp+offset,value[key])
 byte(cp+0x524,value['MinAssociateLevel']);m.wq(parent+0x80,0x11223344);m.wq(parent+0x88,0x55667788)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,value['cancel']);u.reg_write(UC_X86_REG_RSP,rsp)
 for register,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[0x7fffff01,value['mode'],parent,value['code']]):u.reg_write(register,v)
 try:u.emu_start(0x1409c69a0,m.stop,count=20000)
 except Exception:
  failed=m.root/'godot-client/reports/native-creation-post-feats-original-failed-v1.json'
  if not failed.exists():failed.write_text(json.dumps(dict(input=value,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls),indent=2))
  print(json.dumps(dict(input=value,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 active=next((c[1]for c in calls if c[0]=='activate'),None);deactivate=next((c[1]for c in calls if c[0]=='deactivate'),None)
 return dict(input=value,output=dict(stage=m.si(counter)&0xffffffff,child=active,code=deactivate,activated=bool(u.reg_read(UC_X86_REG_RAX)&0xff),copiedCallback=[m.q(created+0x80),m.q(created+0x88)]if active else None,currentLevelUpPanel=m.q(application+0x18)==created if active else False,calls=calls.copy()))
if __name__=='__main__':
 output=m.root/'godot-client/reports/native-creation-post-feats-original-v1.json';assert not output.exists(),'Preserve original evidence'
 rows=[]
 for stage,mode,level,flags,minimum in itertools.product([0,1,2,3,4,255],[0,1],[0,1,2,10,255],range(16),[0,1,2,255]):
  c=dict(stage=stage,mode=mode,level=level,present=True,cancel=0,code=0x800e if flags&1 else 0x8010,PickDomains=flags&1,PickSchool=flags&2,SpellbookRestricted=flags&4,SkipSpellSelection=flags&8,Arcane=mode,MinAssociateLevel=minimum)
  rows.append(run(c))
 for stage,mode,present,cancel in itertools.product([0,1,2,3,4,255],[0,1],[False,True],[0,1]):
  if present and not cancel:continue
  rows.append(run(dict(stage=stage,mode=mode,level=1,present=present,cancel=cancel,code=3,PickDomains=1,PickSchool=1,SpellbookRestricted=1,SkipSpellSelection=0,Arcane=1,MinAssociateLevel=1)))
 output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,entry='0x1409c69a0',nativeRanges=[[hex(a),hex(b)]for a,b in ranges],serviceBoundaries={hex(a):b for a,b in services.items()},constructorBoundaries=[hex(a)for a in sorted(constructors)],factoryBoundaries={hex(a):b for a,b in factories.items()},rows=rows),indent=2)+'\n')
 print(json.dumps(dict(output=str(output),cases=len(rows),publicConnections=0,gpu=False)))
