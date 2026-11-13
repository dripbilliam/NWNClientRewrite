"""Original full0dc140 TileData C8 callback and full AuroraSetTileFoggedByWar.
Unrelated native Gob/emitter/Part lists are empty; no callback math is replaced.
FindScene is the single controlled mainscene identity boundary. Original setter
BSPSearch/predicate, reset and original signed-low32 DeltaT writer all execute.
"""
import argparse,hashlib,importlib.util,json
from pathlib import Path
SOURCE=Path(__file__).resolve()
spec=importlib.util.spec_from_file_location('native_tile_participant_oracle',SOURCE.with_name('capture_tile_data_participants_oracle.py'))
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p);b=p.b
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
b.RANGES.extend([(0x1400dc140,0x1400dc8f3),(0x1400dc900,0x1400dcc10),
 (0x1400a5070,0x1400a50ea),(0x1400a5100,0x1400a5110),(0x140229980,0x140229a5f),(0x1400c9840,0x1400c9840)])
setter_node=0
def extra_hook(_u,address,_size,_data):
 global setter_node
 if address==0x1400c9840:b.m.finish(b.SCENE)
 elif address==0x1400a50b8:setter_node=b.u.reg_read(UC_X86_REG_RAX)
b.u.hook_add(UC_HOOK_CODE,extra_hook)
def main():
 global setter_node
 parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args();target=Path(args.output).resolve();boundary=(b.ROOT/'godot-client/.cache/native-presentation-parity/loading-agent').resolve()
 if not target.is_relative_to(boundary) or target.exists():raise RuntimeError('Fresh owned output required')
 rows,lookup=p.initialize(2,2,1,10);pointers={};placements=[];ptrs=[];node_addresses=[]
 for key,point in [('canonical-one',[5.,5.,0.]),('canonical-two',[15.,5.,0.]),('outside',[-100.,5.,0.])]:
  result,pointer=p.spawn(point,lookup,pointers);ptrs.append(pointer);node_addresses.append(next(a for a,i in lookup.items() if i==result['node']));placements.append(dict(key=key,point=point,expected=result))
 # Empty native lists avoid unrelated renderer/Part/Gob execution. The full
 # callback still executes its real entry, TileData branch and epilogue.
 b.m.wq(0x14140ac50,0);b.m.wi(0x14128ebec,0);b.m.wi(0x14128ec18,0)
 def state():return [dict(token=pointers[ptr],fogged=b.u.mem_read(ptr+0xc4,1)[0],factor_word=b.words(ptr+0xc8,1)[0]) for ptr in ptrs]
 def reset(factor,flag):
  for ptr in ptrs:b.u.mem_write(ptr+0xc4,bytes([flag]));b.m.wi(ptr+0xc8,factor)
 def callback(which,delta):
  converted=b.delta_case(delta);b.phase='callback';b.call(0x1400dc140,node_addresses[which],b.SCENE,b.PLANES);b.execute(0x1400dc140,20000)
  return dict(kind='collect',token=which+1,primary_words=dict(hi=delta>>32,lo=delta&0xffffffff),renderer_delta_t_word=converted['delta_t_word'],expected=state())
 def setter(point,flag):
  global setter_node
  setter_node=0;b.phase='setter';b.floats(b.POSITION,point);b.call(0x1400a5070,b.POSITION,flag);b.execute(0x1400a5070,20000)
  ptr=b.m.q(b.m.q(setter_node+0x70)+0x98)
  return dict(kind='set_fogged',position=point,flag=bool(flag),target_token=pointers[ptr],target_node=lookup[setter_node],expected=state())
 callback_cases=[]
 for factor in [-1.,0.,.25,.999,1.,1.5]:
  for flag in [0,1]:
   for delta in [0,1,16666,0x7fffffff,0x80000000,0xffffffff,0x100000001,0xffffffffffffffff]:
    reset(b.fw(factor),flag);initial=state();trace=[callback(0,delta) for _ in range(3)]
    callback_cases.append(dict(initial=initial,trace=trace))
 reset(b.fw(.75),0);initial=state()
 setter_trace=[setter([5.,5.,0.],1),setter([5.,5.,0.],1),callback(0,16666),setter([5.,5.,0.],0),callback(0,16666),callback(0,16666),setter([5.,5.,0.],0),setter([5.,5.,0.],1),setter([15.,5.,0.],0),callback(1,0xffffffff)]
 setter_cases=[dict(initial=initial,trace=setter_trace)]
 # Exact split equality differs from radius0 FitSphere, and a missing nearby
 # TileData makes BSPSearch try the far subtree. Capture the actual targets.
 for point in [[10.,5.,0.],[5.,15.,0.],[-10.,5.,0.],[5.,5.,-30.],[20.,20.,0.]]:
  reset(b.fw(.75),0);setter_cases.append(dict(initial=state(),trace=[setter(point,1)]))
 output=dict(binary_sha256=b.m.digest,source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),participant_harness_sha256=hashlib.sha256(SOURCE.with_name('capture_tile_data_participants_oracle.py').read_bytes()).hexdigest(),bsp_harness_sha256=hashlib.sha256(SOURCE.with_name('capture_bsp_collector_oracle.py').read_bytes()).hexdigest(),scope=__doc__,placements=placements,callback_cases=callback_cases,setter_cases=setter_cases,limitations=['Original full callback executes on controlled real BSP/TileData with empty unrelated Part/Gob/emitter lists; this is not full renderer execution.','FindScene mainscene identity is captured to the controlled source Scene; the complete setter, BSPSearch and predicate execute unchanged.','Controlled initial C4/C8 words are explicit native memory inputs; original callback/setter outputs are never calculated by Python.','Primary delta snapshots execute the original signed-low32 writer, not a Python/OS clock formula.','No live process, GPU, server, production fog activation, shared native rebuild or FPS claim.'])
 target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(output,indent=2)+'\n');print(json.dumps(dict(output=str(target),callback_cases=len(callback_cases),callbacks=sum(len(c['trace']) for c in callback_cases),setter_cases=len(setter_cases),physical_tiledata=len(ptrs))))
if __name__=='__main__':main()
