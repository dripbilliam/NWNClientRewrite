"""Execute original TileData reuse/allocate, SetPosition, GetTileData and Part+a0
instructions. Reuses the pinned original BSP harness without editing it.
SpawnTile slice0d4463..0d44b3 executes the real reuse/new branch and constructor;
subsequent original AddTileData installs the pointer. Model/Part geometry creation
and full rendering are deliberately outside this oracle.
"""
import argparse,hashlib,importlib.util,json,struct
from pathlib import Path
SOURCE=Path(__file__).resolve()
spec=importlib.util.spec_from_file_location('native_bsp_oracle',SOURCE.with_name('capture_bsp_collector_oracle.py'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
b.RANGES.extend([(0x1402c58d0,0x1402c5935),(0x1400dd7b0,0x1400dd7de),
 (0x1400d4463,0x1400d44b3),(0x140088130,0x14008821d),(0x1400cb660,0x1400cb667),
 (0x1402295a0,0x140229686),(0x14022b350,0x14022b3ab)])
stop_at=0
def stop_hook(_u,address,_size,_data):
 if address==stop_at:b.u.emu_stop()
b.u.hook_add(UC_HOOK_CODE,stop_hook)
def execute_to(address,stop):
 global stop_at
 stop_at=stop;b.u.emu_start(address,b.m.stop,count=100000)
 if b.u.reg_read(UC_X86_REG_RIP)!=stop:raise RuntimeError('Original slice did not reach exact boundary')
 stop_at=0
def initialize(width,height,margin,cell):
 b.reset();b.phase='build';sp=b.call(0x1400ca3b0,b.SCENE,width,height,margin);b.m.wq(b.SCENE,b.TABLE);b.m.wq(b.TABLE+0x260,b.BINS);b.u.mem_write(sp+0x28,b'\1');b.m.wf(sp+0x30,cell);b.execute(0x1400ca3b0)
 return b.native_tree()
def position(x,y,height,transition):
 b.phase='setposition';tile=b.m.heap+0x7000;sp=b.call(0x1402c58d0,tile,x&0xffffffff,y&0xffffffff,height&0xffffffff);b.m.wf(sp+0x28,transition);b.execute(0x1402c58d0,1000)
 return list(struct.unpack('<3f',b.u.mem_read(tile+8,12)))
def fitted(point,lookup):
 b.floats(b.POSITION,point);b.call(0x140229690,b.m.q(b.SCENE+0x188),b.POSITION);b.u.reg_write(UC_X86_REG_XMM2,0);b.execute(0x140229690,10000)
 return lookup[b.u.reg_read(UC_X86_REG_RAX)]
def spawn(point,lookup,pointers):
 b.phase='spawn';b.floats(b.POSITION,point);sp=b.call(0x1400d4463);b.m.wq(sp+0x50,b.SCENE)
 b.u.reg_write(UC_X86_REG_R14,b.POSITION);b.u.reg_write(UC_X86_REG_RSI,0);b.u.reg_write(UC_X86_REG_R13,0);b.u.reg_write(UC_X86_REG_RDI,0)
 before=b.next_alloc;execute_to(0x1400d4463,0x1400d44b3);pointer=b.u.reg_read(UC_X86_REG_RBX);allocated=b.next_alloc!=before
 if pointer not in pointers:pointers[pointer]=len(pointers)+1
 token=pointers[pointer];node=fitted(point,lookup)
 b.call(0x1400dd340,b.SCENE,pointer,b.PARTS,b.POSITION);b.execute(0x1400dd340,10000)
 b.call(0x1400dd7b0,b.SCENE,b.POSITION);b.execute(0x1400dd7b0,10000)
 if b.u.reg_read(UC_X86_REG_RAX)!=pointer:raise RuntimeError('Installed physical TileData differs')
 return dict(token=token,allocated=allocated,node=node,position_words=[b.fw(v) for v in point],tile_anchor_words=b.words(pointer+0x48,3),constructor_fogged=b.u.mem_read(pointer+0xc4,1)[0],constructor_factor_word=b.words(pointer+0xc8,1)[0]),pointer
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);args=p.parse_args();target=Path(args.output).resolve();boundary=(b.ROOT/'godot-client/.cache/native-presentation-parity/loading-agent').resolve()
 if not target.is_relative_to(boundary) or target.exists():raise RuntimeError('Fresh owned output required')
 rows,lookup=initialize(2,2,1,10);pointers={};registrations=[];parts=[]
 inputs=[('terrain:0','canonical',[0,0,0,1]),('terrain:1','canonical',[1,0,2,1.5]),('terrain:2','canonical',[0,1,-2,.25]),('terrain:3','canonical',[1,1,1,.125]),('static-one','static',[9.5,8.5,5.]),('static-two','static',[10.,5.,0.]),('border-one','border',[-5.,5.,0.]),('outside-one','border',[-100.,5.,0.]),('outside-two','border',[-110.,15.,0.]),('above-one','static',[5.,5.,10000.]),('above-two','static',[15.,15.,10001.]),('static-one-repeat','static',[9.5,8.5,5.])]
 for key,kind,value in inputs:
  point=position(*value) if kind=='canonical' else value
  result,pointer=spawn(point,lookup,pointers);registrations.append(dict(key=key,kind=kind,input=value,expected=result))
  for label,low,high in [('small',[point[0]-.25,point[1]-.25,point[2]-.25],[point[0]+.25,point[1]+.25,point[2]+.25]),('large',[-5.,-5.,-1.],[25.,25.,10.])]:
   b.phase='part-write';part=b.m.heap+0x9000;b.call(0x1400cb660);b.u.reg_write(UC_X86_REG_RSI,part);b.u.reg_write(UC_X86_REG_RBX,pointer);execute_to(0x1400cb660,0x1400cb667)
   b.floats(b.POSITION,low);b.floats(b.POSITION+16,high);b.call(0x1402295a0,b.m.q(b.SCENE+0x188),b.POSITION,b.POSITION+16);b.execute(0x1402295a0,10000);mesh_node=lookup[b.u.reg_read(UC_X86_REG_RAX)]
   parts.append(dict(placement=key,label=label,world_low=low,world_high=high,mesh_node=mesh_node,tile_node=result['node'],part_tile_token=pointers[b.m.q(part+0xa0)]))
 set_cases=[]
 for value in [(0,0,0,1),(1,1,-2,1.25),(-5,-5,3,.125),(16777217,-16777217,-2147483648,.03125),(2147483647,-2147483648,2147483647,.00001)]:set_cases.append(dict(input=value,position_words=[b.fw(v) for v in position(*value)]))
 output=dict(binary_sha256=b.m.digest,source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),bsp_harness_sha256=hashlib.sha256(SOURCE.with_name('capture_bsp_collector_oracle.py').read_bytes()).hexdigest(),scope=__doc__,area=dict(width=2,height=2,margin=1,cell=10),tree=rows,registrations=registrations,parts=parts,setposition_cases=set_cases,limitations=['Original SpawnTile reuse/allocation slice and TileData constructor run, not complete model loading/collapse or renderer.','Part+a0 is the exact original ProcessStaticParts store instruction; source Part type/geometry is controlled input.','Original BSPFitBox runs on explicit supplied native world bounds; this oracle does not derive those bounds from Godot meshes.','Pointer values are normalized to first-allocation integer tokens; identity equivalence and allocation order are preserved.','No process attach, renderer, GPU, server, OS clock or shared native build.'])
 target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(output,indent=2)+'\n');print(json.dumps(dict(output=str(target),registrations=len(registrations),physical_tiledata=len(pointers),parts=len(parts),setposition_cases=len(set_cases))))
if __name__=='__main__':main()
