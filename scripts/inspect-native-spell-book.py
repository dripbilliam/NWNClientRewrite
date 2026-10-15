"""Read-only original spell resource owners, EE89.8193.37-17.
Uses/slots/readiness/talent/gain bodies execute unchanged. Captured helpers:
spell/class rule lookup, spell level, minimum ability, feat ownership, domain
confirmation, VM stack, ability getters/bonuses, class gain and CRT allocation.
GFF readers/formatting and memo-slot refresh are also captured for import;
lower AddKnown/SetSlot bodies execute. These synthetic boundaries validate
owner ordering/widths, not full casting.
"""
import importlib.util,itertools,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
stats,actor,rules,spellArray,vm,app=[m.heap+n*0x1000 for n in range(1,7)];classDefs=m.heap+0x20000;spellBase=m.heap+0xa0000;allocateBase=m.heap+0xc0000
ranges=[(0x140409160,0x14040951e),(0x140415c00,0x140415f64),(0x140416610,0x1404167c5),
        (0x140405110,0x1404054e7),(0x1403faab0,0x1403fae6e),(0x1404026a0,0x1404027c0),
        (0x1405257e0,0x140525af0),(0x140408120,0x1404085dc),
        (0x140404ef0,0x140404f76),(0x1404095d0,0x140409678),
        (0x14040f3e0,0x14040f7ea),(0x1403ef2e0,0x1403ef43e),
        (0x140416eb0,0x1404171d9),(0x140416b00,0x140416b62),(0x140415b80,0x140415bff),
        (0x14038a590,0x14038a5c8),(0x140408aa0,0x140408ae4),(0x1403f00a0,0x1403f02d5)]
scoreHelpers=[0x140406930,0x1403fd3e0,0x1403fa0f0,0x140402d10,0x14040b5e0,0x1403fa050]
bonusHelpers=[0x14040a9f0,0x14040a8e0,0x14040a8a0,0x14040a920,0x14040aa30,0x14040a860]
costs={1:2,2:1,4:3,8:4,16:1,32:1}

def alloc(n):
    global allocation
    ptr=allocateBase+allocation;allocation+=(n+15)&~15;assert allocation<0x30000;return ptr
def spellid(ptr):return (ptr-spellBase)//0x200
def rawresize(index,level,count):
    ci=stats+0xe0+index*0x188;at=ci+0xa0+level*16;old=si(at+8);capacity=si(at+12)
    if count>capacity:
        capacity=max(16,capacity)
        while capacity<count:capacity*=2
        ptr=alloc(capacity*8);u.mem_write(ptr,bytes(u.mem_read(q(at),old*8)) if old else bytes(capacity*8));wq(at,ptr);wi(at+12,capacity)
    if count>old:
        for slot in range(old,count):wq(q(at)+slot*8,0)
    wi(at+8,count)
def node(value):
    token=len(nodes)+1;nodes[token]=value;return token
def string(ptr):return bytes(u.mem_read(ptr,128)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,_):
    global pushed
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1402af4a0:finish(spellBase+(y&0xffffffff)*0x200 if (y&0xffffffff)<64 and not(c.get('missingMaster') and y==2) else 0)
    elif a==0x1402af530:finish(c.get('level',1) if (y&255)!=255 and not(c.get('unavailableFirst') and (y&255)==0) else 255)
    elif a==0x1402a3f70:finish(c.get('costs',{}).get(str(y&255),costs.get(y&255,0))&255)
    elif a==0x140408b70:finish(int(c.get('admit',True)))
    elif a==0x14040b900:finish(int(c.get('feat',True)))
    elif a==0x1403f24d0:finish(int(c.get('domain',False)))
    elif a==0x1403f2580:finish(int(c.get('domain',False)))
    elif a==0x1403d54d0:finish(int(c.get('possessed',False)))
    elif a in [0x140405730,0x140403420,0x140409680]:
        index=y&255;level=z&255;pool=c['pools'][index][level] if index<len(c['pools']) and level<10 else []
        if a==0x140405730:finish(len(c.get('known',[1]))&65535)
        elif a==0x140403420:finish(c.get('known',[1])[w&255] if (w&255)<len(c.get('known',[1])) else 0xffffffff)
        else:finish(c.get('uses',3)&255)
    elif a==0x140115890:warnings.append('warning');finish()
    elif a==0x14016afb0:
        data=(string(z)+str(w&0xffffffff)).encode('ascii');ptr=alloc(len(data)+1);u.mem_write(ptr,data+b'\0');wq(x,ptr);wi(x+8,len(data));wi(x+12,len(data)+1);finish(x)
    elif a==0x1401a02c0:
        data=nodes.get(si(z),{});value=data.get(string(w)) if isinstance(data,dict) else None
        if isinstance(value,list):wi(y,node(value));finish(1)
        else:finish(0)
    elif a==0x1401a0370:finish(len(nodes[si(y)]))
    elif a==0x1401a03f0:
        data=nodes[si(z)];value=data[w&0xffffffff] if (w&0xffffffff)<len(data) else None
        if value is not None:wi(y,node(value));finish(1)
        else:finish(0)
    elif a in [0x1401a1950,0x1401a0f60,0x1401a0ee0]:
        data=nodes[si(y)];name=string(z);exists=isinstance(data,dict) and name in data;wi(w,int(exists));width=65535 if a==0x1401a1950 else 255
        value=data[name]&width if exists else si(rsp+0x28)&width
        finish(int(value!=0) if a==0x1401a0f60 else value)
    elif a==0x140418a60:
        calls.append(['updateSlots'])
        for index,entry in enumerate(c['classes']):
            if entry.get('memo',True):
                for level in range(10):rawresize(index,level,c.get('initialSlots',2) if level==(c.get('level',1)&255) else 0)
        finish()
    elif a==0x140416540:rawresize(y&255,z&255,w&255);finish()
    elif a==0x1403f22c0:
        at=stats+0xe0+(y&255)*0x188+(z&255)*16;finish(0 if c['classes'][y&255].get('memo',True) else max(0,c.get('knownCapacity',10)-(si(at+8)&65535))&255)
    elif a==0x14008ae10:
        count=si(x+8);capacity=si(x+12)
        if count==capacity:
            capacity=16 if capacity==0 else capacity*2;ptr=alloc(capacity*4)
            if count:u.mem_write(ptr,bytes(u.mem_read(q(x),count*4)))
            wq(x,ptr);wi(x+12,capacity)
        wi(q(x)+count*4,y);wi(x+8,count+1);finish()
    elif a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX))
    elif a in [0x140c10324,0x140c10368]:finish(alloc(x))
    elif a==0x140c4f038:
        ptr=alloc(y);old=bytes(u.mem_read(x,min(y,0x800))) if x else bytes(y);u.mem_write(ptr,old);finish(ptr)
    elif a in [0x140c10360,0x140c10370]:
        if x and a==0x140c10360 and y==16:deleted.append(si(x))
        finish()
    elif a==0x140c417f0:
        if z:u.mem_write(x,bytes(u.mem_read(y,z)))
        finish(x)
    elif a==0x140403340:finish(int(c.get('abilityReady',0)==1 and (y&0xffffffff)==c.get('abilityId',1)))
    elif a==0x1402af500:finish(int('V' in c.get('components','VS')))
    elif a==0x1402af4d0:finish(int('S' in c.get('components','VS')))
    elif a in [0x140405770,0x140404aa0,0x140404db0,0x140402ff0,0x140404c70]:
        index=y&255;level=z&255;pool=c['pools'][index][level] if index<len(c['pools']) and level<10 else []
        if a==0x140405770:finish(len(pool)&255)
        else:
            record=pool[w&255] if (w&255)<len(pool) else None
            finish(record.get('id',1) if a==0x140404aa0 and record else 0xffffffff if a==0x140404aa0 else record.get('ready',1)&255 if a==0x140404db0 and record else record.get('meta',0)&255 if a==0x140404c70 and record else record.get('domain',0) if record else 0)
    elif a==0x140404be0:
        index=(x-(stats+0xe0))//0x188;level=y&255;slot=z&255
        pool=c['pools'][index][level] if index<len(c['pools']) and level<10 else []
        finish(m.heap+0x90000+index*0x1000+level*0x100+slot*16 if slot<len(pool) and pool[slot] else 0)
    elif a==0x1403fa4a0:finish(c['classes'][y&255].get('id',y&255) if y&255<len(c['classes']) else 255)
    elif a==0x140286110:wi(y,c.get('id',1));finish(1)
    elif a==0x140286160:wi(y,99);finish(1)
    elif a==0x140286410:pushed=y&0xffffffff;finish(1)
    elif a==0x14055b3d0:finish(actor)
    elif a in scoreHelpers:finish(c.get('score',20)&255)
    elif a in bonusHelpers:finish(c.get('bonus',0)&255)
    elif a==0x1402ae870:finish(1)
    elif a==0x1402a4130:finish(c.get('minimum',11))
    elif a==0x1402a4a30:finish(c['classes'][y&255].get('arcane',0))
    elif a==0x1403fa4f0:finish(c['classes'][y&255].get('classLevel',5)&255)
    elif a==0x140299e40:
        calls.append(['gain',(x-classDefs)//0x530,y&255,z&255]);finish(((y+z)&255) if 1<=y&255<=40 and z&255<10 else 255)
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped spell owner dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
    global c,allocation,warnings,deleted,calls,pushed,nodes
    c=case;allocation=0;warnings=[];deleted=[];calls=[];pushed=None;nodes={};u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app)
    # g_pRules is1412df8f8? Verify from the owner's RIP loads, below.
    wq(0x1412df8f8,rules);wq(rules+0x110,classDefs);wq(rules+0xd0,spellArray);wq(stats+0x30,actor);wq(actor+0xad0,stats);wi(stats+0xb0,int(c.get('pc',False)));wi(actor+0x97c,int(c.get('override',False)))
    for off in [0x9e8,0x9ec,0x9f0]:wi(actor+off,c.get('overrideId',1))
    wi(actor+0x81c,c.get('unlimited',0));wq(stats+0xd88,m.heap+0x70000);wq(m.heap+0x70000,m.heap+0x71000)
    abilities=c.get('abilities',[dict(id=1,remaining=1,casterLevel=3)]);wi(m.heap+0x70008,len(abilities))
    for i,entry in enumerate(abilities):wi(m.heap+0x71000+i*12,entry['id']);wi(m.heap+0x71004+i*12,entry['remaining']);u.mem_write(m.heap+0x71008+i*12,bytes([entry['casterLevel']&255]))
    u.mem_write(stats+0xd8,bytes([len(c['classes'])]));u.mem_write(actor+0x8d4,struct.pack('<H',c.get('word',65535)&65535))
    for i in range(64):wi(spellBase+i*0x200+0x178,c.get('master',1) if i==1 else i);u.mem_write(spellBase+i*0x200+0x6f,bytes([c.get('innate',1)&255]));wi(spellBase+i*0x200+0x188,int(c.get('spontaneous',False)));u.mem_write(spellBase+i*0x200+0x18c,bytes([63]))
    for index,cls in enumerate(c['classes']):
        cid=cls.get('id',index);base=classDefs+cid*0x530;u.mem_write(stats+index*0x188+0x25c,bytes([cid&255,cls.get('classLevel',5)&255,0,cls.get('school',0)&255]));wi(base+0x4d8,1);wi(base+0x4ec,int(cls.get('memo',True)));wi(base+0x4f0,int(cls.get('restricted',False)));wi(base+0x4f4,int(c.get('domain',False)));wi(base+0x4f8,int(cls.get('pickSchool',False)));wi(base+0x500,cls.get('arcane',0));wi(base+0x520,int(c.get('convert',False)));u.mem_write(base+0x4e8,bytes([3]));u.mem_write(base+0x525,bytes([cls.get('arcDivisor',0),cls.get('divDivisor',0)]))
        wi(base+0x4fc,int(cls.get('learnScroll',False)))
        for level in range(10):
            u.mem_write(stats+0x248+index*0x188+level,bytes([c.get('uses',3)&255]));u.mem_write(stats+0x252+index*0x188+level,bytes([c.get('maximum',0)&255]));wi(stats+0x220+index*0x188+level*4,c.get('bonusSlots',0)&0xffffffff)
        if cls.get('caster') is False:wi(base+0x4d8,0)
        for level,pool in enumerate(c['pools'][index]):
            arr=m.heap+0x80000+index*0x1000+level*0x100;ci=stats+0xe0+index*0x188;wq(ci+0xa0+level*16,arr);wi(ci+0xa8+level*16,len(pool));wi(ci+0xac+level*16,0 if c['mode']=='import' else 16)
            for slot,record in enumerate(pool):
                if record is None:continue
                ptr=m.heap+0x90000+index*0x1000+level*0x100+slot*16;wq(arr+slot*8,ptr);wi(ptr,record.get('id',1));wi(ptr+4,record.get('ready',1));u.mem_write(ptr+8,bytes([record.get('meta',0)&255]));wi(ptr+12,record.get('domain',0))
        for off in [0xd39,0xd3b,0xd3d,0xd3f,0xd41,0xd43]:u.mem_write(stats+off,bytes([c.get('modifier',5)&255]))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    mode=c['mode'];index=c.get('index',0);id=c.get('id',1);meta=c.get('meta',0)
    if mode=='uses':address=0x140409160;args=[stats,id,index,c.get('domainLevel',0)];wi(rsp+0x28,meta)
    elif mode=='set':address=0x140415c00;args=[stats,index,c.get('slot',0),id];wi(rsp+0x28,c.get('domainLevel',0));wi(rsp+0x30,meta);wi(rsp+0x38,c.get('checkAbility',0))
    elif mode=='resize':address=0x140416610;args=[stats+0xe0,index,c.get('size',0),c.get('delete',1)]
    elif mode=='ready':address=0x140405110;args=[stats+0xe0,id,actor+0xf00,actor+0xf04];wi(rsp+0x28,meta)
    elif mode=='gain':address=0x140408120;args=[stats,index,c.get('level',1),0]
    elif mode=='talent':address=0x1403faab0;args=[stats,0,id,meta]
    elif mode=='has':address=0x1405257e0;args=[app,0,2]
    elif mode=='unready':address=0x140416eb0;args=[stats,id,index,c.get('domainLevel',0)];wi(rsp+0x28,meta)
    elif mode=='consume':address=0x14038a590;args=[actor,id,index,c.get('domainLevel',0)];wi(rsp+0x28,meta);wi(rsp+0x30,c.get('casterLevel',3))
    elif mode=='abilitySet':address=0x140416b00;args=[stats,id,c.get('newReady',0),c.get('casterLevel',3)]
    elif mode=='abilityLevel':address=0x140408aa0;args=[stats,id,0,0]
    elif mode=='adjust':address=0x1403f00a0;args=[stats,0,0,0]
    elif mode=='import':
        wi(actor+0xf50,node({'ClassList':c['data']}));address=0x14040f3e0;args=[stats,actor+0xf60,actor+0xf50,c.get('readyDefault',0)]
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v)
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=u.reg_read(UC_X86_REG_RAX)&(0xff if mode in ['uses','ready','gain','abilityLevel'] else 0xffffffff)
    if mode=='has':result=pushed
    out=dict(case=case,result=result)
    if mode=='ready':out['level']=int.from_bytes(u.mem_read(actor+0xf00,1),'little');out['slot']=int.from_bytes(u.mem_read(actor+0xf04,1),'little')
    if mode in ['set','resize','import','unready','consume']:
        observedIndex=index if index<len(c['classes']) else 0;ci=stats+0xe0+observedIndex*0x188;out['pools']=[]
        for level in range(10):
            records=[]
            for slot in range(si(ci+0xa8+level*16)):
                ptr=q(q(ci+0xa0+level*16)+slot*8);records.append(None if not ptr else dict(id=si(ptr)&0xffffffff,ready=si(ptr+4),meta=int.from_bytes(u.mem_read(ptr+8,1),'little'),domain=si(ptr+12)))
            out['pools'].append(records)
        out['capacities']=[si(ci+0xac+level*16) for level in range(10)];out['deleted']=deleted
    if mode=='import':
        out['known']=[[si(q(stats+0xe0+level*16)+slot*4)&0xffffffff for slot in range(si(stats+0xe8+level*16))] for level in range(10)]
        out['knownCapacity']=[si(stats+0xec+level*16) for level in range(10)];out['calls']=calls
    if mode in ['unready','consume','adjust']:out['perDay']=[[int.from_bytes(u.mem_read(stats+0x248+index*0x188+level,1),'little') for level in range(10)] for index in range(len(c['classes']))]
    if mode=='adjust':out['maximumPerDay']=[[int.from_bytes(u.mem_read(stats+0x252+index*0x188+level,1),'little') for level in range(10)] for index in range(len(c['classes']))]
    if mode in ['consume','abilitySet','abilityLevel']:out['abilities']=[dict(id=si(m.heap+0x71000+i*12)&0xffffffff,remaining=si(m.heap+0x71004+i*12),casterLevel=int.from_bytes(u.mem_read(m.heap+0x71008+i*12,1),'little')) for i in range(len(abilities))]
    if mode in ['gain','adjust']:out['calls']=calls
    return out

def fixture(mode,**kwargs):
    case=dict(mode=mode,classes=[dict(id=0,memo=True)],pools=[[[] for _ in range(10)]]);case.update(kwargs);return case
def pools(entries,level=1):
    result=[[] for _ in range(10)];result[level]=entries;return [result]
rows=[]
for mode in ['uses','ready','set']:
    for meta,admit,feat,kind in itertools.product([0,1,2,3,4,8,16,32,255],[False,True],[False,True],[0,1,2]):
        entries=[dict(id=1,ready=1,meta=16),None,dict(id=2,ready=1),dict(id=1,ready=0)] if kind else []
        case=fixture(mode,meta=meta,admit=admit,feat=feat,pools=pools(entries),checkAbility=1,slot=0,level=1)
        if kind==2:case['classes'][0]['memo']=False;case['classes'][0]['restricted']=True
        rows.append(run(case))
for pc,possessed,override,meta,overrideId in itertools.product([False,True],[False,True],[False,True],[0,1,2,255],[1,2]):rows.append(run(fixture('uses',pc=pc,possessed=possessed,override=override,meta=meta,overrideId=overrideId)))
for size,delete in itertools.product([0,1,2,4,17,255],[0,1]):rows.append(run(fixture('resize',size=size,delete=delete,pools=pools([dict(id=7),None,dict(id=9)]))))
for score,bonus,modifier,level in itertools.product([9,10,13,30],[-5,0,5],[-2,0,5,127],[0,1,3,9]):rows.append(run(fixture('gain',score=score,bonus=bonus,modifier=modifier,level=level)))
for word,components,abilityReady,meta in itertools.product([0,2,4,6,8,14,65535],['','V','S','VS'],[0,1,2],[0,16,32]):
    entries=[dict(id=2,ready=0,meta=16),dict(id=1,ready=1,meta=32),dict(id=1,ready=1)]
    rows.append(run(fixture('talent',word=word,components=components,abilityReady=abilityReady,meta=meta,pools=pools(entries))))
for memo,spontaneous,master,abilityReady in itertools.product([False,True],[False,True],[1,2],[0,1,2]):
    case=fixture('has',spontaneous=spontaneous,master=master,abilityReady=abilityReady,pools=pools([dict(id=1,ready=1),dict(id=1,ready=1),dict(id=2,ready=1,meta=16)]));case['classes'][0]['memo']=memo;rows.append(run(case))
for levels,index,arcane in itertools.product([(5,5,7),(5,6,7),(7,5,5),(1,1,0)],[0,1],[0,1]):
    cls=[dict(id=0,classLevel=levels[0],arcane=arcane),dict(id=1,classLevel=levels[1],arcane=arcane),dict(id=2,classLevel=levels[2],caster=False,arcDivisor=2,divDivisor=3)]
    rows.append(run(fixture('gain',classes=cls,index=index,pools=[[[] for _ in range(10)] for _ in cls],level=1)))
for pc,readyDefault,ready,meta,memo in itertools.product([False,True],[0,1],[None,0,1,2],[0,1,2,16,3],[False,True]):
    slot={'Spell':1,'SpellMetaMagic':meta}
    if ready is not None:slot['Ready']=ready
    case=fixture('import',pc=pc,readyDefault=readyDefault,data=[{'KnownList0':[{'Spell':1},{'Spell':1},{'Spell':99},{}],'MemorizedList1':[slot,{'Spell':2,'Ready':2}]}]);case['classes'][0]['memo']=memo;rows.append(run(case))
for mode,memo,meta,uses,domain in itertools.product(['unready','consume'],[False,True],[0,1,2,16,32,255],[0,1,255],[False,True]):
    case=fixture(mode,meta=meta,uses=uses,domain=domain,domainLevel=1 if domain else 0,pools=pools([dict(id=1,ready=1),dict(id=1,ready=1,meta=16),dict(id=1,ready=0,meta=16)]));case['classes'][0]['memo']=memo;rows.append(run(case))
for mode,pc,possessed,override,meta,overrideId in itertools.product(['unready','consume'],[False,True],[False,True],[False,True],[0,1,255],[1,2]):rows.append(run(fixture(mode,pc=pc,possessed=possessed,override=override,meta=meta,overrideId=overrideId)))
for mode,id,newReady,casterLevel in itertools.product(['abilitySet','abilityLevel','consume'],[1,2,3],[0,1,2],[3,7,255]):
    rows.append(run(fixture(mode,id=id,index=254,newReady=newReady,casterLevel=casterLevel,abilities=[dict(id=1,remaining=0,casterLevel=3),dict(id=1,remaining=1,casterLevel=7),dict(id=2,remaining=2,casterLevel=3)])))
for mode in ['unready','consume']:rows.append(run(fixture(mode,index=255,unlimited=1)))
for mode,meta,master,ready,missingMaster in itertools.product(['unready','consume'],[0,16,255],[1,2],[0,1,256],[False,True]):
    case=fixture(mode,meta=meta,master=master,missingMaster=missingMaster,pools=pools([dict(id=master,ready=ready)]));case['pools'][0][2]=[dict(id=master,ready=ready,meta=16)];rows.append(run(case))
for uses,maximum,bonusSlots,memo in itertools.product([0,1,128,255],[0,5,128,255],[0,3,255,256],[False,True]):
    case=fixture('adjust',uses=uses,maximum=maximum,bonusSlots=bonusSlots);case['classes'][0]['memo']=memo;rows.append(run(case))
out=m.root/'backups/animations/native-spell-book-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
