"""Original tile traversal2bb580 and denied polygons2c3010 on exact local corner
queries and installed mesh. Mesh payloads stay in a Node->Python memory pipe.
Captured boundaries are tile location, allocation, Vector construction, copying
and stack-cookie check. Denied scratch flags are swept over all8zero/one inputs;
results must not be presented as independent native initial-stack evidence.
"""
import sys,importlib,json,subprocess,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-tile-traversal');m=p.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
def hook(u,a,n,data):
 if 0x1402c3010<=a<0x1402c382f or 0x140c7d6d8<=a<0x140c7d783:return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
data=json.loads(subprocess.check_output(['node','scripts/exact-corner-terrain-input.mjs'],cwd=m.root));mesh=data['mesh'];floatbits=data['meshFloatBits'];rows=[]
def denied(case,scratch):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));surface=m.heap;vertices=m.heap+0xa0000;faces=m.heap+0xb0000
 m.wq(surface+0x78,m.heap+0x1000);m.wq(surface+0xf8,vertices);m.wq(surface+0x108,faces);m.wi(surface+0x100,len(mesh['denied']['faces']))
 for i,v in enumerate(floatbits['deniedVertices']):
  for j,b in enumerate(v):m.wi(vertices+i*12+j*4,b)
 for i,face in enumerate(mesh['denied']['faces']):
  for j,index in enumerate(face):m.wi(faces+i*12+j*4,index)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface)
 for reg,value in zip([UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3],case['from']+[case['to'][0]]):u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 for offset,value in zip([0x28,0x30,0x38,0x40],[case['to'][1],case['low'],case['high'],case['radius']]):m.wf(rsp+offset,value)
 m.wi(rsp+0x48,case['flag'])
 for i,value in enumerate(scratch):m.wi(rsp-0xe0+i*4,value)
 u.emu_start(0x1402c3010,m.stop,count=3000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_EAX)
for case in data['cases']:
 if case['kind']=='clip':
  native=p.run(case,mesh,floatbits);rows.append(dict(case=case,result=native['result'],bits=native['bits'],limited=native['limited']));assert native['result']==case['expected'];assert native['bits']==case['expectedBits']
 else:
  values=[dict(scratch=list(s),result=denied(case,s))for s in itertools.product([0,1],repeat=3)];rows.append(dict(case=case,variants=values));assert all(v['result']==case['expected']for v in values)
report=dict(target=m.digest,scope=__doc__,model=data['model'],sourceHash=data['sourceHash'],rows=rows,counts=dict(clipping=sum(r['case']['kind']=='clip'for r in rows),denied=sum(r['case']['kind']=='denied'for r in rows),deniedVariants=sum(len(r.get('variants',[]))for r in rows)),success=True)
out=m.root/'backups/animations/native-corner-terrain-v1.json';out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(success=True,counts=report['counts'],target=m.digest)))
