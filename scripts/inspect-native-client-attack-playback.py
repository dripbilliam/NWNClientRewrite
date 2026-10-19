"""Complete original client attack PlayAnimation and model-hit callback owners.

Synthetic lookup/model records; selector, length, queue insertion, motion/weapon
effects, sound, barks, VFX and CRT draws are captured lower boundaries. Native
WORD state getters, action copy, parry classification and end-animation helper
execute. No combat resolution, native renderer or real process mutation.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,target,context,tc,record,next_,pending,vt,tvt,stats,appearance=[m.heap+n for n in [0x3000,0x4000,0x5000,0x5400,0x6000,0x6100,0x6200,0x7000,0x7800,0x8000,0x9000]]
ranges=[]
for name in ['rea-network-combat-queue-insert','rea-network-combat-model-attack-event','rea-network-combat-pending-record-copy','rea-network-combat-clear-fireforget','rea-network-combat-parry-classifier']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
ranges.extend([(0x1407630d0,0x1407630d5),(0x140763220,0x140763225)])
commands=[];case={};drawIndex=0
def word(a):return int.from_bytes(u.mem_read(a,2),'little')
def wh(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def wb(a,v):u.mem_write(a,bytes([v&255]))
def label(p):return 'source'if p==actor else'target'if p==target else 'head'if p==record else'next'if p==next_ else'pending'if p==pending else None
def rec(p):return dict(type=u.mem_read(p,1)[0],sourceId=m.si(p+4)&0xffffffff,targetId=m.si(p+16)&0xffffffff,duration=word(p+8),damage=word(p+10),result=u.mem_read(p+12,1)[0],reactionDelay=word(p+20),reaction=word(p+22),reactionDuration=word(p+24),attackType=word(p+26),ranged=m.si(p+28),killingBlow=m.si(p+32),weaponAttackType=u.mem_read(p+36,1)[0],next=label(m.q(p+64)))
def hook(u,a,n,data):
 global drawIndex
 x,y,z,v=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x1406ab9e0,0x1406abb60]:m.finish(actor if y&0xffffffff==0xffffffff and not case.get('missingSource')else target if y&0xffffffff==0x80000012 and not case.get('missingTarget')else 0);return
 if a==m.stop+0x58:m.finish(x if x==actor or case['targetType']==5 else 0);return
 if a in [m.stop+0xa0,m.stop+0x28]:m.finish(x if x==target and case['targetType']==(9 if a==m.stop+0xa0 else 10)else 0);return
 if a==0x1407630a0:m.finish(m.q(x+0x78));return
 if a==0x1407fecc0:commands.append(dict(kind='prepare',object=label(x)));m.finish();return
 if a==m.stop+0x60:commands.append(dict(kind='stop-motion',object='source'));m.finish();return
 if a==0x14080f5e0:commands.append(dict(kind='select',object=label(x)));wh(y,case['selected']);wh(z+22,case['selectedReaction']);wh(z+20,case['selectedDelay']);m.finish();return
 if a==0x1407630b0:
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',1200 if x==actor else 700),'little'));m.finish();return
 if a==0x1407635a0:
  speed=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM3)&0xffffffff))[0]
  commands.append(dict(kind='insert',object=label(x),animation=y&65535,duration=z&0xffffffff,speed=speed,record=label(m.q(sp+0x28)),delay=m.si(sp+0x30)&0xffffffff));m.finish();return
 if a==0x140c7ed00:
  draws=case.get('draws',[1]);m.finish(draws[min(drawIndex,len(draws)-1)]);drawIndex+=1;return
 if a==0x140807240:commands.append(dict(kind='bark',object=label(x),value=y&65535));m.finish();return
 if a==0x140805d20:commands.append(dict(kind='sound',object=label(x),record=label(y),flag=z&0xffffffff));m.finish();return
 if a==0x1407fd6b0:commands.append(dict(kind='weapon-effect',object=label(x),value=y&0xffffffff));m.finish();return
 if a==0x140764300:commands.append(dict(kind='base',object=label(x),animation=y&65535));m.finish();return
 if a==m.stop+0x150:commands.append(dict(kind='play',object=label(x),animation=y&65535,record=label(z)));m.finish();return
 if a==m.stop+0x10:m.finish(1 if case.get('parryModel')else 0);return
 if a==0x1401a7010:m.wi(v,case.get('abort',0));m.finish(1);return
 if a==0x14080bb10:commands.append(dict(kind='effect',object=label(x),impact=y&255,record=label(z)));m.finish();return
 if a==0x140c10360:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
cases=[]
for mode,current,body,ranged,result,targetType,targetCurrent,nextFlag in itertools.product(['play','hit'],[0,2,4,24,25],[0,1],[0,1],[0,1,2,3,4,10,15],[5,9],[0,207],[False,True]):
 # Distinct native branches; avoid redundant moving combinations in hit mode.
 if mode=='hit'and(current!=0 or body!=0):continue
 cases.append(dict(mode=mode,current=current,body=body,ranged=ranged,result=result,targetType=targetType,targetCurrent=targetCurrent,next=nextFlag,selected=200,selectedReaction=207,selectedDelay=15))
cases += [dict(mode='hit',current=0,body=1,ranged=0,result=2,targetType=5,targetCurrent=207,next=True,abort=1,parryModel=model,selected=200,selectedReaction=207,selectedDelay=15)for model in [False,True]]
cases += [dict(mode=mode,current=0,body=1,ranged=0,result=1,targetType=5,targetCurrent=0,next=True,missingSource=source,missingTarget=not source,selected=200,selectedReaction=207,selectedDelay=15)for mode,source in itertools.product(['play','hit'],[False,True])]
cases += [dict(mode=mode,current=0,body=1,ranged=0,result=result,targetType=5,targetCurrent=0,next=nextFlag,draws=draws,hp=10,killingBlow=0,selected=200,selectedReaction=reaction,selectedDelay=15)for mode,result,nextFlag,draws,reaction in itertools.product(['play','hit'],[1,2,3],[False,True],[[0,0],[0,1],[0,2]],[207,262])]
for case in cases:
 t.reset(dict(format=1));commands=[];drawIndex=0
 for a,v,ctx,type_ in [(actor,vt,context,5),(target,tvt,tc,case['targetType'])]:
  m.wq(a,v);m.wq(a+0x78,ctx);wb(a+12,type_);m.wq(v+0x58,m.stop+0x58);m.wq(v+0xa0,m.stop+0xa0);m.wq(v+0x28,m.stop+0x28);m.wq(v+0x150,m.stop+0x150);m.wq(ctx,vt+0x400);m.wq(vt+0x400+0x60,m.stop+0x60);m.wq(vt+0x400+0x10,m.stop+0x10)
 m.wi(actor+8,0xffffffff);m.wi(target+8,0x80000012);wh(actor+0x5c,case['current']);wh(actor+0x64,1);wh(target+0x5c,case['targetCurrent']);m.wf(actor+0x60,1);wb(context+0xde,case['body']);m.wq(actor+0x358,pending);m.wq(actor+0x300,appearance);m.wq(target+0x3b0,stats)
 wh(stats+0x88,case.get('hp',0))
 for off in [0x318,0x340,0x344,0x348]:m.wi(target+off,0x7f000000)
 m.wq(0x1412df8f8,appearance);m.wq(appearance+0x130,appearance+0x200);m.wq(appearance+0x300,appearance+0x400)
 for p in [record,next_]:
  wb(p,1);m.wi(p+4,0xffffffff);m.wi(p+16,0x80000012);wh(p+8,916);wh(p+10,24);wb(p+12,case['result']);wh(p+20,15);wh(p+22,14);wh(p+24,250);wh(p+26,0);m.wi(p+28,case['ranged']);m.wi(p+32,case.get('killingBlow',1));wb(p+36,1)
 if case['next']:m.wq(record+64,next_)
 w.call(0x1407fc7d0,[actor,9,record,0])if case['mode']=='play'else w.call(0x14080e490,[0,0,record,0])
 rows.append(dict(case=case,commands=commands,record=rec(record),pending=rec(pending),remaining=m.si(actor+0x74),draws=drawIndex))
out=m.root/'backups/animations/native-client-attack-playback-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
