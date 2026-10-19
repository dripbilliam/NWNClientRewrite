"""Complete original CResGFF ReadFieldINT1a1770/SHORT1a17f0 executions.
Field-label lookup and field-location resolution are captured boundaries; the
original reader performs type checking, default selection and value narrowing.
This is not a full ReadStatsFromGff/ELC oracle. No live memory/binary writes.
"""
from pathlib import Path
import importlib,sys,json,itertools
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
gff,node,label,found,field=[m.heap+n*0x1000 for n in range(1,6)]
ranges=[]
for name in ['int','short']:
 d=json.loads((m.root/f'backups/animations/rea-network-character-gff-read-{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def hook(u,a,size,_):
 if a==m.stop:u.emu_stop();return
 if a==0x14019fcc0:m.finish(0);return
 if a==0x14019fc20:m.finish(0 if case.get('missing')else field);return
 if any(lo<=a<hi for lo,hi in ranges):return
 raise RuntimeError(f'Uncaptured typed GFF read dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case
 case=c;sp=m.stack+0x1fe08;u.mem_write(sp-0x100,bytes(0x200));m.wq(sp,m.stop);m.wi(sp+0x28,c['default']);m.wi(field,c['type']);m.wi(field+8,c['value']);m.wi(found,0xa5a5a5a5)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[gff,0 if c.get('noStruct')else node,0 if c.get('noLabel')else label,found]):u.reg_write(r,v)
 u.reg_write(UC_X86_REG_RSP,sp);u.emu_start(0x1401a1770 if c['reader']=='INT'else 0x1401a17f0,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 bits=32 if c['reader']=='INT'else 16;value=u.reg_read(UC_X86_REG_RAX)&((1<<bits)-1);value=value-(1<<bits)if value&(1<<(bits-1))else value
 return dict(case=c,value=value,found=m.si(found))
cases=[dict(reader=r,type=t,value=v,default=d)for r,t,v,d in itertools.product(['INT','SHORT'],range(19),[0,1,10,255,65535,0xffffffff],[0,255,-1])]
for r,extra in itertools.product(['INT','SHORT'],['missing','noStruct','noLabel']):cases.append(dict(reader=r,type=5 if r=='INT'else 3,value=10,default=-1,**{extra:True}))
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-character-field-type-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
