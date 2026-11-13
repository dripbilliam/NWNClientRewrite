"""Original NWN highlight CPU instructions; no renderer, process attach or network.

Executes WritePartHighlightVertices and all reached quaternion/vector/normalize/
finite sqrt instructions against synthetic typed Parts and authored bounds. Also
executes exact Scene Gob-alpha and pulse slices. Pulse uses the original SSE
sinf branch (CPU-feature flag zero), not a replacement Python math routine.
"""
import argparse, copy, hashlib, importlib, itertools, json, math, struct, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts'))
m = importlib.import_module('inspect-native-intratile-coordinator')
u = m.u; u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
SHA = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if m.digest != SHA: raise RuntimeError('PE identity')
SCENE, CAMERA, POS, QUAT, COLOUR, COUNT, GOB = [m.heap + n * 0x1000 for n in range(1, 8)]
OUTPUT = m.heap + 0x40000
PARTS = [m.heap + 0x10000 + n * 0x1000 for n in range(8)]
MODELS = [m.heap + 0x20000 + n * 0x1000 for n in range(8)]
TABLES = [m.heap + 0x30000 + n * 0x1000 for n in range(8)]
RANGES = [(0x1400d4f30,0x1400d5844), (0x14022ae90,0x14022b0ba),
          (0x14022ab00,0x14022ac33), (0x14022d960,0x14022da0a),
          (0x140230920,0x1402309f4), (0x140c7d6d8,0x140c7d782),
          (0x14008c360,0x14008c373), (0x1400616e0,0x1400616f2),
          (0x14008c4d0,0x14008c4e3), (0x1400c8529,0x1400c8586),
          (0x1400c83ce,0x1400c8469), (0x140c7a2b0,0x140c7a9a5)]
operation = ''; visited = set()
def hook(_u, address, _size, _data):
    visited.add(address)
    if address == m.stop or (operation == 'gob-alpha' and address == 0x1400c8586) or (operation == 'pulse' and address == 0x1400c8469):
        u.emu_stop(); return
    if not any(a <= address <= b for a,b in RANGES):
        raise RuntimeError(f'Uncaptured highlight dependency {address:x}')
u.hook_add(UC_HOOK_CODE, hook)
def fw(value): return struct.unpack('<I',struct.pack('<f',value))[0]
def word(address): return struct.unpack('<I',u.mem_read(address,4))[0]
def words(address,count): return list(struct.unpack('<'+'I'*count,u.mem_read(address,count*4)))
def write_floats(address, values): u.mem_write(address,struct.pack('<'+'f'*len(values),*values))
def reset():
    global visited
    visited=set();u.mem_write(m.heap,bytes(0x50000));u.mem_write(m.stack,bytes([0xa5])*0x20000)
    for reg in [UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_R10,UC_X86_REG_R11,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(reg,0)
    for reg in [UC_X86_REG_XMM0,UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3,UC_X86_REG_XMM4,UC_X86_REG_XMM5,UC_X86_REG_XMM6,UC_X86_REG_XMM7,UC_X86_REG_XMM8,UC_X86_REG_XMM9,UC_X86_REG_XMM10,UC_X86_REG_XMM11,UC_X86_REG_XMM12,UC_X86_REG_XMM13,UC_X86_REG_XMM14,UC_X86_REG_XMM15]:u.reg_write(reg,0)
    sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
    return sp
def part(**updates):
    return dict(kind='trimesh',enabled=True,position=[0,0,0],quaternion_wxyz=[1,0,0,0],scale=1,bounds=[[-1,-2,0],[1,2,3]],alpha=1,source_render=1,children=[]) | updates
def leaf(case):
    global operation
    operation='leaf';sp=reset()
    if len(case['parts'])>8:raise RuntimeError('Part bound')
    for index,p in enumerate(case['parts']):
        a,source,table=PARTS[index],MODELS[index],TABLES[index]
        m.wq(a,table);m.wq(a+8,source)
        m.wq(table+0x58,0x1400616f0 if p['kind']=='dummy' else 0x14008c4e0)
        m.wq(table+0xa0,0x14008c4d0 if p['kind']=='skin' else 0x1400616e0)
        write_floats(a+0x10,p['position']);write_floats(a+0x1c,p['quaternion_wxyz']);m.wf(a+0x2c,p['scale'])
        u.mem_write(a+0x34,bytes([int(p['enabled'])]));m.wf(a+0xa8,p['alpha'])
        u.mem_write(source+0x98,bytes([0x21]));write_floats(source+0xc0,p['bounds'][0]+p['bounds'][1]);m.wi(source+0x118,p['source_render'])
        m.wq(a+0x38,a+0x200);m.wi(a+0x40,len(p['children']))
        for n,child in enumerate(p['children']):m.wq(a+0x200+n*8,PARTS[child])
    write_floats(POS,case['parent_position']);write_floats(QUAT,case['parent_quaternion_wxyz']);write_floats(COLOUR,case['rgb']);write_floats(CAMERA+0xb0,case['camera'])
    m.wq(0x1412e0318,CAMERA);m.wf(0x14128ec2c,case['intensity']);m.wi(COUNT,0)
    u.mem_write(OUTPUT,bytes([0xcd])*0x2000)
    for reg,v in [(UC_X86_REG_RCX,SCENE),(UC_X86_REG_RDX,PARTS[0]),(UC_X86_REG_R8,POS),(UC_X86_REG_R9,QUAT)]:u.reg_write(reg,v)
    m.wf(sp+0x28,case['parent_scale']);m.wq(sp+0x30,COLOUR);m.wf(sp+0x38,case['pulse_size']);m.wq(sp+0x40,OUTPUT);m.wq(sp+0x48,COUNT)
    u.emu_start(0x1400d4f30,m.stop,count=100000)
    if u.reg_read(UC_X86_REG_RIP)!=m.stop:raise RuntimeError('Leaf did not return')
    count=m.si(COUNT)
    if count<0 or count>144:raise RuntimeError('Vertex bound')
    if bytes(u.mem_read(OUTPUT+count*24,64))!=bytes([0xcd])*64:raise RuntimeError('Output tail overwritten')
    raw=bytes(u.mem_read(OUTPUT,count*24))
    return dict(case=case,count=count,vertex_words=[list(struct.unpack('<6I',raw[n*24:n*24+24])) for n in range(count)],output_sha256=hashlib.sha256(raw).hexdigest(),parent_position_words=words(POS,3),parent_quaternion_words=words(QUAT,4),visited_sqrt=0x140c7d6d8 in visited)
def attenuation(alpha,rgb):
    global operation
    operation='gob-alpha';sp=reset();u.reg_write(UC_X86_REG_RDI,GOB);m.wf(GOB+0x108,alpha)
    write_floats(sp+0x68,rgb);u.reg_write(UC_X86_REG_XMM10,fw(.4));u.reg_write(UC_X86_REG_XMM9,fw(rgb[0])|(fw(rgb[1])<<32));u.reg_write(UC_X86_REG_R13,fw(rgb[2]))
    u.emu_start(0x1400c8529,m.stop,count=1000)
    if u.reg_read(UC_X86_REG_RIP)!=0x1400c8586:raise RuntimeError('Alpha slice did not complete')
    return dict(alpha_word=fw(alpha),rgb_words=[fw(x) for x in rgb],output_rgb_words=words(sp+0x68,3))
def pulse(phase,delta,amplitude,frequency,size):
    global operation
    operation='pulse';reset();u.reg_write(UC_X86_REG_R15,SCENE);m.wf(SCENE+0xb0,phase)
    for address,value in [(0x14128e030,delta),(0x14128ec28,amplitude),(0x14128ec24,frequency),(0x14128ec20,size)]:m.wf(address,value)
    m.wi(0x1415d8224,0) # Select original non-AVX CPU math branch explicitly.
    u.emu_start(0x1400c83ce,m.stop,count=15000)
    if u.reg_read(UC_X86_REG_RIP)!=0x1400c8469:raise RuntimeError('Pulse slice did not complete')
    return dict(phase_word=fw(phase),delta_word=fw(delta),amplitude_word=fw(amplitude),frequency_word=fw(frequency),size_word=fw(size),new_phase_word=word(SCENE+0xb0),pulse_size_word=u.reg_read(UC_X86_REG_XMM8)&0xffffffff)
def main():
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);args=p.parse_args();output=Path(args.output).resolve()
    boundary=(ROOT/'godot-client/.cache/native-presentation-parity/render-agent').resolve()
    if not output.is_relative_to(boundary) or output.exists():raise RuntimeError('Fresh owned output required')
    base=dict(name='identity',parts=[part()],parent_position=[0,0,0],parent_quaternion_wxyz=[1,0,0,0],parent_scale=1,rgb=[.25,.5,.75],camera=[7,11,13],intensity=.3,pulse_size=2.5)
    cases=[base,base|dict(name='door-alpha-zero',parts=[part(alpha=0)]),base|dict(name='authored-render-zero',parts=[part(source_render=0)]),base|dict(name='disabled',parts=[part(enabled=False)]),base|dict(name='skin-excluded',parts=[part(kind='skin')])]
    for camera,scale,pulse_size in itertools.product([[20,0,0],[0,20,0],[0,0,20],[7,11,13],[0,0,0]],[1,-1,0,.25],[1,2.5]):cases.append(base|dict(name=f'camera-scale-{len(cases)}',camera=camera,parent_scale=scale,pulse_size=pulse_size))
    qx=[math.sqrt(.5),math.sqrt(.5),0,0];qz=[math.sqrt(.5),0,0,math.sqrt(.5)]
    for ps,cs,kind in itertools.product([1,-2],[.5,-1],['dummy','trimesh','skin']):
        cases.append(base|dict(name=f'hierarchy-{len(cases)}',parent_position=[3,-5,7],parent_quaternion_wxyz=qx,parent_scale=ps,parts=[part(kind=kind,position=[1,2,3],quaternion_wxyz=qz,scale=cs,children=[1]),part(position=[4,2,-1],quaternion_wxyz=qx,bounds=[[0,-.29,0],[2,.5,3.5]])]))
    cases += [base|dict(name='disabled-parent-prunes-child',parts=[part(kind='dummy',enabled=False,children=[1]),part()]),base|dict(name='skin-parent-still-recurses',parts=[part(kind='skin',children=[1]),part()]),base|dict(name='dummy-parent-still-recurses',parts=[part(kind='dummy',children=[1]),part()]),base|dict(name='degenerate-authored-bounds',parts=[part(bounds=[[0,0,0],[0,0,0]])])]
    rows=[leaf(c) for c in cases];checks=0
    def check(condition,message):
        nonlocal checks
        checks+=1
        if not condition:raise AssertionError(message)
    check(rows[0]['vertex_words']==rows[1]['vertex_words'],'Part alpha0 changed highlight')
    check(rows[0]['vertex_words']==rows[2]['vertex_words'],'Source render flag changed leaf selector')
    check(rows[3]['count']==0 and rows[4]['count']==0,'Part enabled/skin gate')
    check(rows[-4]['count']==0 and rows[-3]['count']==18 and rows[-2]['count']==18,'Parent recursion gates')
    expected_uv=[(0,0),(1,0),(0,1),(0,1),(1,0),(1,1)]
    for row in rows:
        check(row['count']%18==0,'18 vertices per eligible Part')
        for index,v in enumerate(row['vertex_words']):check(v[4:]==[fw(x) for x in expected_uv[index%6]],'UV order')
    atten=[attenuation(a,rgb) for a,rgb in itertools.product([-1,0,.1,.2,struct.unpack('<f',struct.pack('<I',fw(.4)-1))[0],.4,.5,1],[[.25,.5,.75],[1,0,0]])]
    check(atten[10]['output_rgb_words']==atten[10]['rgb_words'],'Gob alpha .4 changed colour')
    check(atten[4]['output_rgb_words']!=atten[4]['rgb_words'],'Gob alpha .1 did not attenuate')
    pulses=[pulse(ph,dt,.5,fr,2.5) for ph,dt,fr in itertools.product([0,.25,math.pi,math.pi*2,math.pi*2+.1],[0,1/60,.2],[0,1,4])]
    result=dict(binary_sha256=m.digest,scope=__doc__,checks=checks,leaf_cases=len(rows),leaf=rows,gob_alpha_cases=atten,pulse_cases=pulses,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limitations=['Synthetic typed Parts/authored bounds and camera; no scene membership/GL draw/real assets.','Leaf executes original math including finite SQRTSS; nonfinite exceptional CRT paths are outside this corpus.','Gob attenuation and pulse execute bounded original Scene slices, not complete DoHighlightGob iteration.','Pulse explicitly selects original SSE sinf CPU branch; actual host AVX/FMA branch is not claimed byte-equivalent.'])
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(output=str(output),checks=checks,leaf_cases=len(rows),alpha_cases=len(atten),pulse_cases=len(pulses))))
if __name__=='__main__':main()
