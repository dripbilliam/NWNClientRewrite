"""Complete original tile-part matcher, main-light palette apply and scene update.

Original matching, BYTE indices, six named table reads, conditional color
updates and radius/flag writes execute. String primitives, allocation/free,
2DA FLOAT getters, virtual AsPartLight, BSP lookup and static-light invalidation
are captured lower boundaries. Synthetic model names, palette values and light
memory are explicit inputs. No GPU/per-object selection/source-flame claim.
"""
import sys,importlib,json,itertools
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['tile-part','tile-main-apply','tile-set']:
 d=json.loads((m.root/'backups/animations'/('rea-network-light-'+name+'.json')).read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
tile,part,node,scene,vt,lights,rules,arrays,table,model=[m.heap+n*0x1000 for n in range(3,13)]
def cstr(ptr):
 data=bytes(u.mem_read(ptr,256));return data.split(b'\0')[0].decode('latin1')
def rgb(row):return [row/255,(255-row)/255,(row%3)/2]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c4eec0:
  raw=cstr(y).encode();u.mem_write(x,(raw+bytes(z))[:z]);m.finish(x);return
 if a==0x140c9a9fc:m.finish(0 if cstr(x).lower()==cstr(y).lower()else 1);return
 if a==m.stop+0x10:m.finish(lights if c.get('cast',True)else 0);return
 if a==0x1401a6c70:
  column=cstr(m.q(z));reads.append(dict(row=y&0xffffffff,column=column));m.wf(k,rgb(y&255)[['RED','GREEN','BLUE'].index(column)]);m.finish(1);return
 if a==0x1400dd7b0:m.finish(tile);return
 if a==0x1400de630:invalidated.append((y-lights)//0x200);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def reset(case):
 global c,reads,invalidated
 c=case;reads=[];invalidated=[];t.reset(dict(format=1));m.wq(part,vt);m.wq(part+8,node);m.wq(vt+0x48,m.stop+0x10);m.wq(scene,vt);m.wq(vt+0x38,0x1400d3e60);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,arrays);m.wq(arrays+0x1b8,table)
matching=[]
for prefix,suffix,cast in itertools.product(['tile','TileCase','x'*60,'x'*64],['ml1','ML2','sl1','SL2','unrelated'],[False,True]):
 reset(dict(cast=cast));u.mem_write(model,prefix.encode()+b'\0');u.mem_write(node+0x38,(prefix[:60]+suffix).encode()+b'\0');result=w.call(0x1400cb890,[tile,part,model,0]);matching.append(dict(prefix=prefix,node=prefix[:60]+suffix,cast=cast,result=bool(result),slots=[bool(m.q(tile+i*8))for i in range(4)]))
updates=[]
for first,second,present,equal in itertools.product([0,28,255,256,-1],[0,1,29,255],range(4),range(4)):
 reset(dict(first=first,second=second,present=present,equal=equal));before=[]
 for i,index in enumerate([first,second]):
  p=lights+i*0x200;m.wq(tile+i*8,p if present&(1<<i)else 0)
  color=rgb(index&255)if equal&(1<<i)else [-1,-1,-1]
  for k,v in zip([0x68,0x6c,0x70],color):m.wf(p+k,v)
  for k,v in [(0x74,17),(0x7c,19)]:m.wf(p+k,v)
  for k in [0x78,0x88,0x90]:m.wi(p+k,7)
 result=w.call(0x14084f9a0,[tile,first,second,scene]);state=[]
 for i in range(2):
  p=lights+i*0x200;state.append(dict(color=[m.rf(p+k)for k in [0x68,0x6c,0x70]],radius=m.rf(p+0x74),field78=m.si(p+0x78),shadowRadius=m.rf(p+0x7c),field88=m.si(p+0x88),priority=m.si(p+0x90)))
 updates.append(dict(case=c.copy(),indices=list(u.mem_read(tile+0x28,2)),reads=reads.copy(),invalidated=invalidated.copy(),lights=state))
assert len(updates)==320
# Static loader identity, separate from executed matching/update cases. No
# resource/game asset bytes are retained; only table name and instructions.
loader=[dict(address=hex(x.address),text=x.mnemonic+' '+x.op_str)for x in Cs(CS_ARCH_X86,CS_MODE_64).disasm(m.pe.get_data(0x2b5327,0x56),0x1402b5327)]
resource=m.pe.get_data(0xdc65f0,16).split(b'\0')[0].decode();assert resource=='LightColor';assert any(x['address']=='0x1402b536c'and x['text']=='mov qword ptr [rbx + 0x1b8], rax'for x in loader)
output=m.root/'backups/animations/native-tile-light-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,loader=dict(resource=resource,scope='Static disassembly only; loader not emulated',assembly=loader),matching=matching,updates=updates),indent=2)+'\n');print(json.dumps(dict(output=str(output),matching=len(matching),updates=len(updates))))
