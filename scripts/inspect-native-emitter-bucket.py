"""Read-only original emitter admission/update/draw-order instruction trace.

Executes unchanged BSP leaf emitter admission, SphereAbovePlane, the entire
Scene::DoEmitterBucket, AnimateParticles, its type test, the original sort and
its comparator/helpers from the SHA-checked installed executable. Synthetic
scene/part poses, animation callbacks and render handlers are explicit captured
boundaries. This proves native admission, update eligibility, clamped deltas,
empty-emitter exclusion and draw ordering, not full particle simulation, GPU
pixels or native-client timing. Existing initialization/vertices/stream oracles
cover those separate lower boundaries. No game process or network is opened.
"""
import importlib, itertools, json, random, struct

m = importlib.import_module('inspect-native-intratile-coordinator')
u = m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)

scene, scene_vt, source_vt, emitter_vt, camera, bsp, leaf, planes, volume = [m.heap+n*0x1000 for n in range(9)]
bucket, draw_list, source_base, emitter_base, node_base = [m.heap+n for n in [0xa000, 0xb000, 0x10000, 0x20000, 0x60000]]
tls_base, tls_array, tls_data = [m.heap+n for n in [0x90000, 0x91000, 0x92000]]
transform_call, fog_call, scene_animation_call, source_animation_call, update_call, render_call = [m.stop+n*0x10 for n in range(1,7)]
ranges = [(0x1400dc140,0x1400dc8f4), (0x14022e360,0x14022e392),
          (0x1400c7ae0,0x1400c7f00), (0x140061210,0x1400615ec),
          (0x14008c2e0,0x14008c2f4), (0x1400c0580,0x1400c086a),
          (0x1400c91f0,0x1400c9268), (0x1400bf590,0x1400bf60a),
          (0x1400bfa90,0x1400bfccc), (0x1400bfeb0,0x1400bff92)]

def vector(address, values):
    for index, value in enumerate(values): m.wf(address+4*index, value)

def f32(value): return struct.unpack('<f',struct.pack('<f',value))[0]

def identity(address): return identities[address]

def hook(u, address, size, _):
    if address == m.stop: u.emu_stop(); return
    x,y,z,w = [u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if address == transform_call:
        index = identity(x); vector(y,profiles[index]['position']); vector(z,[1,0,0,0])
        calls.append(dict(call='pose',phase=phase,id=index)); m.finish()
    elif address == fog_call: calls.append(dict(call='fog')); m.finish()
    elif address == scene_animation_call: m.finish(case['animating'])
    elif address == source_animation_call: m.finish(source_profiles[x]['animating'])
    elif address == update_call:
        index=identity(x); delta=m.xmm(UC_X86_REG_XMM1)
        calls.append(dict(call='update',id=index,delta=delta)); m.wi(x+0x190,profiles[index]['after']); m.finish()
    elif address == render_call: calls.append(dict(call='render_handler',id=identity(x))); m.finish()
    elif address == 0x140c417f0:
        u.mem_write(x,bytes(u.mem_read(y,z))); m.finish(x)
    elif address == 0x140c4f038:
        target = bucket if x==m.q(0x14140b0c8) else draw_list
        assert y <= 0x1000
        calls.append(dict(call='reserve',list='admitted' if target==bucket else 'draw',bytes=y))
        m.finish(target)
    elif address in [0x140064720,0x140064760,0x14030f3c0,0x1400d5d80,0x1400d5bb0,0x140c10410]:
        if address in [0x140064720,0x140064760]: calls.append(dict(call='layer_start' if address==0x140064720 else 'layer_stop'))
        m.finish()
    elif not any(low<=address<high for low,high in ranges):
        raise RuntimeError(f'Unexpected original bucket dependency {address:x}')

u.hook_add(UC_HOOK_CODE,hook)

def invoke(address,*arguments):
    u.mem_write(m.stack,bytes(0x20000)); rsp=m.stack+0x1fe08; m.wq(rsp,m.stop)
    u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],arguments): u.reg_write(reg,value)
    try: u.emu_start(address,m.stop,count=3000000)
    except Exception:
        print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),last_calls=calls[-15:])))
        raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop, 'Native instruction bound exhausted'

def run(config):
    global case,calls,profiles,source_profiles,identities,phase
    case=config; calls=[]; profiles=[]; source_profiles={}; identities={}
    u.mem_write(m.heap,bytes(0x100000))
    # Disable optional Tracy and initialize the already-constructed C++ static
    # vector guard. The particle loops/sort and reserve requests remain intact.
    u.mem_write(0x14141e310,b'\0\0'); m.wi(0x14141e314,0)
    m.wi(0x1415d65b0,0); m.wi(0x14140af48,0)
    u.reg_write(UC_X86_REG_GS_BASE,tls_base); m.wq(tls_base+0x58,tls_array); m.wq(tls_array,tls_data); m.wi(tls_data+0x1e4,0)
    m.wq(scene,scene_vt); m.wq(scene_vt+0x278,fog_call); m.wq(scene_vt+0x280,scene_animation_call)
    u.mem_write(scene+0x1e0,b'\1'); m.wq(0x14140ac50,scene); m.wq(0x1412e0318,camera)
    vector(camera+0xb0,config['camera']); m.wf(0x14128e030,config['delta'])
    m.wq(emitter_vt+0x18,transform_call); m.wq(emitter_vt+0x100,update_call); m.wq(source_vt+0x2a0,source_animation_call)
    m.wq(bsp+0x70,leaf); m.wq(leaf+0x30,m.heap+0xc000); m.wi(leaf+0x38,config['count'])
    m.wq(volume,planes); m.wi(volume+8,6); m.wi(0x14140afcc,config['last_plane'])
    for index,value in enumerate([[1,0,0,-5],[-1,0,0,-5],[0,1,0,-5],[0,-1,0,-5],[0,0,1,-5],[0,0,-1,-5]]): vector(planes+index*16,value)
    m.wq(0x14140b0c8,bucket); m.wi(0x14140b0d0,0); m.wi(0x14140b0d4,config['capacity'])
    m.wq(0x14140af38,draw_list); m.wi(0x14140af40,0); m.wi(0x14140af44,config['capacity'])
    for index in range(config['count']):
        group=index%4 if config['shared_sources'] else index
        has_source=index%5!=0
        source=source_base+group*0x400
        position=[f32(((group*17)%97-48)/8),f32((group%3-1)*0.5),0.0]
        profile=dict(position=position,before=index%3,after=0 if index%4==0 else 2,radius=0.25,source=source if has_source else 0,order=(index*13)%37-18)
        profiles.append(profile)
        if has_source:
            source_profiles[source]=dict(animating=bool(group%2),fade=0.5 if config['faded'] and group%3==1 else 1.0)
            m.wq(source,source_vt); vector(source+0xa8,position)
            fade_instance=m.heap+0x50000+group*0x100
            m.wq(source+0x1a8,fade_instance); m.wf(fade_instance+0xc8,source_profiles[source]['fade'])
        ptr=emitter_base+index*0x400; node=node_base+index*0x200; identities[ptr]=index
        m.wq(ptr,emitter_vt); m.wq(ptr+8,node); m.wq(ptr+0x50,profile['source']); m.wq(ptr+0x1b0,render_call)
        vector(ptr+0x10,position); m.wf(ptr+0x20c,profile['radius']); m.wi(ptr+0x190,profile['before'])
        u.mem_write(node+0x98,b'\5'); u.mem_write(node+0x170,struct.pack('<h',profile['order']))
    order=list(range(config['count'])); random.Random(config['seed']).shuffle(order)
    for index,emitter_index in enumerate(order): m.wq(m.heap+0xc000+index*8,emitter_base+emitter_index*0x400)
    phase='admission'; invoke(0x1400dc140,bsp,0,volume,scene)
    admitted=[identity(m.q(m.q(0x14140b0c8)+index*8)) for index in range(m.si(0x14140b0d0))]
    expected_admitted=[index for index in order if all(abs(component)<=5+profiles[index]['radius'] for component in profiles[index]['position'])]
    assert admitted==expected_admitted
    phase='update'; invoke(0x1400c7ae0,scene)
    updates=[call for call in calls if call['call']=='update']
    expected_updates=[index for index in admitted if (config['animating'] or (profiles[index]['source'] and source_profiles[profiles[index]['source']]['animating'])) and (not profiles[index]['source'] or source_profiles[profiles[index]['source']]['fade']>=1)]
    assert [call['id'] for call in updates]==expected_updates
    assert all(call['delta']==min(f32(config['delta']),0.5) for call in updates)
    drawn=[call['id'] for call in calls if call['call']=='render_handler']
    expected_live=[index for index in admitted if (profiles[index]['after'] if index in expected_updates else profiles[index]['before'])>0]
    assert set(drawn)==set(expected_live) and len(drawn)==len(expected_live)
    distances={index:m.rf(emitter_base+index*0x400+0x240) for index in drawn}
    def less(a,b):
        if distances[a]!=distances[b]: return distances[a]<distances[b]
        if profiles[a]['source'] and profiles[a]['source']==profiles[b]['source']: return profiles[a]['order']<profiles[b]['order']
        return False
    assert all(distances[drawn[index]]<=distances[drawn[index+1]] for index in range(len(drawn)-1))
    # The original comparator only breaks equal-distance ties for the same
    # non-null source. Mixing those records with unrelated/source-less records
    # does not define a total order. Record the original sort's actual result;
    # do not replace it with a conveniently stable Python sort or a new key.
    tie_inversions=[(drawn[index],drawn[index+1]) for index in range(len(drawn)-1) if less(drawn[index+1],drawn[index])]
    assert [call['call'] for call in calls if call['call'].startswith('layer_')]==['layer_start','layer_stop']
    return dict(input=config,registration_order=order,admitted=admitted,updates=updates,render_handlers=drawn,distances=distances,equal_distance_tie_inversions=tie_inversions,calls=calls,last_reject_plane=m.si(0x14140afcc),retained_admission_capacity=m.si(0x14140b0d4),retained_draw_capacity=m.si(0x14140af44))

if __name__=='__main__':
    out=m.root/'backups/animations/native-emitter-bucket-v1.json'
    assert not out.exists(), 'Preserve original instruction observations'
    rows=[run(dict(count=count,animating=animating,delta=delta,faded=faded,shared_sources=shared,capacity=capacity,last_plane=plane,seed=17,camera=[0,0,5])) for count,animating,delta,faded,shared,capacity,plane in itertools.product([0,7,64],[False,True],[0.0,1/60,0.7,-0.1],[False,True],[False,True],[0,128],[0,4])]
    out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2))
    print(json.dumps(dict(success=True,output=str(out),cases=len(rows),network_connections=0,gpu_execution=False)))
