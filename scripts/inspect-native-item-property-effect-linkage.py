"""Complete original property apply/remove dispatch wrappers. Selected concrete
materializer is a captured callback mutating the live effect-pointer array;
original snapshot membership, warning gates, property-ID annotation, matching
removal snapshot and optional custom-removal dispatch execute unchanged.
No every-materializer or gameplay-completion claim; no live process changes.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
handler,item,prop,owner,pool,table,records=[m.heap+i*0x1000 for i in range(7)]
def setIds(ids):
 global current
 current=list(ids);m.wi(owner+0x158,len(current))
 for i,index in enumerate(current):m.wq(pool+i*8,records+index*0x200)
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c4f038:
  ptr=m.heap+cursor;cursor+=(y+15)&~15
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,allocations[x]))))
  allocations[ptr]=y;m.finish(ptr)
 elif a==0x140c4f024:m.finish()
 elif a==m.stop+0x300:trace.append(['apply',m.si(rsp+0x28),m.si(rsp+0x30)]);setIds(c['after']);m.finish(7)
 elif a==m.stop+0x310:trace.append(['customRemove',m.si(rsp+0x28)]);m.finish(7)
 elif a==0x140497ec0:
  index=(y-records)//0x200;trace.append(['remove',index]);ids=list(current)
  if index in ids:ids.remove(index)
  setIds(ids);m.finish()
 elif a==0x140115890:line=m.si(rsp+0x28);trace.append(['warning',{0x19f:'duration',0x1a1:'creator'}[line]]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x140473790,0x140473acf),(0x140473ad0,0x140473c2f)]):raise RuntimeError(f'Unmapped property linkage dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,cursor,allocations
 c=case;trace=[];cursor=0x30000;allocations={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(handler+8,table);m.wq(handler+16,table+0x400);m.wq(owner+0x150,pool);m.wi(item+0x50,123);m.wq(prop+0x28,int(c['propertyId'],16));u.mem_write(prop,struct.pack('<H',c['type']&65535))
 if c['type']&65535<88 and c['enabled']:m.wq(table+(c['type']&65535)*8,m.stop+0x300);m.wq(table+0x400+(c['type']&65535)*8,m.stop+0x310)
 for i,e in enumerate(c['effects']):ptr=records+i*0x200;u.mem_write(ptr+0xa,struct.pack('<H',e['durationType']&65535));m.wi(ptr+0x18,e['creatorId']);m.wq(ptr+0xf0,int(e['propertyId'],16))
 setIds(c['before']);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,16);m.wi(rsp+0x30,0);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[handler,item,0 if c.get('null') else prop,owner]):u.reg_write(reg,value)
 u.emu_start(0x140473790 if c['kind']=='apply' else 0x140473ad0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,trace=trace,after=current,propertyIds=[f'{m.q(records+i*0x200+0xf0):016x}' for i in range(len(c['effects']))])
rows=[]
for n,type_,enabled,kind in itertools.product([0,1,16,17,32],[6,13,61,88,65536],[False,True],['apply','remove']):
 effects=[dict(durationType=3,creatorId=123,propertyId=f'{i%3:016x}') for i in range(n)]+[dict(durationType=duration,creatorId=creator,propertyId='0000000000000000') for duration,creator in [(3,123),(4,123),(2,123),(3,999),(11,123)]]
 rows.append(run(dict(kind=kind,type=type_,enabled=enabled,effects=effects,before=list(range(n)),after=[n,*range(n),n+1,n+2,n+3,n+4],propertyId='0000000000000001')))
for kind in ['apply','remove']:rows.append(run(dict(kind=kind,type=6,enabled=True,null=True,effects=[],before=[],after=[],propertyId='0000000000000000')))
out=m.root/'backups/animations/native-item-property-effect-linkage-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
