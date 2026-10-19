"""Complete original ComputeAwayVector369a40 plus native normalize/magnitude
and finite CRT sine/cosine instructions. TestDirectLine is a captured synthetic
geometry boundary with complete argument/order capture; real tiles/objects,
host CPU dispatch selection, FP status and whole flee actions are separate.
"""
import importlib,itertools,json,struct,random
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);area,origin,threat,path,output=[m.heap+n*0x1000 for n in range(5)]
ranges=[(0x140c70000,0x140c80000),(0x140c90000,0x140c98000)]
for name in ['vector-owner','normalize','magnitude']:
 body=json.loads((m.root/f'backups/animations/rea-move-away-{name}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
def bits(p):return[int.from_bytes(u.mem_read(p+i*4,4),'little')for i in range(3)]
def point(p):return[m.rf(p+i*4)for i in range(3)]
def hook(u,a,n,_):
 global lines
 if a==m.stop:u.emu_stop();return
 if a==0x140371d30:
  rsp=u.reg_read(UC_X86_REG_RSP);line=[m.xmm(UC_X86_REG_XMM1),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.rf(rsp+0x30),m.rf(rsp+0x38),m.si(rsp+0x40)];calls.append(line)
  mode=c.get('line','clear');status=1 if mode=='clear'else 0 if mode=='blocked'else int(lines>=c.get('blocked',0))if mode=='prefix'else 1 if line[2]>=line[0]else -2;lines+=1;m.finish(status)
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected away-vector dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,lines
 c=case;calls=[];lines=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 for p,key in[(origin,'origin'),(threat,'threat')]:
  for i,v in enumerate(c[key]):m.wf(p+i*4,v)
 m.wf(path+4,c.get('radius',.6));m.wf(path+12,c.get('height',.5));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wf(rsp+0x28,c['distance']);m.wq(rsp+0x30,path if c.get('path',True)else 0);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[area,output,origin,threat]):u.reg_write(reg,value)
 try:u.emu_start(0x140369a40,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,point=point(output),bits=bits(output),pathStored=m.q(area+0x280)==path)
cases=[dict(origin=origin,threat=threat,distance=distance,path=path,line=line)for origin,threat,distance,path,line in itertools.product([[0,0,0],[3,2,1],[-2,-1,-0.0]],[[1,0,0],[0,1,0],[0,0,0],[5,-3,9]],[0,.01,1,4,-1],[False,True],['clear','blocked','positiveX'])]
cases += [dict(origin=[1.25,-2,3.5],threat=[4,5,-1],distance=7.25,line='prefix',blocked=blocked)for blocked in [1,3,9,17,71,72]]
rng=random.Random(7301)
for _ in range(60):cases.append(dict(origin=[rng.uniform(-100,100)for _ in range(3)],threat=[rng.uniform(-100,100)for _ in range(3)],distance=rng.uniform(.1,50),line='prefix',blocked=rng.randrange(20)))
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-away-vector-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
