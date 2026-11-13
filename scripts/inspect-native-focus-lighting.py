"""Unchanged original GetEmitterLighting + vision hysteresis instruction oracle.

The admitted light list, fade factors, headlight colors and cached scene sample
are explicit service boundaries. Does not prove BSP admission/fades, live focus
placement, GPU colors or room performance. No process/network access or edits.
"""
import importlib
import itertools
import json
import math
import random
import struct
import sys
from pathlib import Path

m = importlib.import_module('inspect-native-intratile-coordinator')
u = m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager, point, output, items, excluded, excluded_items, view, scene, vtable, app = [m.heap+n*0x1000 for n in range(10)]
lights = m.heap+0x10000
sample_call = m.stop+0x10
ranges = [(0x14007ee50,0x14007f17f),(0x14022b180,0x14022b1ae),
          (0x1402303d0,0x14023040d),(0x140c7d6d8,0x140c7d783),
          (0x1407dadb0,0x1407daea3)]
def vec(address, values):
    for index,value in enumerate(values): m.wf(address+index*4,value)
def read_vec(address): return [m.rf(address+n*4) for n in range(3)]
def hook(u,address,size,_):
    if address==m.stop: u.emu_stop(); return
    if address==0x1406ac1a0: m.finish(0); return  # Controlled render-object service.
    if address==sample_call:
        destination=u.reg_read(UC_X86_REG_RDX)
        vec(destination,cached); m.finish(destination); return
    if not any(low<=address<high for low,high in ranges):
        raise RuntimeError(f'Unexpected original focus-light dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,*arguments):
    u.mem_write(m.stack,bytes(0x20000)); rsp=m.stack+0x1fe08; m.wq(rsp,m.stop)
    u.reg_write(UC_X86_REG_RSP,rsp); u.reg_write(UC_X86_REG_MXCSR,0x1f80)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],arguments): u.reg_write(reg,value)
    try: u.emu_start(address,m.stop,count=1000000)
    except Exception:
        print(json.dumps({'rip':hex(u.reg_read(UC_X86_REG_RIP))})); raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop,'Instruction boundary exhausted'
    return u.reg_read(UC_X86_REG_RAX)
def light(address,row):
    vec(address+0x68,row['color']); vec(address+0xb0,row.get('position',[0,0,0]))
    m.wf(address+0x74,row.get('radius',0)); m.wf(address+0x94,row.get('fade',1))
def gate(sample,previous,present=True):
    global cached
    cached=sample; m.wq(view+0x248,scene if present else 0); m.wi(view+0x350,previous)
    m.wq(scene,vtable); m.wq(vtable+0x130,sample_call)
    m.wq(0x1412df970,app); m.wq(app,app+8)
    returned=invoke(0x1407dadb0,view)&0xffffffff
    return {'previous':previous,'present':present,'returned':returned,'stored':m.si(view+0x350)}
def run(case):
    u.mem_write(m.heap,bytes(0x100000)); vec(point,case['point'])
    m.wq(manager+0x60,items); m.wi(manager+0x68,len(case['lights']))
    for index,row in enumerate(case['lights']):
        address=lights+index*0x100; light(address,row); m.wq(items+index*8,address)
    for field,key,index in [(0xa0,'ambient',200),(0x98,'diffuse',201)]:
        row=case.get(key)
        if row is not None:
            address=lights+index*0x100; light(address,row); m.wq(manager+field,address)
    m.wi(0x14128e520,int(case.get('headlight',False)))
    vec(0x14128e5c0,case.get('headlight_diffuse',[0,0,0])); vec(0x14128e5d0,case.get('headlight_ambient',[0,0,0]))
    for index,identity in enumerate(case.get('excluded',[])): m.wq(excluded_items+index*8,lights+identity*0x100)
    m.wq(excluded,excluded_items); m.wi(excluded+8,len(case.get('excluded',[])))
    before=bytes(u.mem_read(excluded_items,len(case.get('excluded',[]))*8))
    invoke(0x14007ee50,manager,output,point,excluded if case.get('exclusion_list',True) else 0)
    result=read_vec(output)
    assert before==bytes(u.mem_read(excluded_items,len(case.get('excluded',[]))*8)), 'Original membership sentinel was not restored'
    return {'case':case,'sample':result,'gates':[gate(result,previous) for previous in [0,1]]}
rows=[]
for radius,distance,fade in itertools.product([0,.01,1,10,1000],[0,0.000001,.5,1,12],[-.25,0,.5,1]):
    rows.append(run({'point':[0,0,0],'lights':[{'color':[.2,.4,.8],'radius':radius,'position':[distance,0,0],'fade':fade}]}))
randomizer=random.Random(0x77a691)
for index in range(192):
    count=index%33
    light_rows=[{'color':[randomizer.uniform(-.1,2) for _ in range(3)],'position':[randomizer.uniform(-3,3) for _ in range(3)],'radius':randomizer.choice([0,.25,2,8,1000]),'fade':randomizer.choice([0,.3,1])} for _ in range(count)]
    rows.append(run({'point':[randomizer.uniform(-2,2) for _ in range(3)],'lights':light_rows,'excluded':list(range(0,count,2)),'exclusion_list':index%4!=0,
        'ambient':{'color':[.1,.2,.3],'fade':.5} if index%2 else None,'diffuse':{'color':[.15,.05,.2],'fade':.75} if index%3 else None,
        'headlight':index%5==0,'headlight_diffuse':[.05,.1,.15],'headlight_ambient':[.02,.04,.06]}))
# Larger exclusion lists exercise the original restored-sentinel membership path.
for count in [17,18,33,64,129]:
    rows.append(run({'point':[1,2,3],'lights':[{'color':[.02,.01,.03],'radius':8,'position':[0,0,0],'fade':1} for _ in range(count)],'excluded':list(range(count))}))
gates=[]
for value in [0,.3499,.35,.3501,.4999,.5,.5001,.7,1]:
    for previous,present in itertools.product([0,1],[False,True]):
        sample=[value]*3; gates.append({'sample':sample,**gate(sample,previous,present)})
for value in [.35*1.732,.5*1.732]:
    bits=struct.unpack('<I',struct.pack('<f',value))[0]
    for delta,previous in itertools.product([-2,-1,0,1,2],[0,1]):
        sample=[struct.unpack('<f',struct.pack('<I',bits+delta))[0],0,0]
        gates.append({'sample':sample,**gate(sample,previous)})
destination=Path(sys.argv[1])
if destination.exists(): raise ValueError('Use a new oracle output path')
result={'binary_sha256':m.digest,'scope':__doc__,'network_connections':0,'rows':rows,'gates':gates}
if len(sys.argv)>2:
    history_path=Path(sys.argv[2]); history=json.loads(history_path.read_text(encoding='utf-8'))
    assert history['binary_sha256']==m.digest
    samples=[]
    for sequence,row in enumerate(history['rows']):
        for frame_index,frame in enumerate(row['frames']):
            admitted=[]
            for call in frame['calls']:
                if call['kind']=='draw':
                    light_row=dict(row['case']['lights'][call['id']]);light_row['fade']=call['fade'];admitted.append(light_row)
            sample=run({'point':[0,0,0],'lights':admitted})
            sample.update({'sequence':sequence,'frame':frame_index});samples.append(sample)
    import hashlib
    result.update({'rows':samples,'gates':[],'history_sha256':hashlib.sha256(history_path.read_bytes()).hexdigest(),
                   'scope':'Original GetEmitterLighting and vision hysteresis over the exact original ControlLightsFade draw submissions in the paired128-lamp limit corpus. Explicit sampled point at origin; no live-room or GPU acceptance.'})
destination.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'output':str(destination),'samples':len(result['rows']),'gate_boundaries':len(result['gates'])}))
