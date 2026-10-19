"""Execute original ranged selector80f5e0 and travel762900, including native
float magnitude, divide, truncation and WORD wrapping. Object/equipment lookups,
SetBaseAnimation and melee dispatch are captured lower boundaries; no rendering,
gameplay resolution, live process changes or proprietary bytes are retained.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,target,context,record,animation,item=[m.heap+n for n in [0x3000,0x4000,0x5000,0x6000,0x6100,0x7000]]
ranges=[]
for name in ['rea-network-combat-select-attack-animation','rea-network-ranged-parry-travel','rea-network-ranged-vector-magnitude','rea-network-ranged-sqrt']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
commands=[];case={}
def word(p):return int.from_bytes(u.mem_read(p,2),'little')
def wh(p,v):u.mem_write(p,struct.pack('<H',v&65535))
def wb(p,v):u.mem_write(p,bytes([v&255]))
def hook(u,a,n,data):
 x,y,z,v=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406ab9e0:commands.append(dict(kind='target',id=y&0xffffffff));m.finish(0 if case['missingTarget']else target);return
 if a==0x140800c30:commands.append(dict(kind='weapon',type=y&255));m.finish(0x80000043);return
 if a==0x1406abc80:commands.append(dict(kind='item',id=y&0xffffffff));m.finish(0 if case['baseItem']is None else item);return
 if a==0x140764300:commands.append(dict(kind='base',animation=y&65535));m.finish();return
 if a==0x140800780:commands.append(dict(kind='classify'));m.finish(case.get('branch',2));return
 if a in [0x140810c20,0x14080ffd0,0x14080f7b0]:commands.append(dict(kind='melee',branch={0x140810c20:1,0x14080ffd0:2,0x14080f7b0:3}[a]));wh(y,204);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
cases=[dict(animation=9,ranged=1,side=side,reaction=reaction,missingTarget=missing,baseItem=base,duration=duration,from_=[1.25,-2,3.5],to=to)for side,reaction,missing,base,duration,to in itertools.product([0,1,2],[0,12,14],[False,True],[None,0,31,59,63,64,255],[1,916,65535],[[1.25,-2,3.5],[4.25,2,15.5],[200000,100000,-400000]])]
cases += [dict(animation=animation_,ranged=ranged,side=2,reaction=12,missingTarget=False,baseItem=31,duration=916,from_=[0,0,0],to=[3,4,0],branch=branch)for animation_,ranged,branch in itertools.product([0,9,92,200,65535],[0,1],[1,2,3])]
rows=[]
for case in cases:
 t.reset(dict(format=1));commands=[];m.wq(actor+0x78,context);wb(actor+0x170,case['side']);wb(context+0xe0,7);wh(actor+0x224,65535);wh(animation,case['animation'])
 for p,point in [(actor+0x38,case['from_']),(target+0x38,case['to'])]:u.mem_write(p,struct.pack('<3f',*point))
 wh(record+8,case['duration']);m.wi(record+16,0x80000012);wh(record+20,123);wh(record+22,case['reaction']);wh(record+26,0xabcd);m.wi(record+28,case['ranged']);wb(record+36,7)
 m.wi(item+0x40,case['baseItem']or 0);w.call(0x14080f5e0,[actor,animation,record])
 rows.append(dict(case=case,animation=word(animation),reaction=word(record+22),reactionDelay=word(record+20),side=u.mem_read(actor+0x170,1)[0],contextSide=u.mem_read(context+0xe0,1)[0],attackType=word(actor+0x224),commands=commands))
out=m.root/'backups/animations/native-client-ranged-selection-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
