"""Complete original Gob08f680, Part08f560/08f740 weighted-part selection.
Synthetic physical trees use original stored mesh areas, native recursive child
order, FLOAT arithmetic and cache. Mesh subtype query and CRT draws are captured
lowers; no geometry generation, model loading, renderer or native assets copied.
Also execute full header copier078ab0 to verify disk268 -> runtime2bc.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
gob,parts,vt,geometry,serialized=[m.heap+n for n in [0x3000,0x4000,0x9000,0xa000,0xc000]]
ranges=[]
for name in ['rea-network-ranged-gob-random-impact','rea-network-ranged-part-area','rea-network-ranged-part-select']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
ranges.append((0x140078ab0,0x140078e60))
case={};draws=0
def hook(u,a,n,data):
 global draws
 x,y=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==m.stop+0x58:
  index=(x-parts)//0x500;m.finish(x if case['areas'][index]is not None else 0);return
 if a==0x140c7ed00:draws+=1;m.finish(case['draw']);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
trees=[dict(areas=[None,1,2,None,3],parents=[-1,0,0,0,3]),dict(areas=[1,2,3,None,4],parents=[-1,0,1,0,3]),dict(areas=[None,0,0,None,0],parents=[-1,0,0,1,2]),dict(areas=[None,.0001,10000,None,.25],parents=[-1,0,0,1,1])]
for tree,draw,cached in itertools.product(trees,[0,1,4999,5000,9999,10000,32767],[-1,0,10]):
 case=tree|dict(draw=draw,cached=cached);draws=0;t.reset(dict(format=1));m.wq(gob+0x90,parts);m.wf(gob+0x4b8,cached)
 for index,area in enumerate(case['areas']):
  p=parts+index*0x500;mesh=geometry+index*0x400;m.wq(p,vt);m.wq(vt+0x58,m.stop+0x58);m.wq(p+8,mesh);m.wi(mesh+0x98,0x21);m.wf(mesh+700,area or 0);u.mem_write(mesh+0x38,f'part{index}'.encode()+b'\0')
  children=[parts+i*0x500 for i,parent in enumerate(case['parents'])if parent==index];m.wq(p+0x38,p+0x200);m.wi(p+0x40,len(children))
  for i,child in enumerate(children):m.wq(p+0x200+i*8,child)
 result=w.call(0x14008f680,[gob]);ptr=u.reg_read(UC_X86_REG_RAX);name=bytes(u.mem_read(ptr,16)).split(b'\0')[0].decode()if ptr else None
 rows.append(dict(case=case,name=name,area=m.rf(gob+0x4b8),draws=draws))
copies=[]
for value in [0,.0001,1,123.5,-1]:
 t.reset(dict(format=1));m.wf(serialized+0x268,value);w.call(0x140078ab0,[serialized,geometry]);copies.append(dict(value=value,result=m.rf(geometry+700)))
out=m.root/'backups/animations/native-model-random-part-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,copies=copies),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),copies=len(copies),output=str(out))))
