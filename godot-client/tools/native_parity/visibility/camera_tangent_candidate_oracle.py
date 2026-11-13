"""Executed original SSE tanf for native perspective half-FOV, no host tan.

The original DegToRad and tanf instructions execute in Unicorn. Explicit
MXCSR=0x1f80, CPU dispatch DWORD=0. No FMA/native process/renderer/build/server.
Only the bounded perspective domain reaches the admitted instruction ranges.
"""
import argparse, hashlib, importlib, json, random, struct, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator')
u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
SHA='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if m.digest!=SHA:raise RuntimeError('Original binary identity differs')
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def fw(v):return struct.unpack('<I',struct.pack('<f',v))[0]
def fs(v):return struct.unpack('<f',struct.pack('<I',v))[0]
def word(a):return struct.unpack('<I',u.mem_read(a,4))[0]
visited=set();all_visited=set();steps=0
def hook(_u,address,_size,_data):
 global steps
 if address==m.stop:u.emu_stop();return
 if not (0x14022c210<=address<=0x14022c218 or 0x140c7d790<=address<=0x140c7d8f3 or 0x140c7da56<=address<=0x140c7dae8):raise RuntimeError(f'Unadmitted perspective SSE dependency {address:x}')
 steps+=1;visited.add(address);all_visited.add(address)
u.hook_add(UC_HOOK_CODE,hook)
def execute(address,input_word):
 sp=m.stack+0x1fe08;u.mem_write(sp-0x100,bytes(0x108));m.wq(sp,m.stop)
 u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 for reg in [UC_X86_REG_XMM0,UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3,UC_X86_REG_XMM4,UC_X86_REG_XMM5]:u.reg_write(reg,0)
 u.reg_write(UC_X86_REG_XMM0,input_word);m.wi(0x1415d8224,0)
 u.emu_start(address,m.stop,count=200)
 if u.reg_read(UC_X86_REG_RIP)!=m.stop:raise RuntimeError('Perspective instruction bound/no return')
 return u.reg_read(UC_X86_REG_XMM0)&0xffffffff
CONSTANTS={
 'degrees_to_radians':(0x140d83b68,4),
 'poly_n0':(0x140ed2318,8),'poly_n1':(0x140ed2310,8),
 'poly_d0':(0x140ed2330,8),'poly_d1':(0x140ed2328,8),'poly_d2':(0x140ed2320,8),
 'small_cubic':(0x140ed2348,8),'tiny_threshold':(0x140ed2350,8),'cubic_threshold':(0x140ed2358,8),
 'reduction_round':(0x140ed2360,8),'pi_over_two_hi':(0x140ed2368,8),'pi_over_two_lo':(0x140ed2370,8),
 'two_over_pi':(0x140ed22d0,8),'reciprocal_numerator':(0x140ed2380,8),'direct_threshold':(0x140ed2388,8),
 'tiny_status_multiplier':(0x140ed2398,4),'tiny_status_addend':(0x140ed23a8,4)}
def main():
 global visited,steps
 parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args()
 out=Path(args.output).resolve();boundary=(ROOT/'godot-client/.cache/native-presentation-parity/loading-agent').resolve()
 if not out.is_relative_to(boundary) or out.exists():raise RuntimeError('Fresh owned output required')
 constants={name:dict(address=hex(address),bytes_le=bytes(u.mem_read(address,size)).hex(),value=struct.unpack('<f' if size==4 else '<d',u.mem_read(address,size))[0]) for name,(address,size) in CONSTANTS.items()}
 inputs={}
 def add_word(value,category):
  if 0<value<fw(180.):inputs.setdefault(value,set()).add(category)
 def add(value,category):add_word(fw(value),category)
 for value in range(1,180):add(value,'integer-fov')
 for value in range(20,121):add(value,'ui-slider')
 for value in range(1,1440):add(value/8,'fractional-eighth')
 rng=random.Random(0x53534554414e)
 for _ in range(2048):add(rng.uniform(0,180),'fractional-random')
 for _ in range(2048):add_word(rng.randrange(1,fw(180.)),'native-word-random')
 for center in [1,2,3,4,7,0x007fffff,0x00800000,fw(90.),fw(180.)-1]:
  for offset in range(-32,33):add_word(center+offset,'native-edge-neighbours')
 for threshold in ['tiny_threshold','cubic_threshold','direct_threshold']:
  center=fw(constants[threshold]['value']*2/constants['degrees_to_radians']['value'])
  for offset in range(-32,33):add_word(center+offset,'branch-neighbours-'+threshold)
 for value in [1e-40,1e-30,1e-20,1e-10,1e-6,.001,.01,.1,20.1,33.333333,44.99999,45.00001,60.000003,89.99999,90.00001,119.99999,179.99]:add(value,'selected-fractional-extreme')
 rows=[];branches={}
 for angle_word,categories in sorted(inputs.items()):
  visited=set();steps=0
  half_word=fw(f(fs(angle_word)*.5))
  radians_word=execute(0x14022c210,half_word)
  tangent_word=execute(0x140c7d790,radians_word)
  branch='tiny-return' if 0x140c7d7e5 in visited else 'cubic' if 0x140c7d800 in visited else 'direct-rational' if 0x140c7d830 in visited else 'reduced-reciprocal'
  branches[branch]=branches.get(branch,0)+1
  rows.append(dict(angle_word=angle_word,half_angle_word=half_word,radians_word=radians_word,tangent_word=tangent_word,branch=branch,steps=steps,categories=sorted(categories)))
 evidence=ROOT/'godot-client/tools/native_parity/visibility/evidence/native-tile-fog-math-and-inputs-v1.json'
 original=json.loads(evidence.read_text())
 listing=original['records']['collector_deg_to_rad_evidence']['selection']['assembly']+original['records']['collector_tanf_evidence']['selection']['assembly']
 reached=[line for line in listing if int(line.split(':',1)[0],16) in all_visited]
 if len(reached)!=len(all_visited):raise RuntimeError('Reached instruction is absent from retained decoded source')
 result=dict(binary_sha256=SHA,oracle_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),loader_source_sha256=hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest(),evidence_sha256=hashlib.sha256(evidence.read_bytes()).hexdigest(),scope=__doc__,cpu_dispatch_word=0,mxcsr=0x1f80,constants=constants,cases=rows,branches=branches,visited_instructions=reached,limitations=['Original SSE branch only; FMA/AVX dispatch and floating-point status flags are not candidate output claims.','Positive finite native f32 FOV<180; f32 half and original f32 DegToRad before original tanf.','Synthetic CPU instruction oracle only, no original live viewport/process or production hook.'])
 out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(dict(output=str(out),cases=len(rows),branches=branches,reached_instructions=len(reached),maximum_steps=max(row['steps'] for row in rows))))
if __name__=='__main__':main()
