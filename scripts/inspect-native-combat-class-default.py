"""Complete original base CNWCCreatureStats constructor7ea230 and near-range
selector80ffd0/GetClass7f0f60. Constructor lower allocation, array-element setup,
TLK/ResRef, rule lookup and CombatInformation are captured boundaries; the
physical class-count/id/level writes execute unchanged. Near-selector equipment,
target/model queries and CRT random boundaries retain the existing oracle's
scope, but GetClass now executes its complete original body against real slots.
No original server/renderer/client object creation or canonical stats claim.
"""
from pathlib import Path
import sys,importlib,json,struct,itertools,hashlib
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
stats=m.heap+0x10000;cursor=m.heap+0x60000;rule=8;calls=[]
def hook(u,address,size,_):
    global cursor
    if address==m.stop:u.emu_stop();return
    if 0x1407ea230<=address<=0x1407ea6fe or 0x1407f0f60<=address<=0x1407f0fc5:return
    x,y,z,w=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if address==0x140c10370:m.finish()
    elif address in [0x140c10324,0x140c10368]:
        pointer=cursor;cursor+=(max(x,1)+15)&~15;assert cursor<m.heap+0xf0000
        u.mem_write(pointer,bytes(max(x,1)));m.finish(pointer)
    elif address==0x140c11414:
        calls.append(dict(kind='class-array-element-constructors',size=y,count=z,constructor=hex(w)))
        u.mem_write(x,bytes(y*z));m.finish()
    elif address==0x1401994d0:
        calls.append(dict(kind='TLK',ref=z));u.mem_write(y,bytes(24));m.finish(y)
    elif address==0x14018ded0:u.mem_write(x,bytes(16));m.finish(x)
    elif address==0x14084c170:u.mem_write(x,bytes(32));m.finish(x)
    elif address==0x1402ae870:m.finish(1)
    elif address==0x1402a4130:calls.append(dict(kind='ruleset-minimum',value=rule));m.finish(rule)
    elif address==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x)
    elif address==0x1402a22b0:u.mem_write(x,bytes(0x70));m.finish(x)
    else:raise RuntimeError('Unmapped original constructor dependency '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,args):
    rsp=m.stack+0x1fe08;u.mem_write(m.stack,bytes(0x20000));m.wq(rsp,m.stop)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
    u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(address,m.stop,count=100000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return u.reg_read(UC_X86_REG_RAX)
constructors=[]
for rule in [-4,8,20]:
    cursor=m.heap+0x60000;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(stats,bytes([0xa5])*0xc38)
    invoke(0x1407ea230,[stats])
    count=u.mem_read(stats+0x69,1)[0]
    classes=[dict(id=invoke(0x1407f0f60,[stats,index])&255,level=u.mem_read(stats+0x296+index*0x150,1)[0])for index in range(8)]
    assert count==1 and classes==[dict(id=4,level=1)]+[dict(id=255,level=0)]*7
    constructors.append(dict(ruleMinimum=rule,count=count,physicalSlots=classes,capturedCalls=calls))
source=root/'scripts/inspect-native-client-combat-animation.py'
prefix=source.read_text().split('cases=[]',1)[0]
needle="elif a==0x1407f0f60:finish(5 if case['monk'] else 0)"
assert needle in prefix
prefix=prefix.replace(needle,'elif 0x1407f0f60<=a<=0x1407f0fc5:return')
scope={'__name__':'native_near_class_slots','__file__':str(source)};exec(compile(prefix,str(source),'exec'),scope)
exec('''
def exercise(row):
 global cursor,state,draws,case
 case=row;cursor=heap+0x10000;state=case['seed'];draws=0;uc.mem_write(heap,bytes(0x10000))
 wq(0x1412df970,app);wq(app,app+0x100);wq(0x1412df8f8,app);wq(app+0x130,app+0x200);wq(app+0x220,app+0x300)
 wq(actor+0x78,context);wb(actor+0x170,case['side']);wi(actor+8,21);wq(actor+0x3b0,stats);wb(stats+0x69,len(case['classes']))
 for index,cls in enumerate(case['classes']):wb(stats+0x295+index*0x150,cls)
 for k,v in enumerate(case['position']):uc.mem_write(actor+0x38+k*4,struct.pack('<f',v))
 wq(target,vt);wq(vt+0x18,stop+0x10);wq(vt+0x58,stop+0x20);wq(target+0x300,stats);wi(target+0x3a8,case['lockTarget'])
 for k,v in enumerate(case['orientation']):uc.mem_write(target+0x44+k*4,struct.pack('<f',v))
 wb(context+0xdd,case['style']);wb(context+0xe0,case['side']);wi(actor+0x318,100 if case['weapon'] else 0x7f000000);wi(actor+0x31c,0x7f000000)
 wi(weapon+0x40,22);wb(info+0x35,case['slashLeft']);wb(info+0x36,case['slashRight'])
 wh(out,9);wh(record+0x16,case['reaction']);wi(record+0x10,22);wb(record+0x24,1)
 rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));wq(rsp,stop)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,out,record]):uc.reg_write(reg,value)
 uc.reg_write(UC_X86_REG_RSP,rsp);uc.emu_start(0x14080ffd0,stop,count=20000)
 assert uc.reg_read(UC_X86_REG_RIP)==stop
 return dict(case=case,animation=int.from_bytes(uc.mem_read(out,2),'little'),reaction=int.from_bytes(uc.mem_read(record+0x16,2),'little'),side=uc.mem_read(actor+0x170,1)[0],contextSide=uc.mem_read(context+0xe0,1)[0],draws=draws)
''',scope)
rows=[]
for classes,side,weapon,seed in itertools.product([[],[4],[5],[4,5],[5,4],[4]*7+[5],[255]],range(3),[0,1],[1,17]):
    case=dict(classes=classes,branch=2,side=side,style=1,weapon=weapon,shield=0,seed=seed,slashLeft=50,slashRight=50,validBase=1,targetCreature=1,targetBase=0,lockTarget=21,height='H',position=[1,0,0],orientation=[1,0,0],reaction=1)
    rows.append(scope['exercise'](case))
output=root/'godot-client/reports/native-combat-class-default-original-v1.json'
output.write_text(json.dumps(dict(success=True,binarySha256=m.digest,scope=__doc__,constructorCases=constructors,selectorCases=rows,selectorHarnessSha256=hashlib.sha256(source.read_bytes()).hexdigest()),indent=2)+'\n')
print(json.dumps(dict(success=True,constructorCases=len(constructors),selectorCases=len(rows),output=str(output))))
