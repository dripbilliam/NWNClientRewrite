"""Original highlight leaf over the actual-model trace's typed hierarchy.

This tests actual bbox/pose bridge inputs, not a live native object's runtime
kind or Part34. Constructor-enabled/source-kind assumptions remain explicit.
"""
import argparse, hashlib, importlib.util, json, math, struct, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
source=ROOT/'godot-client/tools/native_parity/visibility/capture_highlight_leaf_oracle.py'
spec=importlib.util.spec_from_file_location('claddath_original_leaf',source)
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
u=original.u;m=original.m
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RIP

def run(trace):
    original.operation='leaf';sp=original.reset()
    rows=trace['original_tree_candidate']
    if len(rows)>64:raise RuntimeError('Actual source tree outside64-Part fixture bound')
    parts=[m.heap+0x10000+n*0x400 for n in range(len(rows))]
    models=[m.heap+0x30000+n*0x400 for n in range(len(rows))]
    tables=[m.heap+0x50000+n*0x1000 for n in range(len(rows))]
    children={n:[] for n in range(len(rows))}
    for row in rows:
        if row['parent']>=0:children[row['parent']].append(row['index'])
    for row in rows:
        index=row['index'];a,model,table=parts[index],models[index],tables[index]
        flags=row['mdl_flags'];kind='skin' if flags&0x40 else 'trimesh' if flags&0x20 else 'dummy'
        m.wq(a,table);m.wq(a+8,model)
        m.wq(table+0x58,0x1400616f0 if kind=='dummy' else 0x14008c4e0)
        m.wq(table+0xa0,0x14008c4d0 if kind=='skin' else 0x1400616e0)
        original.write_floats(a+0x10,row['position']);original.write_floats(a+0x1c,row['quaternion_wxyz']);m.wf(a+0x2c,row['scale'])
        u.mem_write(a+0x34,b'\x01');m.wf(a+0xa8,1.0)
        bounds=row['bounds'] or {'min':[0,0,0],'max':[0,0,0]}
        u.mem_write(model+0x98,b'\x21');original.write_floats(model+0xc0,bounds['min']+bounds['max']);m.wi(model+0x118,1)
        if len(children[index])>32:raise RuntimeError('Child table bound')
        m.wq(a+0x38,a+0x200);m.wi(a+0x40,len(children[index]))
        for at,child in enumerate(children[index]):m.wq(a+0x200+at*8,parts[child])
    original.write_floats(original.POS,[-3.5,0,0]);original.write_floats(original.QUAT,[1,0,0,0]);original.write_floats(original.COLOUR,[0,1,0]);original.write_floats(original.CAMERA+0xb0,trace['camera']['native'])
    m.wq(0x1412e0318,original.CAMERA);m.wf(0x14128ec2c,.3);m.wi(original.COUNT,0)
    output=m.heap+0x90000;u.mem_write(output,bytes([0xcd])*0x10000)
    for reg,value in [(UC_X86_REG_RCX,original.SCENE),(UC_X86_REG_RDX,parts[0]),(UC_X86_REG_R8,original.POS),(UC_X86_REG_R9,original.QUAT)]:u.reg_write(reg,value)
    m.wf(sp+0x28,1.0);m.wq(sp+0x30,original.COLOUR);m.wf(sp+0x38,trace['pulse']['size']);m.wq(sp+0x40,output);m.wq(sp+0x48,original.COUNT)
    u.emu_start(0x1400d4f30,m.stop,count=1000000)
    if u.reg_read(UC_X86_REG_RIP)!=m.stop:raise RuntimeError('Original actual-model tree did not return')
    count=m.si(original.COUNT)
    if count!=trace['source_counts']['eligible_parts']*18:raise RuntimeError('Original tree/Source.collect membership differ')
    raw=bytes(u.mem_read(output,count*24))
    if bytes(u.mem_read(output+count*24,64))!=bytes([0xcd])*64:raise RuntimeError('Original output tail overwritten')
    expected=[point for row in trace['parts'] if row['current_source_eligible'] for point in row['projected_vertices']]
    maximum=0.0;failures=[];per_part=[]
    for n in range(count):
        values=struct.unpack('<IfffII',raw[n*24:n*24+24]);actual=[values[1],values[3],-values[2]]
        error=math.sqrt(sum((actual[k]-expected[n][k])**2 for k in range(3)));maximum=max(maximum,error)
        tolerance=max(1e-5,math.sqrt(sum(x*x for x in expected[n]))*2e-6)
        if error>tolerance:failures.append({'vertex':n,'error':error,'tolerance':tolerance,'original_godot':actual,'bridge':expected[n]})
        if n%18==0:per_part.append({'part':next(row['name'] for row in trace['parts'] if row['current_source_eligible'] and row['projected_vertices'][0]==expected[n]),'first_original_godot':actual})
    return {'success':not failures,'vertices':count,'eligible_parts':count//18,'maximum_position_error':maximum,'failures':failures[:20],'original_output_sha256':hashlib.sha256(raw).hexdigest(),'per_part':per_part}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--trace',required=True);parser.add_argument('--output',required=True);args=parser.parse_args()
    trace_file=Path(args.trace).resolve();output=Path(args.output).resolve();boundary=(ROOT/'godot-client/.cache/native-presentation-parity/loading-agent').resolve()
    if not output.is_relative_to(boundary) or output.exists():raise RuntimeError('Fresh owned output required')
    raw=trace_file.read_bytes();trace=json.loads(raw)
    result=run(trace);result.update({'binary_sha256':original.SHA,'trace':{'file':str(trace_file),'sha256':hashlib.sha256(raw).hexdigest()},'oracle_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'scope':__doc__,'assumptions':['Original Part34 constructor/tree default enabled is modeled; no original running object field is claimed.','Runtime type selectors modeled from actual MDL kinds and recovered construction callbacks; later native API mutations are not observed.','Current native-clip local transforms come from the V5 actual physical hierarchy trace; original game process is not attached.'],'network_connections':0,'gpu_draws':0,'native_builds':0})
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({key:result[key]for key in ['success','vertices','eligible_parts','maximum_position_error','failures','original_output_sha256']}));sys.exit(0 if result['success'] else 1)
if __name__=='__main__':main()
