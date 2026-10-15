"""Untouched ComputeSpellSaveDC1403861c0. Class/feat/effect/ability queries
are captured lower-owner boundaries; all branches, BYTE arithmetic, focus
selection, ruleset defaults and final signed INT calculation run unchanged.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq=[getattr(m,n) for n in ['q','si','wi','wq']]
actor,stats,spell,rules,classRules,effectList,effectStorage=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x1402af4a0:m.finish(spell if c.get('spellExists',True) and not(c.get('masterMissing') and (y&0xffffffff)==2) else 0)
    elif a==0x140409520:m.finish(c.get('modifier',3)&255)
    elif a==0x1403fa4a0:m.finish(c.get('classType',10)&255)
    elif a==0x1403fa5b0:m.finish(c.get('penalty',0)&255)
    elif a==0x1402af530:m.finish(c.get('level',1)&255)
    elif a==0x14040b900:m.finish(c.get('featResult',1) if (y&65535) in c.get('feats',[]) else 0)
    elif a==0x1402a4130:
        m.finish(ruleset_value(c.get('rulesOverrides',{}),y,z))
    elif a==0x140401b30:m.finish(c.get('sourceType',10))
    elif a==0x140402dc0:m.finish(c.get('sourceIndex',0))
    elif a==0x1403fa4f0:m.finish(c.get('classLevel',3)&255)
    elif a==0x1403f4380:abilityCalls.append(y&255);m.finish(c.get('abilityMods',[0,1,2,3,4,5])[y&255] if (y&255)<=5 else 0)
    elif a==0x140423fc0:m.finish(c.get('effectFlag',1) if y==5 else c.get('effectAbility',5))
    elif not (0x1403861c0<=a<0x1403866f8 or 0x1402ae870<=a<0x1402ae899):raise AssertionError(f'Uncaptured save DC dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,abilityCalls
    c=case;abilityCalls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0xd0,rules);wq(rules+0x110,classRules);wq(actor+0xad0,stats)
    wi(actor+0x820,c.get('override',0));wi(actor+0x97c,c.get('equipment',0));wi(actor+0x9e8,c.get('overrideSpell',1));wi(actor+0x9ec,-1);wi(actor+0x9f0,-1)
    u.mem_write(actor+0x22c,bytes([c.get('class',0)&255]));u.mem_write(actor+0x21c,bytes([c.get('domain',0)&255]));u.mem_write(actor+0x23c,struct.pack('<H',c.get('feat',65535)&65535))
    u.mem_write(spell+0x6f,bytes([c.get('innate',1)&255]));u.mem_write(spell+0x29,bytes([c.get('school',0)&255]));wi(spell+0x178,2)
    u.mem_write(stats+0xd43,bytes([c.get('abilityMods',[0,1,2,3,4,5])[5]&255]))
    slot=c.get('sourceIndex',0)&255;u.mem_write(classRules+slot*0x530+0x4e8,bytes([c.get('classAbility',3)&255]));u.mem_write(classRules+slot*0x530+0x49a,bytes([c.get('primaryAbility',0)&255]))
    if c.get('effects'):
        wq(actor+0x150,effectList);wi(actor+0x158,len(c['effects']))
        for i,type in enumerate(c['effects']):wq(effectList+i*8,effectStorage+i*0x100);u.mem_write(effectStorage+i*0x100+8,struct.pack('<H',type&65535))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,1)
    u.emu_start(0x1403861c0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
    return dict(case=c,result=result if result<0x80000000 else result-0x100000000,abilityCalls=abilityCalls)
rows=[]
for school,tier,modifier,level,penalty in itertools.product(range(9),[0,1,2,3],[-128,-1,0,3,127],[0,1,9,255],[0,1,255]):
    feats=[] if tier==0 or school==0 else [609+school] if tier==3 else [392+school] if tier==2 else [35 if school==1 else 164+school]
    rows.append(run(dict(school=school,feats=feats,modifier=modifier,level=level,penalty=penalty)))
for cls,feat,override,equipment in itertools.product([0,254,255],[65535,12],[0,1,2],[0,1]):rows.append(run(dict(**{'class':cls},feat=feat,override=override,equipment=equipment)))
for effects,flag,ability in itertools.product([[],[18],[62],[18,62],[62,62]],[0,1,2],[-1,0,1,2,3,4,5,6,255]):rows.append(run(dict(equipment=1,effects=effects,effectFlag=flag,effectAbility=ability)))
for key,values in [('domain',[1,9,255]),('innate',[0,255]),('spellExists',[False]),('overrideSpell',[2]),('classAbility',[0,5,255]),('featResult',[2])]:
    for value in values:rows.append(run(dict(equipment=key=='classAbility',school=1,feats=[610,393,35],**{key:value})))
rows.append(run(dict(school=1,feats=[610,393,35],rulesOverrides={'FEAT_EPIC_SPELL_FOCUS_BONUS':-100})))
out=m.root/'backups/animations/native-spell-save-dc-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
