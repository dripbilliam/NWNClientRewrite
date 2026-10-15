"""Read-only build89 MakeSpawnList, PadOutCreatureCount and AddCreaturesToSpawnList
full native owner executions. Synthetic physical CR/point/flag records and CRT
draw stream; CResRef copy and CalculatePointsFromCR are captured substitutes.
Instruction-budget exhaustion is retained as a nonterminating fixture outcome,
not converted into a successful native return. Not full spawning/heap proof.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
enc,entries,out,count,chosen=[heap+n*0x2000 for n in range(5)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
def hook(u,a,n,_):
    global draws
    if a==stop:u.emu_stop();return
    if a==0x14018de80:
        x,y=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]];u.mem_write(x,bytes(u.mem_read(y,17)));finish(x)
    elif a==0x140c7ed00:
        value=case['random'][draws%len(case['random'])];draws+=1;finish(value)
    elif a==0x14043b220:
        cr=struct.unpack('<f',u.reg_read(UC_X86_REG_XMM1).to_bytes(16,'little')[:4])[0];cost=next((e['points'] for e in case['entries'] if f(e['cr'])==cr),f(1.5**cr));u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',cost),'little'));finish()
    elif not any(start<=a<end for start,end in [(0x14043cc00,0x14043cf90),(0x14043cf90,0x14043d1a1),(0x14043adf0,0x14043b051)]):raise RuntimeError(f'Unmapped encounter spawn dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def write_entry(p,e):
    wi(p,e['id']);wf(p+0x14,e['cr']);wf(p+0x18,e['points']);wi(p+0x1c,e.get('used',0));wi(p+0x20,e.get('visited',0));wi(p+0x24,e.get('single',0))
def read_entry(p):return dict(id=i(p),cr=rf(p+0x14),points=rf(p+0x18),used=i(p+0x1c),visited=i(p+0x20),single=i(p+0x24))
def run(c):
    global case,draws
    case=c;draws=0;u.mem_write(heap,bytes(0x20000));wi(enc+0x33c,c['maximum']);wi(enc+0x338,c['recommended']);wi(enc+0x340,c['spawned']);wf(enc+0x3c4,c['pool']);wf(enc+0x3c8,c['activePool']);wf(enc+0x3bc,c['minimum']);wi(enc+0x398,len(c['entries']));wq(enc+0x390,entries);wi(count,len(c['initial']))
    for n,e in enumerate(c['entries']):write_entry(entries+n*0x28,e)
    for n,e in enumerate(c['initial']):write_entry(out+n*0x28,e)
    write_entry(chosen,c['chosen']);rsp=stack+0xff08;u.mem_write(rsp-0x1000,bytes(0x1080));wq(rsp,stop);wq(rsp+0x28,chosen)
    for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP],[enc,out,count,c['index'],rsp]):u.reg_write(r,v)
    u.emu_start({'make':0x14043cc00,'pad':0x14043cf90,'split':0x14043adf0}[c['mode']],stop,count=20000)
    completed=u.reg_read(UC_X86_REG_RIP)==stop
    return {'case':c,'completed':completed,'out':[read_entry(out+n*0x28) for n in range(i(count))] if completed else None,'entries':[read_entry(entries+n*0x28) for n in range(len(c['entries']))] if completed else None,'draws':draws if completed else None}
e=lambda id,cr,**flags:dict(id=id,cr=cr,points=f(1.5**cr),used=flags.get('used',0),visited=flags.get('visited',0),single=flags.get('single',0))
default=dict(maximum=4,recommended=2,spawned=0,pool=5,activePool=0,minimum=1,entries=[],initial=[],random=[0,1,2,3,4,5,6,7],index=0,chosen=e(91,2))
lists=[[],[e(1,0)],[e(1,1)],[e(1,3),e(2,2),e(3,1)],[e(1,2),e(2,2)],[e(1,2,single=1),e(2,2)],[e(1,2,single=1),e(2,2,single=1)],[e(1,2,single=1,used=1),e(2,2,single=1,used=1)],[e(1,3),e(2,2,single=1),e(3,2),e(4,1)]]
cases=[]
for mode,entries_case,pool,activePool,maximum,spawned,recommended in itertools.product(['make','pad'],lists,[0,.1,1,2.25,5],[0,1],[0,1,4],[0,1],[0,2]):cases.append(default|dict(mode=mode,entries=entries_case,pool=pool,activePool=activePool,maximum=maximum,spawned=spawned,recommended=recommended))
for initial,index,entries_case,minimum,maximum,recommended,spawned in itertools.product([[],[e(91,2)],[e(91,2),e(92,1)]],[0,1],lists,[0,2.25],[1,4],[0,2],[0,1]):cases.append(default|dict(mode='split',initial=initial,index=index,entries=entries_case,minimum=minimum,maximum=maximum,recommended=recommended,spawned=spawned))
observations=[run(c) for c in cases];output=root/'backups/animations/native-encounter-spawn-list-observations.json';output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2));print(json.dumps({'output':str(output),'observations':len(observations),'nonterminating':sum(not r['completed'] for r in observations)}))
