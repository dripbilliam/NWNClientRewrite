"""Untouched ExecuteCommandDoTouchAttack. VM/object lookup, bonus/AC,
defenses, RNG and feedback allocations are captured lower-owner boundaries.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
command,vm,actor,target,statsA,statsT,roundState,attack,vtable,app,message,clientA,clientT=[m.heap+n*0x1000 for n in range(1,14)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x140286160,0x140286110]:wi(y,pops.pop(0));finish(1)
    elif a==0x140286410:outputs.append(y&0xffffffff);finish(1)
    elif a==0x14055b850:finish(app)
    elif a==0x140296470:
        o=actor if y==99 else target if y==100 else 0;wq(z,o);finish(0 if o else 1)
    elif a==m.stop+0x10:finish(x if c.get('actorType',5)==5 and x==actor or c.get('targetType',5)==5 and x==target else 0)
    elif a==m.stop+0x20:finish(x if x in [actor,target] else 0)
    elif a in [0x1404041c0,0x140405b00]:calls.append(['bonus',a==0x140405b00]);finish(c.get('bonus',0)&0xffffffff)
    elif a==0x1403f47f0:calls.append(['ac',99,1]);finish(c.get('ac',10)&65535)
    elif a==0x140390070:calls.append(['ac',None,0]);finish(c.get('ac',10)&65535)
    elif a==0x1402ad680:
        value=c.get('rolls',[10,10])[min(len(rolls),1)];rolls.append(value);calls.append(['roll',value]);finish(value)
    elif a==0x1403e5630:calls.append(['defensive']);finish(c.get('blocked',0))
    elif a==0x140375e40:finish(attack)
    elif a==0x140c10324:finish(message)
    elif a==0x1402da770:feedback.setdefault('objects',{})[str(y)]=z&0xffffffff;finish()
    elif a==0x1402da730:feedback.setdefault('integers',{})[str(y)]=z&0xffffffff;finish()
    elif a==0x14055b390:finish(clientA if y==99 and c.get('clientA',True) else clientT if y==100 and c.get('clientT',True) else 0)
    elif a==0x14055b810:finish(app)
    elif a==0x1404cf090:calls.append(['send',y,z&255,json.loads(json.dumps(feedback))]);finish()
    elif a in [0x14050c920,0x140c10360]:finish()
    elif not 0x140516710<=a<0x140516c11:raise AssertionError(f'Uncaptured {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,pops,calls,outputs,rolls,feedback
    c=case;calls=[];outputs=[];rolls=[];feedback={};pops=[100,c.get('feedback',1),99]
    u.mem_write(m.heap,bytes(0x100000));wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app);wi(command+12,99)
    for obj,kind,stats in [(actor,c.get('actorType',5),statsA),(target,c.get('targetType',5),statsT)]:
        wq(obj,vtable);wi(obj+8,99 if obj==actor else 100);u.mem_write(obj+12,bytes([kind]));wq(obj+0xad0,stats)
    wq(vtable+0x60,m.stop+0x10);wq(vtable+0x20,m.stop+0x20);wq(actor+0x880,roundState);u.mem_write(attack+0x78,bytes([c.get('defenseResult',8)]));u.mem_write(attack+0x58,bytes([c.get('concealment',50)]));u.mem_write(statsT+0xd54,bytes([c.get('enemyBonus',0)&255]));wi(clientA+0x48,99);wi(clientT+0x48,100)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,c.get('ordinal',146),3]):u.reg_write(reg,value)
    u.emu_start(0x140516710,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return {'case':c,'outputs':outputs,'calls':calls}
rows=[]
for ordinal,roll,confirmation,bonus,enemyBonus,blocked in itertools.product([146,147],[1,9,10,20],[1,10],[0,20,-10],[0,127,128],[0,1]):
    rows.append(run(dict(ordinal=ordinal,rolls=[roll,confirmation],bonus=bonus,enemyBonus=enemyBonus,blocked=blocked)))
for actorType,display,hasA,hasT in itertools.product([9,10],[0,1],[False,True],[False,True]):rows.append(run(dict(actorType=actorType,feedback=display,clientA=hasA,clientT=hasT)))
for targetType in [6,9,10]:rows.append(run(dict(targetType=targetType,feedback=0)))
print(json.dumps({'targetSha256':'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a','owner':'ExecuteCommandDoTouchAttack140516710','limits':'Captured lower VM, AC/bonus, defense, RNG and message owners. No end-to-end original spell/network claim.','rows':rows}))
