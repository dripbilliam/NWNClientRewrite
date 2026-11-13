"""Original illumination priority/sort and complete ControlLightsFade oracle.

Executes unchanged priority, original MSVC sort/comparator, adjusted color/range,
fade speed and fade history. Frames with collect_radius also execute original
SetupLightsForThisPositionAndRadius. Otherwise candidate lists are supplied.
Per-light view admission and render-interface writes are explicit boundaries. No live game,
network, binary edits, GPU or native timing claims. Shadow-list selection is not
executed here; independent fade channels are exercised through param3.
"""
import importlib,json,random,struct,sys
from pathlib import Path
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager,vt,focus,ranked,ranked_items,active0,active1=[m.heap+n*0x1000 for n in range(7)]
parts,nodes=m.heap+0x10000,m.heap+0x30000
ranges=[(0x14007db60,0x14007dbcc),(0x14007ddb0,0x14007e6ef),(0x14007f380,0x14007f633),(0x140080f80,0x140081100),
        (0x14007ff40,0x1400801a5),(0x14007c000,0x14007d7d0),
        (0x1400812d0,0x140081300),(0x1402303d0,0x14023040d),
        (0x140c7d6d8,0x140c7d783)]
def vector(address,values):
    for n,v in enumerate(values):m.wf(address+n*4,v)
def identity(address):return (address-parts)//0x100
def finish_float(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,_):
    global allocations
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x14007f180:m.finish(int(frame.get('in_view',{}).get(str(identity(x)),True)));return
    if a==0x1400bec20:m.finish(int(case.get('enhanced',True)));return
    if a==0x1400bec10:assert x==18;finish_float(case.get('cutoff',2));return
    if a in [0x14007fe40,0x1400801b0]:m.finish();return
    if a==0x140080950:calls.append({'kind':'headlight'});m.finish();return
    if a==0x140080c10:calls.append({'kind':'draw','id':identity(x),'slot':y&0xffffffff,'fade':m.xmm(UC_X86_REG_XMM2)});m.finish();return
    if a==0x1400bea00:calls.append({'kind':'disable','slot':x&0xffffffff});m.finish();return
    if a in [0x1400befd0,0x1400befe0]:m.finish();return
    if a==0x1400beb90:u.mem_write(x,bytes(u.mem_read(y,12)));m.finish(x);return
    if a==0x140230920:vector(x,[0,0,1]);m.finish(x);return
    if a==0x140c417f0:
        assert z<=0x2000;u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
    if a==0x140c4f038:
        assert y<=0x2000
        if x==0:x=m.heap+0x80000+allocations*0x4000;allocations+=1
        m.finish(x);return
    if not any(low<=a<high for low,high in ranges):raise RuntimeError(f'Unexpected original light history dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,*args,fp2=None):
    u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
    u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
    if fp2 is not None:u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',fp2),'little'))
    try:u.emu_start(address,m.stop,count=2000000)
    except Exception:print(json.dumps({'rip':hex(u.reg_read(UC_X86_REG_RIP)),'last_calls':calls[-8:]}));raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop,'Instruction bound exhausted'
def field(address,row):
    m.wq(address+8,nodes+identity(address)*0x120)
    node=m.q(address+8);m.wi(node+0xf8,row.get('priority',4));m.wi(node+0x110,int(row.get('fading',True)))
    vector(address+0x68,row.get('color',[.4,.6,.8]));vector(address+0xb0,row.get('position',[0,0,0]))
    m.wf(address+0x74,row.get('radius',8));m.wf(address+0xa8,row.get('multiplier',1))
    m.wi(address+0x90,row.get('override',0));m.wi(address+0x88,row.get('affect',1));m.wi(address+0x8c,row.get('dynamic',1));m.wq(address+0x50,row.get('owner',0))
    for offset,key in [(0x94,'fade0'),(0x98,'fade1')]:m.wf(address+offset,row.get(key,0))
def list_ids(address):return [identity(m.q(m.q(address)+n*8)) for n in range(m.si(address+8))]
def run(config):
    global case,frame,calls,allocations
    case=config;calls=[];allocations=0;u.mem_write(m.heap,bytes(0x100000))
    m.wq(manager,vt);m.wq(vt+0x58,0x14007fe40);m.wq(vt+0x48,0x14007ff40);m.wq(vt+0x50,0x1400801b0)
    for n,row in enumerate(case['lights']):field(parts+n*0x100,row)
    for channel,address in enumerate([active0,active1]):
        ids=case.get('active'+str(channel),[])
        if ids:
            buffer=m.heap+0x60000+channel*0x4000;m.wq(address,buffer);m.wi(address+8,len(ids));m.wi(address+12,256)
            for n,index in enumerate(ids):m.wq(buffer+n*8,parts+index*0x100)
    results=[]
    for frame in case['frames']:
        calls=[];m.wi(0x14128e588,frame.get('maximum',case.get('maximum',16)))
        m.wi(0x14128e520,int(frame.get('headlight',False)));m.wq(0x141301720,frame.get('only_owner',0));m.wf(0x14128e030,frame.get('delta',1/60))
        vector(focus,frame.get('focus',[0,0,0]))
        for key,index in [('ambient',250),('diffuse',251)]:
            row=frame.get(key,case.get(key))
            if row is not None:
                address=parts+index*0x100
                if not m.q(address+8):field(address,row)
                vector(address+0x68,row.get('color',[0,0,0]));m.wq(manager+(0xa0 if key=='ambient' else 0x98),address)
            else:m.wq(manager+(0xa0 if key=='ambient' else 0x98),0)
        ids=frame.get('candidates',list(range(len(case['lights']))));m.wq(manager+0x40,ranked_items);m.wi(manager+0x48,len(ids));m.wi(manager+0x4c,256)
        if 'collect_radius' in frame:
            all_items=m.heap+0x7000;m.wq(manager+0x10,all_items);m.wi(manager+0x18,len(case['lights']))
            for n in range(len(case['lights'])):m.wq(all_items+n*8,parts+n*0x100)
            invoke(0x140080f80,manager,focus,fp2=frame['collect_radius']);ids=list_ids(manager+0x40)
        else:
            for n,index in enumerate(ids):m.wq(ranked_items+n*8,parts+index*0x100)
        if frame.get('sort',True):invoke(0x14007ff60,manager,focus)
        m.wq(ranked,ranked_items);m.wi(ranked+8,len(ids));m.wi(ranked+12,len(ids))
        order=list_ids(ranked);channel=frame.get('channel',0)
        invoke(0x14007ddb0,manager,[active0,active1][channel],ranked,channel)
        results.append({'active0':list_ids(active0),'active1':list_ids(active1),'order':order,'collected':ids,
            'fades':[[m.rf(parts+n*0x100+0x94),m.rf(parts+n*0x100+0x98)] for n in range(len(case['lights']))],
            'area_fades':[[m.rf(parts+n*0x100+0x94),m.rf(parts+n*0x100+0x98)] for n in [250,251]],'calls':calls})
    return {'case':case,'frames':results}
def corpus(count):
    rng=random.Random(0x17a190)
    rows=[]
    for n in range(count):
        total=[0,1,4,17,33,64,129,160][n%8]
        lights=[{'color':rng.choice([[.3,.5,.8],[0,0,0],[2,1,.5],[-.2,.4,.2]]),'radius':rng.choice([0,.01,4,12]),'multiplier':rng.choice([0,.5,1,2]),'position':[rng.choice([-3,-1,0,1,3]) for _ in range(3)],'priority':rng.choice([0,1,4]),'override':rng.choice([0,11]),'dynamic':rng.choice([0,1]),'fading':rng.choice([False,True]),'owner':rng.choice([0,1,2])} for _ in range(total)]
        frames=[]
        for step in range(8):
            ids=list(range(total));rng.shuffle(ids)
            if step in [2,5]:ids=ids[:total//2]
            if step==7:ids=[]
            frames.append({'candidates':ids,'channel':step%2 if n%3==0 else 0,'maximum':[0,1,4,16,128,256][n%6],
                'headlight':n%5==0,'only_owner':1 if step in [3,4] else 0,'delta':rng.choice([0,.00001,1/60,.2,.7]),
                'in_view':{str(index):bool((index+step)%4) for index in range(total)},'focus':[step*.25,0,0]})
        rows.append(run({'lights':lights,'frames':frames,'enhanced':bool(n%2),'cutoff':2,
            'ambient':{'color':[.1,.2,.3],'radius':1000000,'owner':0},'diffuse':{'color':[.3,.2,.1],'radius':1000000,'owner':0}}))
    return rows
def directed():
    rows=[]
    # Exact zero is retained; negative removes. Forced non-fading replacement
    # evicts without zeroing the outgoing Part's independent stored fade.
    for channel in [0,1]:
        for fading in [False,True]:
            lights=[{'color':[1,1,1],'radius':5,'fade'+str(channel):.25 if fading else .75},
                    {'color':[1,1,1],'radius':5,'fading':fading}]
            frames=[{'candidates':[1,0],'sort':False,'channel':channel,'maximum':1,'delta':dt} for dt in [.25,0,.25,.25]]
            rows.append(run({'lights':lights,'active'+str(channel):[0],'frames':frames,'enhanced':True}))
    for initial in [-.25,1.25]:
        rows.append(run({'lights':[{'color':[.7,.3,.2],'radius':4,'fade0':initial}],
            'active0':[0],'ambient':{'color':[.2,.3,.4],'radius':1000000,'fade0':initial},
            'frames':[{'candidates':[0],'maximum':1,'delta':.01},{'candidates':[0],'maximum':1,'only_owner':1,'delta':.01}]}))
    return rows

def collection_corpus():
    rng=random.Random(0x1580148);rows=[]
    for n in range(64):
        lights=[{'color':rng.choice([[0,0,0],[.5,.3,.2],[2,1,.5],[-.2,0,0]]),
            'radius':rng.choice([0,.01,4,5,999.99,1000,1001]),'multiplier':rng.choice([0,.5,1,2]),
            'position':[rng.choice([-80,-53,-49,-1,0,1,49,53,80]),0,0],
            'dynamic':rng.choice([0,1]),'affect':rng.choice([0,1]),'fading':rng.choice([0,1])} for _ in range(64)]
        rows.append(run({'lights':lights,'enhanced':bool(n%2),'cutoff':2,'frames':[
            {'collect_radius':radius,'maximum':16,'delta':1/60,'focus':[n%3,0,0]} for radius in [0,45,60]]}))
    # Strict sphere overlap, raw radius=1000 boundary, and source-flag pairs.
    for dynamic,affect in [(0,0),(0,1),(1,0),(1,1)]:
        lights=[{'color':[1,1,1],'radius':4,'position':[distance,0,0],'dynamic':dynamic,'affect':affect} for distance in [52.99999,53,53.00001]]
        rows.append(run({'lights':lights,'enhanced':True,'frames':[{'collect_radius':45,'maximum':128,'delta':.1}]}))
    return rows

def light_limit_corpus():
    # Deliberately distinguish the configured active limit from the128-slot
    # storage capacity. Closest warm lamps compete with more distant cool lamps.
    lights=[{'color':[.012,.010,.001],'position':[2+n*.015,0,0],'radius':6,'fading':0} for n in range(32)]
    lights += [{'color':[.004,.007,.012],'position':[7+n*.02,0,0],'radius':20,'fading':0} for n in range(96)]
    return [run({'lights':lights,'enhanced':True,'frames':[
        {'collect_radius':45,'maximum':maximum,'delta':.1} for maximum in limits]})
        for limits in [[8],[16],[32],[64],[128],[32,128,32]]]

def tile_priority_corpus():
    return [run({'lights':[
        {'color':[1,.8,0],'position':[3,0,0],'radius':10,'priority':5,'override':override,'fading':0},
        {'color':[1,.8,0],'position':[3.2,0,0],'radius':10,'priority':4,'fading':0}],
        'enhanced':True,'frames':[{'collect_radius':45,'maximum':1,'delta':.3}]}) for override in [0,4,0]]

destination=Path(sys.argv[1]);limit=int(sys.argv[2]) if len(sys.argv)>2 else 160
if destination.exists():raise ValueError('Use a new evidence path')
mode=sys.argv[3] if len(sys.argv)>3 else ''
rows=collection_corpus() if mode=='collection' else light_limit_corpus() if mode=='light-limit' else tile_priority_corpus() if mode=='tile-priority' else corpus(limit)+directed()
destination.write_text(json.dumps({'binary_sha256':m.digest,'scope':__doc__,'rows':rows,'network_connections':0},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'output':str(destination),'sequences':len(rows),'frames':sum(len(row['frames']) for row in rows)}))
