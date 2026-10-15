"""Read-only native ResistSpell wrapper, raw stats resistance, absorption
and immunity owners. VM, object/metadata/class/feat queries, effect removal,
combat message containers/delivery and RNG are captured lower boundaries.
All owner branches, width/sign arithmetic, draw order, absorption writes and
feedback ordering execute untouched. Wrapper captures immunity responses;
those owners execute independently in the absorption/immunity cases below.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,caster,target,selfAoE,stats,spell,app,rules,table,pool,storage,client,vtable=[m.heap+n*0x1000 for n in range(1,14)]
def owner(ptr):return 99 if ptr==caster else 100 if ptr==target else 101
def message(ptr):return messages.setdefault(ptr,dict(objectIds=[],integers=[]))
def hook(u,a,n,_):
    global output,allocation
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140286160:m.wi(y,arguments.pop(0));m.finish(1)
    elif a==0x140286410:output=y&0xffffffff;m.finish(1)
    elif a==0x14055b4c0:m.finish(caster if y==99 and c.get('casterExists',True) else target if y==100 and c.get('targetExists',True) else selfAoE if y==101 and c.get('selfAoE',False) else 0)
    elif a==m.stop+0x10:m.finish(x if u.mem_read(x+0xc,1)[0]==5 else 0)
    elif a==m.stop+0x20:m.finish(x if u.mem_read(x+0xc,1)[0]>4 else 0)
    elif a==m.stop+0x30:m.finish(x if u.mem_read(x+0xc,1)[0]==11 else 0)
    elif a==m.stop+0x40:m.finish(2)
    elif a==0x1402af4a0:m.finish(spell if c.get('spellExists',True) and not(y==2 and c.get('aoeSpellMissing',False)) else 0)
    elif a==0x140494ee0:calls.append(['level',owner(x)]);m.finish(c.get('casterLevel',3))
    elif a==0x14040b900:m.finish(c.get('featResult',1) if (y&65535) in c.get('feats',[]) else 0)
    elif a==0x140296910:m.finish(int((y&65535) in c.get('feats',[])))
    elif a==0x1402a4130:m.finish(ruleset_value(c.get('rulesOverrides',{}),y,z))
    elif a in [0x140494890,0x140494650] and c['mode']=='resist':calls.append(['absorption' if a==0x140494890 else 'immunity']);m.finish(c.get('absorption' if a==0x140494890 else 'immunity',-1))
    elif a==0x140408dd0 and c['mode']=='resist':calls.append(['resistance']);m.finish(c.get('resistance',10))
    elif a==0x1402ad680:calls.append(['dice',y&255,z&255]);m.finish(c.get('roll',10))
    elif a==0x1403fa4a0:m.finish(c.get('classType',10)&255)
    elif a==0x1402af530:m.finish(c.get('level',1)&255)
    elif a==0x140498280:
        calls.append(['remove',m.q(storage)]);m.wi(target+0x158,0);removed=True;m.finish()
    elif a==0x140c10324:allocation+=1;ptr=m.heap+0x20000+allocation*0x100;messages[ptr]=dict(objectIds=[],integers=[]);m.finish(ptr)
    elif a in [0x1402da770,0x1402da730]:
        key='objectIds' if a==0x1402da770 else 'integers';values=message(x)[key];index=y&0xffffffff
        while len(values)<=index:values.append(0)
        values[index]=z&0xffffffff if key=='objectIds' else z if z<0x80000000 else z-0x100000000;m.finish()
    elif a==0x1402d5210:messages[y]=dict(objectIds=list(message(x)['objectIds']),integers=list(message(x)['integers']));m.finish()
    elif a==0x1403a2480:calls.append(['feedback',owner(x),y&65535,message(z)]);m.finish()
    elif a==0x14055b390:
        m.wi(client+0x48,y);m.finish(client if c.get('clients',True) else 0)
    elif a==0x14055b810:m.finish(app)
    elif a==0x1404cf090:calls.append(['send',y&0xffffffff,z&255,message(w)]);m.finish()
    elif a in [0x14050c920,0x140c10360,0x14037bd50]:m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x14053bb30,0x14053bfe4),(0x140408dd0,0x14040915b),(0x140494650,0x140494d80),(0x1402ae870,0x1402ae899),(0x140423fc0,0x140423fcb),(0x140425210,0x140425242)]):raise AssertionError(f'Uncaptured resistance dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,arguments,output,allocation,messages
    c=case;calls=[];arguments=[99,100];output=None;allocation=0;messages={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,app);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,table);m.wi(command+0xc,101 if c.get('selfAoE') else 99)
    for ptr,id,type in [(caster,99,c.get('casterType',5)),(target,100,c.get('targetType',5)),(selfAoE,101,11)]:
        m.wq(ptr,vtable);m.wi(ptr+8,id);u.mem_write(ptr+0xc,bytes([type]));m.wq(ptr+0xad0,stats);m.wi(ptr+0x218,1);m.wi(ptr+0x820,c.get('override',0));m.wi(ptr+0x824,c.get('overrideLevel',7));u.mem_write(ptr+0x23c,struct.pack('<H',c.get('feat',65535)&65535));u.mem_write(ptr+0x22c,bytes([0]));m.wi(ptr+0x344,c.get('aoeLevel',5))
    for off,func in [(0x60,m.stop+0x10),(0x20,m.stop+0x20),(0xa8,m.stop+0x30),(0x178,m.stop+0x40)]:m.wq(vtable+off,func)
    for off,value in [(0x6f,c.get('innate',1)),(0x184,c.get('userType',1)),(0x29,c.get('school',1))]:u.mem_write(spell+off,bytes([value&255]))
    m.wi(spell+0x178,1);classes=c.get('classes',[]);u.mem_write(stats+0xd8,bytes([len(classes)&255]))
    for i,(type,level) in enumerate(classes):u.mem_write(stats+0x25c+i*0x188,bytes([type&255,level&255]))
    u.mem_write(stats+0xd84,bytes([c.get('increase',0)&255,c.get('decrease',0)&255]));m.wq(target+0x150,pool);m.wi(target+0x158,len(c.get('effects',[])))
    for i,e in enumerate(c.get('effects',[])):
        ptr=storage+i*0x200;ints=ptr+0x100;m.wq(pool+i*8,ptr);m.wq(ptr,i+1);u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wq(ptr+0x48,ints)
        for j,value in enumerate(e['integers']):m.wi(ints+j*4,value)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    modes={'resist':(0x14053bb30,command,0,2),'stats':(0x140408dd0,stats,0,0),'absorption':(0x140494890,target,caster,selfAoE if c.get('selfAoE') else 0),'immunity':(0x140494650,target,caster,selfAoE if c.get('selfAoE') else 0)}
    entry,x,y,z=modes[c['mode']]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[x,y,z]):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=output if c['mode']=='resist' else u.reg_read(UC_X86_REG_RAX)&0xffffffff
    return dict(case=c,result=result if result<0x80000000 else result-0x100000000,calls=calls,effects=[dict(type=e['type'],integers=[m.si(storage+i*0x200+0x100+j*4) for j in range(len(e['integers']))]) for i,e in enumerate(c.get('effects',[]))] if m.si(target+0x158)>0 else [])
rows=[]
for resistance,roll,feat,override,userType in itertools.product([0,1,10,127,128,255],[1,10,20],[65535,12],[0,1,2],[1,2,3]):rows.append(run(dict(mode='resist',resistance=resistance,roll=roll,feat=feat,override=override,userType=userType)))
for key,values in [('casterExists',[False]),('targetExists',[False]),('spellExists',[False]),('casterType',[3,6,9,11]),('targetType',[6,9,11]),('absorption',[0,1,2,3]),('immunity',[0,2]),('feats',[[36],[401,36],[618,401,36]]),('featResult',[2]),('clients',[False]),('selfAoE',[True])]:
    for value in values:rows.append(run(dict(mode='resist',**{key:value})))
for level,increase,decrease,tier,lower in itertools.product([0,20,255],[0,10,127,128,255],[0,20,128,255],[0,1,10],[0,1]):rows.append(run(dict(mode='stats',classes=[[5,level]],increase=increase,decrease=decrease,feats=[215]+([698+tier] if tier else []),rulesOverrides={'MONK_SPELL_RESISTANCE_CAN_BE_LOWERED':lower})))
rows.append(run(dict(mode='stats',feats=[215],classes=[])));rows.append(run(dict(mode='stats',feats=[699,708],rulesOverrides={'EPIC_SPELL_RESISTANCE_10':200})))
for mode,cap,budget,school,spellLevel,kind in itertools.product(['absorption'],[0,1,9],[0,1,10],[0,1,2],[0,1,9],[0,1,2]):rows.append(run(dict(mode=mode,level=spellLevel,effects=[dict(type=65,integers=[cap,budget,school,kind])])))
for value,spellExists,targetType in itertools.product([-1,0,1,2],[False,True],[5,6]):rows.append(run(dict(mode='immunity',spellExists=spellExists,targetType=targetType,effects=[dict(type=50,integers=[value])])))
out=m.root/'backups/animations/native-spell-resistance-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
