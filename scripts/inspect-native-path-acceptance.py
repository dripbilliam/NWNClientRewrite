"""Original8001f0 acknowledgement admission plus real800da0 endpoint getter.

Synthetic clear/blocked query answers isolate ordered repair policy. Allocation,
80b0d0 installation, height projection and render notifications are captured
boundaries. No native world collision, live process changes or copied assets.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');m=p.m;w=p.w;u=p.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
obj,vt,area,points,source=[m.heap+n*0x1000 for n in range(80,85)]
d=json.loads((m.root/'backups/animations/rea-ack-path-function-v1.json').read_text())['structuredContent']['raw_result']['value']
ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]+[(0x140800da0,0x140800dc9)]
def put(a,v):u.mem_write(a,struct.pack('<3f',*v))
def vec(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407e6a20:
  answer=c['answers'][len(queries)] if len(queries)<len(c['answers']) else 0
  queries.append(dict(start=vec(z),end=vec(k),radius=m.rf(sp+0x28),height=m.rf(sp+0x30),creatures=m.si(sp+0x38),result=answer));m.finish(answer);return
 if a==0x14080b0d0:
  installed.append([vec(z+i*12)for i in range(y&65535)]);m.finish();return
 if a==0x1407ff030:
  # Captured flat projection: original fallback requests this only after all
  # connectivity repairs fail. Keep it distinct from the authoritative snap.
  value=vec(z);value[2]=c['height'];projected.append(value);put(m.q(sp+0x28),value);m.finish();return
 if a==m.stop+0x128:rendered.append(vec(y));put(obj+0x38,vec(y));m.finish();return
 if a==m.stop+0x208:notifications.append(vec(y));m.finish();return
 if a==0x140c10370:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,queries,installed,projected,rendered,notifications
 c=case;queries=[];installed=[];projected=[];rendered=[];notifications=[];p.t.reset(dict(format=1))
 m.wq(obj,vt);m.wq(obj+0x30,area if c['area']else 0);m.wq(vt+0x230,0x140800da0);m.wq(vt+0x128,m.stop+0x128);m.wq(vt+0x208,m.stop+0x208)
 m.wi(obj+0x2f8,c['script']);u.mem_write(obj+0x2d3,bytes([c['lastSequence']]));m.wi(obj+0x2d8,0);m.wi(obj+0x2cc,c['correction'])
 put(obj+0x2c0,c['position']);put(obj+0x38,c['render']);m.wq(obj+0x298,points);m.wq(obj+0x2a0,points+c['cursor']*12);u.mem_write(obj+0x2d0,struct.pack('<H',len(c['priorPath'])))
 for i,v in enumerate(c['priorPath']):put(points+i*12,v)
 for i,v in enumerate(c['path']):put(source+i*12,v)
 put(source+0x500,c['serverPosition']);m.wq(m.stack+0x1fe08+0x28,source+0x500);w.call(0x1408001f0,[obj,len(c['path']),source,c['sequence']])
 return dict(case=c,queries=queries,installed=installed,projected=projected,rendered=rendered,notifications=notifications,position=vec(obj+0x2c0),render=vec(obj+0x38),newPath=m.si(obj+0x2d8),correction=m.si(obj+0x2cc))
if __name__=='__main__':
 base=dict(position=[10.,20.,1.],render=[9.7,20.2,1.],serverPosition=[10.1,19.9,1.],path=[[10.2,20.,0.],[11.,20.,0.],[12.,20.,0.]],priorPath=[[10.,20.,1.],[10.5,20.2,1.],[11.5,20.2,1.]],cursor=1,script=1,lastSequence=23,sequence=23,correction=512,height=.25,area=True)
 cases=[]
 for answers,cursor,render in itertools.product([[1],[0,1],[0,0,1],[0,0,0,1],[0,0,0,0,1],[0,0,0,0,0]], [0,1,2],[[10.,20.,1.],[9.7,20.2,1.],[10.8,19.5,1.]]):cases.append(base|dict(answers=answers,cursor=cursor,render=render))
 for sequence,script,prior in itertools.product([0,22,23,24],[0,1],[[],base['priorPath']]):cases.append(base|dict(sequence=sequence,script=script,priorPath=prior,cursor=0,answers=[0,0,0,0,1]))
 cases.extend([base|dict(answers=[1],path=[]),base|dict(answers=[1],area=False),base|dict(answers=[0,0,0,0,0],priorPath=[],cursor=0)])
 rows=[run(case)for case in cases];out=m.root/'backups/animations/native-path-acceptance-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),queries=sum(len(r['queries'])for r in rows),resets=sum(bool(r['rendered'])for r in rows),output=str(out))))
