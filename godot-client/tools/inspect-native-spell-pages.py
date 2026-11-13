"""Run the complete hash-pinned original spell pool9a2b10, level ring9a2370
and metamagic ring9a24b0 in isolated Unicorn memory. Pool/class/spell lookup,
uses/gain queries, allocation, strings, icons and presentation are captured
boundaries. This proves traversal/slots/continuation/packed selection decisions,
not full original replication, UI drawing, spell gain or server outcomes.
No live process writes or network. Output must be a new workspace report.
"""
import sys,importlib,json,argparse,itertools
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
context,actor,stats,rules,manager,spellbase,seen,classes=[m.heap+n for n in [0x1000,0x3000,0x5000,0x7000,0x9000,0x10000,0x60000,0x70000]]
ranges=[(0x1409a2b10,0x1409a3795),(0x1409a2370,0x1409a24ac),(0x1409a24b0,0x1409a284a)]
def slot(level,cursor):
 rows=c.get('memory',{}).get(str(level),[]);return rows[cursor] if cursor<len(rows) else None
def uses(id,domain,meta):
 level=c['spells'][id].get('Custom',255)
 if domain:level=domain
 level=(level+cost(meta))&255
 if not c.get('prepared',True):return c.get('usesLeft',{}).get(str(level),0)&255
 return sum(bool(row and row['spell']==id and row['ready'] and (not meta or row['metamagic']&meta)) for row in c.get('memory',{}).get(str(level),[])[:len(c.get('memory',{}).get(str(level),[]))&255])&255
def cost(meta):return {1:2,2:1,4:3,8:4,16:1,32:1}.get(meta,0)
def cstr(ptr):
 raw=bytes(u.mem_read(ptr,64));return raw.split(b'\0')[0].decode('ascii')
def hook(u,address,size,data):
 global allocation
 if address==m.stop:u.emu_stop();return
 x,y,z,k=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if address==0x1406ac1a0:m.finish(actor)
 elif address==0x1407f0f60:m.finish(2)
 elif address==0x1407f6750:m.finish(len(c.get('memory',{}).get(str(z&255),[]))&255)
 elif address==0x1407f66e0:m.finish(len(c.get('known',{}).get(str(z&255),[]))&65535)
 elif address==0x1407f5c50:
  known=c.get('known',{}).get(str(z&255),[]);m.finish(known[k&255] if (k&255)<len(known) else 0xffffffff)
 elif address==0x1407f6b20:m.finish(1)
 elif address in [0x1407f5e30,0x1407f5f40,0x1407f5ab0]:
  row=slot(z&255,k&255);key={0x1407f5e30:'spell',0x1407f5f40:'metamagic',0x1407f5ab0:'domain'}[address];m.finish(row.get(key,0) if row else 0xffffffff if key=='spell' else 0)
 elif address==0x1402af4a0:
  id=y&0xffffffff
  if id>=len(c['spells']) or not c['spells'][id]:m.finish(0);return
  ptr=spellbase+id*0x200;m.wi(ptr+0x10,1000+id);m.wi(ptr+0x188,c['spells'][id].get('SpontaneouslyCast',0));u.mem_write(ptr+0x18,b'spell\0');u.mem_write(ptr+0x170,bytes([int('SubRadSpell1' in c['spells'][id])]));u.mem_write(ptr+0x18c,bytes([c['spells'][id].get('MetaMagic',63)]));m.finish(ptr)
 elif address==0x1402af530:m.finish(c['spells'][(x-spellbase)//0x200].get('Custom',255))
 elif address==0x1402a3f70:m.finish(cost(y&255))
 elif address==0x1407f74d0:m.finish(uses(y&0xffffffff,k&255,m.si(sp+0x28)&255))
 elif address==0x1407fabf0:m.finish(int(any(row and row['ready'] and not row['domain'] for row in c.get('memory',{}).get(str(z&255),[]))))
 elif address==0x1409a4910:m.finish(int(y&0xffffffff not in c.get('denied',[])))
 elif address in [0x140c10324,0x140c10368]:
  allocation+=1;ptr=m.heap+0x80000+allocation*0x1000;assert allocation<24;m.finish(ptr)
 elif address==0x1401f7950:m.finish(x)
 elif address==0x140c4f038:m.finish(seen)
 elif address==0x1409aaf70:m.finish(x)
 elif address==0x14016c810:texts[x]=y&0xffffffff;m.finish(x)
 elif address==0x1401e4720:
  counts[x]=texts[y] if y in texts else cstr(m.q(y));m.finish()
 elif address==0x1401fa010:
  packed=m.q(sp+0x38);entries.append(dict(slot=y&0xffffffff,spellId=(k-1000)&0xffffffff,packed=packed,disabled=False,iconPointer=z));m.finish()
 elif address==0x1401faa40:
  entries.append(dict(slot=y&0xffffffff,icon=cstr(z),labelRef=k&0xffffffff,creator=hex(m.q(sp+0x30)),packed=m.q(sp+0x38),disabled=False));m.finish()
 elif address==0x1401f8b30:next(row for row in entries if row['slot']==y)['disabled']=True;m.finish()
 elif address==0x140296910:m.finish(int(y&65535 in c.get('feats',[])))
 elif address in [0x140c10370,0x140c4f024]:m.finish()
 elif address==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,address=0x1409a2b10):
 global c,entries,allocation,texts,counts
 c=case;entries=[];allocation=0;texts={};counts={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes([0xa5])*0x20000)
 m.wq(0x1412df970,manager);m.wq(manager,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules+0x1000);m.wi(rules+0x1000,len(c['spells']));m.wq(rules+0x110,classes)
 m.wq(actor+0x3b0,stats);m.wq(context+0x890,int(c.get('assignment',False)));m.wi(classes+2*0x530+0x4ec,int(c.get('prepared',True)));m.wi(classes+2*0x530+0x4f0,int(c.get('restricted',False)));m.wi(classes+2*0x530+0x520,int(c.get('conversion',False)))
 packed=c.get('cursor',0)|(2<<16)|(c.get('level',1)<<24)|(c.get('index',0)&3)<<28|(c.get('index',0)&4)<<36|c.get('meta',0)<<31
 if address==0x1409a24b0:packed=c.get('index',0)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,context);u.reg_write(UC_X86_REG_RDX,packed)
 u.emu_start(address,m.stop,count=300000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 for row in entries:
  if 'iconPointer' in row:row['uses']=counts.get(row.pop('iconPointer'))
 return dict(case=c,entries=entries)
spells=[dict(Name=1000+i,IconResRef='spell',Custom=1,TargetType=127,MetaMagic=63,Master=i) for i in range(40)]
rows=[]
for count,meta,assignment in itertools.product([0,1,7,8,14,20],[0,1,2],[False,True]):
 memory={'1':[dict(spell=i//2,metamagic=0 if i%3 else 2,ready=int(i%4!=0),domain=0) for i in range(count)],'7':[dict(spell=i+20,metamagic=0,ready=1,domain=0) for i in range(5)],'8':[dict(spell=i+25,metamagic=0,ready=1,domain=0) for i in range(5)],'9':[dict(spell=i+30,metamagic=0,ready=1,domain=0) for i in range(5)]}
 for level,cursor in [(1,0),(1,3),(7,0),(8,2),(9,0)]:rows.append(run(dict(spells=spells,memory=memory,meta=meta,assignment=assignment,level=level,cursor=cursor,index=4,denied=[1,24,33])))
# Metamagic / domain context and conversion flags are not inferred from names.
for convert,ready in itertools.product([False,True],[0,1]):
 altered=[dict(s) for s in spells];altered[0]['SpontaneouslyCast']=1
 rows.append(run(dict(spells=altered,memory={'1':[dict(spell=0,metamagic=0,domain=0,ready=0),dict(spell=1,metamagic=0,domain=0,ready=ready)]},conversion=convert)))
for restricted,meta,level,cursor,assignment in itertools.product([False,True],[0,2],[1,7],[0,2],[False,True]):
 altered=[dict(s,Custom=id%10) for id,s in enumerate(spells)]
 known={str(level):[id for id in range(len(altered)) if id%10==level] for level in range(10)}
 rows.append(run(dict(spells=altered,prepared=False,restricted=restricted,known=known,usesLeft={str(level):level%3 for level in range(10)},meta=meta,level=level,cursor=cursor,assignment=assignment)))
levels=run(dict(spells=spells,index=6,meta=32),0x1409a2370)
metas=[]
for feats in [[],[11],[12,25],[29,33,37],[11,12,25,29,33,37]]:metas.append(run(dict(spells=spells,index=4,feats=feats),0x1409a24b0))
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',required=True);args=parser.parse_args();output=(root/args.report).resolve();assert output.is_relative_to(root/'godot-client/reports') and not output.exists()
with output.open('x',encoding='utf-8') as stream:stream.write(json.dumps(dict(binarySha256=m.digest,scope=__doc__,cases=rows,levels=levels,metamagic=metas),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),rings=1+len(metas),output=str(output))))
