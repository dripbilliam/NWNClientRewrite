"""Untouched ordinary AIActionCastSpell, captured lower owners.
Synthetic spell/rules/eligibility/time/LOS/round/presentation/impact boundaries.
Includes counterspellers and feat readiness/weapon/release consumption. Not a full spell effect
or full action parity claim; unobserved branches remain explicit dependencies.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
actor,target,stats,node,rules,spells,app,spell,roundState,vtable,area,clock,allocated=[m.heap+n*0x1000 for n in range(1,14)]
counterObjects={101+i:m.heap+0x30000+i*0x1000 for i in range(3)}
counterRounds={101+i:m.heap+0x80000+i*0x4000 for i in range(3)}
def record(pointer,entry):
    id=next((id for id,ptr in (counterRounds if pointer in counterRounds.values() else counterObjects).items() if ptr==pointer),None)
    calls.append(['counter',id,*entry] if id is not None else entry)
ranges=[(0x1403ada70,0x1403b0505),(0x1402ae870,0x1402ae899)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140c10370:finish()
    elif a==0x1404953b0:calls.append(['dead']);finish(c.get('dead',0))
    elif a==0x140495620:calls.append(['dying']);finish(c.get('dying',0))
    elif a==m.stop+0x10:record(x,['lock',y&0xffffffff]);finish()
    elif a==m.stop+0x20:record(x,['animation',y&65535]);finish()
    elif a==m.stop+0x30:finish(target)
    elif a==m.stop+0x40:finish(actor if x==actor else target if c.get('targetType',5)==5 else 0)
    elif a==m.stop+0x50:finish(0)
    elif a==0x1402af4a0:finish(spell if c.get('spellExists',True) and not(c.get('masterMissing') and (y&0xffffffff)!=1) else 0)
    elif a==0x1403fa4a0:finish(10)
    elif a==0x1402af530:finish(c.get('level',1)&255)
    elif a==0x140409160:calls.append(['uses',y&0xffffffff,z&255,w&255,si(rsp+0x28)&255]);finish(c.get('uses',1))
    elif a==0x1404012f0:calls.append(['featUses',y&65535]);finish(c.get('featUses',1))
    elif a==0x1403f2750:calls.append(['decrementFeat',y&65535]);finish()
    elif a==0x140462bd0:calls.append(['equipped',y&0xffffffff]);finish(m.heap+0xf000 if c.get('weapon') is not None else 0)
    elif a==0x1404095d0:finish(c.get('ready',1))
    elif a==0x140405770:finish(len(c.get('slots',[]))&255)
    elif a in [0x140404db0,0x140402ff0,0x140404c70,0x140404aa0]:
        row=c.get('slots',[])[w&255];key={0x140404db0:'ready',0x140402ff0:'domain',0x140404c70:'metamagic',0x140404aa0:'id'}[a];finish(row.get(key,0) if row else 0)
    elif a==0x14040b900:finish(int((y&65535) in c.get('feats',[])))
    elif a==0x140402f80:finish(0)
    elif a==0x14037cc30:calls.append(['activityManager',y&0xffffffff]);finish()
    elif a==0x140382eb0:calls.append(['opportunity',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x1402af4d0:finish(c.get('somatic',1))
    elif a==0x1402af500:finish(c.get('verbal',1))
    elif a==0x140408100:calls.append(['spellFailure',y&255]);finish(c.get('failureBySchool',{}).get(str(y&255),0)&255)
    elif a==0x1402ad680:
        sides=z&255;draw=len([v for v in calls if v[0]=='roll']);value=c.get('rolls',[100,100])[min(draw,len(c.get('rolls',[100,100]))-1)]
        calls.append(['roll',sides]);finish(value)
    elif a==0x140406a40:calls.append(['skill',y&255,z&0xffffffff,w&0xffffffff]);finish(c.get('concentrationRank',0)&255)
    elif a==0x140392220:calls.append(['nearestEnemy',m.xmm(UC_X86_REG_XMM1),z&0xffffffff,w&0xffffffff,si(rsp+0x28)]);finish(c.get('enemy',0x7f000000))
    elif a==0x140c10324:finish(allocated)
    elif a==0x1404233d0:u.mem_write(allocated,bytes(0x200));finish(allocated)
    elif a==0x140425110:calls.append(['visualCreator',y&0xffffffff]);finish()
    elif a==0x140425210:calls.append(['visualInteger',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x14048e350:calls.append(['visualApply']);finish()
    elif a==0x1403ab1a0:message.clear();finish(allocated)
    elif a==0x1402da770:message.setdefault('objects',{})[str(y&0xffffffff)]=z&0xffffffff;finish()
    elif a==0x1402da730:message.setdefault('integers',{})[str(y&0xffffffff)]=z&0xffffffff;finish()
    elif a==0x140384150:calls.append(['skillMessage',json.loads(json.dumps(message))]);finish()
    elif a==0x1402a3f70:finish(c.get('metaCost',4 if (y&255)==8 else 0))
    elif a==0x14055b4c0:finish(target if (y&0xffffffff)==100 and c.get('targetExists',True) else 0)
    elif a==0x14055b3d0:finish(counterObjects.get(y&0xffffffff,0) if (y&0xffffffff) not in c.get('counterMissing',[]) else 0)
    elif a==0x1402a4130:
        finish(ruleset_value(c.get('rulesOverrides',{}),y,z)&0xffffffff)
    elif a==0x1402a40d0:
        default=m.xmm(UC_X86_REG_XMM2)
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',ruleset_value(c.get('rulesOverrides',{}),y,default)),'little'));finish()
    elif a==0x140384300:calls.append(['broadcast',y&0xffffffff,z&255,w&65535]);finish()
    elif a==0x14037a000:record(x,['startRound',y&0xffffffff]);wi(x+0x2f04,1);finish()
    elif a==0x140375a30:record(x,['decrementRound',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x140379c70:record(x,['pause',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x140379c30:record(x,['pauseTimer',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x1403766e0:record(x,['spellPending']);finish(c.get('counterPending',1))
    elif a==0x140378f80:record(x,['removeSpellAction']);finish()
    elif a==0x14055b2c0:finish(clock)
    elif a==0x140597180:wi(y,0);wi(z,c.get('elapsed',0));finish()
    elif a==0x14055ba10:finish(clock)
    elif a==0x140597a20:wi(q(rsp+0x30),0);wi(q(rsp+0x38),c.get('elapsed',0));finish(0)
    elif a==0x140494e80:finish(area)
    elif a==0x14035c590:calls.append(['los']);finish(c.get('los',1))
    elif a==0x14038a590:record(x,['consume',y&0xffffffff,z&255,w&255,si(rsp+0x28)&255,si(rsp+0x30)&255]);finish(c.get('counterConsume',{}).get(str(si(x+8)),1) if x in counterObjects.values() else c.get('consume',1))
    elif a==0x14048fe20:record(x,['projectileTime',y&255]);finish()
    elif a==0x14049c4b0:
        calls.append(['impact',y&0xffffffff,*struct.unpack('<3f',u.mem_read(z,12)),w&0xffffffff,si(rsp+0x28)&255,si(rsp+0x30)&0xffffffff,si(rsp+0x38)&0xffffffff,si(rsp+0x40)&0xffffffff,si(rsp+0x48)&255,si(rsp+0x50)&0xffffffff]);wi(actor+0x224,1);finish()
    elif a==0x14048f270:
        calls.append(['fakeImpact',y&0xffffffff,z&0xffffffff,list(struct.unpack('<3f',u.mem_read(w,12))),list(struct.unpack('<3f',u.mem_read(q(rsp+0x28),12))),si(rsp+0x30)&0xffffffff,si(rsp+0x38)&255,si(rsp+0x40)&0xffffffff,si(rsp+0x48)&255,si(rsp+0x50)&255]);finish()
    elif a==0x14039ecb0:calls.append(['removeRoundSpell']);finish()
    elif a==0x14039be00:calls.append(['pendingEquipment']);finish()
    elif a==0x1403a2480:record(x,['feedback',y&0xffffffff]);finish()
    elif a==0x1403a2f60:calls.append(['combatState',y&0xffffffff]);finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured cast action dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,message
    c=case;calls=[];message={};u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0xd0,spells);wq(rules+0x110,m.heap+0x50000);wq(rules+0x120,m.heap+0x70000);wq(0x1412df970,app);wq(app+8,app)
    for addr in [0x14141e310,0x14141e311]:u.mem_write(addr,b'\0')
    wq(actor+0xad0,stats);wq(actor+0x880,roundState);wi(actor+8,99);wi(target+8,100);wq(actor,vtable);wq(target,vtable)
    for offset,address in [(0x188,m.stop+0x10),(0x100,m.stop+0x20),(0x20,m.stop+0x30),(0x60,m.stop+0x40),(0x70,m.stop+0x50)]:wq(vtable+offset,address)
    wi(actor+0x81c,c.get('consumed',0));wi(actor+0x224,c.get('impactDone',0));wi(actor+0x760,c.get('haste',0));wi(roundState+0x2f04,c.get('started',0));u.mem_write(actor+0x8d4,struct.pack('<H',c.get('componentFlags',65535)));wi(actor+0xa0,88);wi(actor+0x700,c.get('combatState',0))
    for i,id in enumerate((c.get('counters',[])+[0x7f000000]*10)[:10]):wi(actor+0x310+i*4,id)
    wi(actor+0x338,c.get('counterCount',sum(id!=0x7f000000 for id in c.get('counters',[]))))
    for id,ptr in counterObjects.items():
        wq(ptr,vtable);wi(ptr+8,id);wq(ptr+0x880,counterRounds[id]);wi(ptr+0x7fc,9);u.mem_write(ptr+0x800,bytes([1,16,3]));wi(ptr+0x81c,0)
    u.mem_write(actor+0xa4,struct.pack('<3f',0,0,0));u.mem_write(target+0xa4,struct.pack('<3f',2,0,0));wi(spell+0x178,c.get('master',1));u.mem_write(spell+0x6f,b'\1');wi(spell+0x70,c.get('conjure',1500));u.mem_write(spell+0x74,struct.pack('<H',c.get('conjureAnim',1)));u.mem_write(spell+0xdc,struct.pack('<H',c.get('castAnim',1)));wi(spell+0xe0,c.get('castTime',500));u.mem_write(spell+0x184,bytes([c.get('userType',1)]));u.mem_write(spell+0x18c,bytes([c.get('allowedMeta',63)&255]))
    u.mem_write(spell+0x29,bytes([c.get('school',0)&255]));wi(m.heap+0x50000+10*0x530+0x504,c.get('arcane',0))
    for off,key in [(0xd78,'effectFailure'),(0xd79,'chestFailure'),(0xd7a,'shieldFailure')]:u.mem_write(stats+off,bytes([c.get(key,0)&255]))
    u.mem_write(actor+0x6ef,bytes([c.get('combatMode',0)&255]));wi(spell+0x174,c.get('useConcentration',0));wi(spell+0x188,c.get('convertible',0))
    if c.get('concentrationEffect'):
        wq(actor+0x150,m.heap+0x60000);wi(actor+0x158,1);wq(m.heap+0x60000,m.heap+0x61000);u.mem_write(m.heap+0x61000+8,struct.pack('<H',18))
    wi(m.heap+0xf000+0x40,c.get('weapon') or 0)
    flags=(0x40000000 if c.get('instant') else 0)|(0x80000000 if c.get('cheat') else 0);parameters=[1,c.get('class',0),c.get('domain',0),c.get('meta',0),c.get('spontaneous',0),100,0,0,0,flags,c.get('feat',-1),255]
    for index,value in enumerate(parameters):wq(node+0x38+index*8,value&0xffffffffffffffff)
    wi(node+0x9c,c.get('nodeReady',1));rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,node,0,0]):u.reg_write(reg,value)
    u.emu_start(0x1403ada70,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    offsets=[0x214,0x218,0x224,0x228,0x740,0x748,0x818,0x81c]
    result=dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,fields={hex(off):si(actor+off)&0xffffffff for off in offsets},domain=int.from_bytes(u.mem_read(actor+0x21c,1),'little'),classIndex=int.from_bytes(u.mem_read(actor+0x22c,1),'little'),metamagic=int.from_bytes(u.mem_read(actor+0x22d,1),'little'),feat=int.from_bytes(u.mem_read(actor+0x23c,2),'little'),nodeReady=si(node+0x9c),started=si(roundState+0x2f04))
    if 'counters' in c:result.update(counterCount=si(actor+0x338),counterIds=[si(actor+0x310+i*4)&0xffffffff for i in range(10)],counterState={str(id):{'id':si(ptr+0x218)&0xffffffff,'target':si(ptr+0x214)&0xffffffff,'impact':si(ptr+0x224),'consumed':si(ptr+0x81c),'started':si(counterRounds[id]+0x2f04)} for id,ptr in counterObjects.items()})
    return result
rows=[]
for elapsed,haste,meta,instant in itertools.product([0,499,500,749,750,1499,1500,1999,2000,2499,2500],[0,1],[0,8],[False,True]):rows.append(run(dict(elapsed=elapsed,haste=haste,meta=meta,instant=instant)))
for key,values in [('class',[254,255]),('dead',[1]),('dying',[1]),('uses',[0]),('targetExists',[False]),('consume',[0]),('los',[0]),('spellExists',[False]),('nodeReady',[0]),('impactDone',[1]),('started',[1]),('conjureAnim',[2]),('castAnim',[2,3,4,5,6,7,8,9])]:
    for value in values:rows.append(run(dict(elapsed=2000,**{key:value})))
for flags,meta,somatic,verbal in itertools.product([0,4,8,12,65535],[0,16,32,48,256,288],[0,1],[0,1]):rows.append(run(dict(elapsed=0,componentFlags=flags,meta=meta,somatic=somatic,verbal=verbal)))
for feats,level,meta,userType,flags in itertools.product([[863],[864],[865],[860],[861],[862],[863,860]],[0,3,4,6,7,9,10],[0,16,32,48],[0,1],[0,4,8]):rows.append(run(dict(elapsed=0,feats=feats,level=level,meta=meta,userType=userType,componentFlags=flags)))
for meta,allowed,consumed in itertools.product([0,16,32],[0,1,16,32],[0,1]):rows.append(run(dict(elapsed=0,meta=meta,allowedMeta=allowed,consumed=consumed)))
for consumed in [0,1]:rows.append(run(dict(elapsed=0,master=2,masterMissing=True,consumed=consumed)))
for domain,cost,flags,userType in itertools.product([0,3,4,255,256],[0,4,256],[0,4,8],[0,1]):rows.append(run(dict(elapsed=0,domain=domain,metaCost=cost,componentFlags=flags,userType=userType,feats=[863,860])))
for cap in [-1,0,3,4,20]:rows.append(run(dict(elapsed=0,level=3,componentFlags=8,feats=[863],rulesOverrides={'EPIC_AUTOMATIC_LESSER_STILL_LEVEL_CAP':cap})))
for arcane,chest,effect,roll,meta,somatic in itertools.product([0,1],[0,25,100,127,128,255],[-40,0,40],[1,25,26,100],[0,32,48],[0,1]):
    rows.append(run(dict(elapsed=1500,arcane=arcane,chestFailure=chest,effectFailure=effect,rolls=[roll,roll],meta=meta,somatic=somatic)))
for userType,flags,meta,school,roll in itertools.product([0,1],[12,28],[0,16,48],[0,1,8,9],[1,20,21,40,41,100]):
    rows.append(run(dict(elapsed=1500,userType=userType,componentFlags=flags,meta=meta,school=school,failureBySchool={'0':10,'1':40,'8':30},rolls=[roll])))
for feats,level,meta,haste,elapsed in itertools.product([[857],[858],[859],[857,859]],[3,4,6,7,9,10,255],[0,8],[0,1],[499,500,1000]):
    rows.append(run(dict(feats=feats,level=level,meta=meta,haste=haste,elapsed=elapsed)))
for mode,feats,rank,roll,enemy in itertools.product([0,9], [[],[7],[696]],[0,10,14,15,20,127,128,255],[1,14,15,20],[0x7f000000,100]):
    rows.append(run(dict(elapsed=1500,combatMode=mode,feats=feats,concentrationRank=rank,rolls=[roll,100],enemy=enemy)))
for instant,rank,roll,concentration in itertools.product([False,True],[0,14,15,128,255],[1,14,15,20],[0,1]):
    rows.append(run(dict(elapsed=1500,instant=instant,useConcentration=concentration,concentrationEffect=True,concentrationRank=rank,rolls=[roll,100])))
for cap in [0,1,3,4,7,10]:rows.append(run(dict(elapsed=500,level=3,feats=[857],rulesOverrides={'EPIC_AUTOMATIC_LESSER_QUICKEN_LEVEL_CAP':cap})))
for value in [0,1,250,750,2000]:rows.append(run(dict(elapsed=500,meta=8,rulesOverrides={'QUICKENED_SPELL_MINIMUM_CONJURE_TIME':value,'FAST_SPELLCAST_ROUND':5000})))
rows.append(run(dict(elapsed=1500,combatMode=9,concentrationRank=20,rolls=[1,100],enemy=100,rulesOverrides={'DEFENSIVE_CASTING_BASE_DC':30,'CONCENTRATION_CHECK_RANGE':8.5,'CONCENTRATION_CHECK_MELEE_PENALTY':7})))
for elapsed,requested,uses,convertible,ready,consumed,consume in itertools.product([0,1500],[0,1,2],[0,1],[0,1],[0,1],[0,1],[0,1]):
    rows.append(run(dict(elapsed=elapsed,spontaneous=requested,uses=uses,convertible=convertible,ready=ready,consumed=consumed,consume=consume,
      slots=[None,dict(id=7,ready=1,domain=1,metamagic=2),dict(id=8,ready=0,domain=0,metamagic=4),dict(id=9,ready=1,domain=0,metamagic=16)])))
for slots in [[],[None],[dict(id=8,ready=256,domain=0,metamagic=0)],[dict(id=9,ready=1,domain=1,metamagic=0)]]:
    rows.append(run(dict(elapsed=1500,spontaneous=1,slots=slots)))
for elapsed,meta,haste,instant,cheat in itertools.product([0,1500,2000,2500],[0,8],[0,1],[False,True],[False,True]):
    rows.append(run(dict(elapsed=elapsed,meta=meta,haste=haste,instant=instant,cheat=cheat,counters=[101,0x7f000000,102])))
for case in [dict(los=0),dict(consume=0),dict(combatMode=9,concentrationRank=0,rolls=[1]),dict(concentrationEffect=True,useConcentration=1,rolls=[1]),dict(arcane=1,chestFailure=100,rolls=[1]),dict(failureBySchool={'0':100},rolls=[1]),dict(counterConsume={'101':0}),dict(counterConsume={'101':0,'102':0}),dict(counterMissing=[101]),dict(counterMissing=[101,102]),dict(counterPending=0),dict(counterPending=2),dict(impactDone=1),dict(dead=1),dict(targetExists=False)]:
    rows.append(run(dict(elapsed=2000,counters=[101,0x7f000000,102],**case)))
for feat,elapsed,consumed,remaining,weapon,index in itertools.product([257,450,454,455,65535,65536],[0,1499,1500,2000,2500],[0,1],[0,1],[None,8,11,22],[0,255]):
    rows.append(run(dict(feat=feat,elapsed=elapsed,consumed=consumed,featUses=remaining,weapon=weapon,**{'class':index})))
out=m.root/'backups/animations/native-cast-action-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
