"""Full original feat ability-delta4097c0 and ComputeFeatBonuses3f2110.
Membership/rules and derived score/modifier/encumbrance calls are captured
boundaries. Delta helper executes independently from its caller. Covers raw
BYTE bases/caches, rule-query order, polymorph snapshots and dirty flags.
The original hash continuation2ae870 executes unchanged, including its
prehashed first letter; rule-query boundary verifies the full effective key.
"""
import importlib.util,itertools,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
statsPtr,actorPtr,featsPtr,outPtr=[m.heap+n*0x3000 for n in range(1,5)]
getters=[0x140406930,0x1403fd3e0,0x1403fa0f0,0x140402d10,0x14040b5e0,0x1403fa050]
def fnv(text):
 value=0xcbf29ce484222325
 for b in text.encode('ascii'):value=((value^b)*0x100000001b3)&0xffffffffffffffff
 return value
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if c['mode']=='compute' and at==0x1404097c0:
  assert x==featsPtr;calls.append(['deltas',z&0xffffffff])
  for i,value in enumerate(c['deltas']):m.wi(y+i*4,value)
  m.finish();return
 if at==0x140296910:calls.append(['hasFeat',y&0xffffffff]);m.finish(int((y&0xffffffff)in c.get('feats',[])));return
 if at==0x1402a4130:assert y==fnv('EPIC_GREAT_STAT_BONUS');calls.append(['rule','EPIC_GREAT_STAT_BONUS',z&0xffffffff]);m.finish(c.get('bonus',1));return
 if at in getters:
  i=getters.index(at);calls.append(['score',i,u.mem_read(statsPtr+0xd38+i*2,1)[0]]);m.finish(c['scores'][i]);return
 if at==0x1403f16c0:calls.append(['modifier',y&255]);m.finish(c.get('modifier',-3));return
 if at==0x1403db1e0:assert x==actorPtr;calls.append(['encumbrance',y&0xffffffff]);m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not (0x1404097c0<=at<0x14040a68c or 0x1403f2110<=at<0x1403f22b5 or 0x1402ae870<=at<0x1402ae899):raise AssertionError(f'Uncaptured feat ability dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(statsPtr+0x30,actorPtr)
 for i,value in enumerate(c.get('bases',[10]*6)):u.mem_write(statsPtr+0xd38+i*2,bytes([value&255,0xa5]))
 m.wi(actorPtr+0x97c,c.get('polymorphed',0));m.wi(actorPtr+0x544,17)
 for i,value in enumerate(c.get('polyBases',[250,9,1])):u.mem_write(actorPtr+[0x9de,0x9e0,0x9df][i],bytes([value&255]))
 u.mem_write(outPtr,bytes([0xa5])*24);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 values=[statsPtr,featsPtr,c.get('remove',0)] if c['mode']=='compute'else[0 if c.get('nullFeats')else featsPtr,outPtr,c.get('remove',0)]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],values):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(0x1403f2110 if c['mode']=='compute'else 0x1404097c0,m.stop,count=250000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,deltas=[m.si(outPtr+i*4)for i in range(6)],bases=[u.mem_read(statsPtr+0xd38+i*2,1)[0]for i in range(6)],caches=[u.mem_read(statsPtr+0xd39+i*2,1)[0]for i in range(6)],poly=[u.mem_read(actorPtr+o,1)[0]for o in [0x9de,0x9e0,0x9df]],dirty=m.si(actorPtr+0x544))
rows=[]
for feat,bonus,remove in itertools.product(list(range(763,825))+[0,1000],[1,2,-1,0x7fffffff],[0,1,-2]):rows.append(run(dict(mode='deltas',feats=[feat,feat],bonus=bonus,remove=remove)))
for bonus,remove in itertools.product([1,0,-3,0x7fffffff],[0,1]):rows.append(run(dict(mode='deltas',feats=list(range(764,824)),bonus=bonus,remove=remove)))
rows.append(run(dict(mode='deltas',nullFeats=True,remove=1)))
rng=random.Random(20261016)
for i in range(160):rows.append(run(dict(mode='compute',deltas=[rng.choice([0,1,-1,256,-257,0x7fffffff])for _ in range(6)],bases=[rng.randrange(256)for _ in range(6)],scores=[rng.randrange(256)for _ in range(6)],modifier=rng.choice([-128,-3,0,5,127]),polymorphed=rng.choice([0,1,2]),polyBases=[rng.randrange(256)for _ in range(3)],remove=rng.choice([0,1]))))
out=m.root/'backups/animations/native-feat-ability-bonuses-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
