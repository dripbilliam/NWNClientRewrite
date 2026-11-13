"""Execute original live Skills SetData9bfda0 and complete Skills OK9c8d10.
Class usability, cached eligibility/value getters and rank writes7fa8b0 execute
unchanged. Raw stat/table fixtures, object lookup, GUI/TLK/string formatting,
allocation and the subsequent feat/spell child chain are explicit boundaries.
This proves the skill-cache/data policy, not complete creation or original pixels.
"""
import copy,importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('skills',Path(__file__).with_name('inspect-native-pregame-skills.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
m=s.m;u=m.u;u.hook_del(s.hook_handle)
page,creature,string,vtable=[m.heap+n for n in[0x80000,0x84000,0x86000,0x87000]]
text_stub,destructor_stub=m.stop+0x100,m.stop+0x110
extra=[(0x1409bfda0,0x1409bffa3),(0x1409c8d10,0x1409c90c3),(0x1407f0f60,0x1407f0fc6),(0x1407f6630,0x1407f664b),(0x1407f5d70,0x1407f5e11),(0x1407fa8b0,0x1407faa0c)]
def hook(u,a,n,_):
 global last_number
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140800c90:m.finish(creature)
 elif a in[0x140c10370,0x1401edf80,0x1401fb540,text_stub,destructor_stub]:m.finish()
 elif a==0x1407ec290:u.mem_write(y,b'\0');u.mem_write(z,b'\0');m.finish()
 elif a==0x1409c69a0:closed_codes.append(u.reg_read(UC_X86_REG_R9)&0xffffffff);m.finish()
 elif a==0x14016c810:
  last_number=struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0];m.wq(x,string+0x200);m.wi(x+8,0);m.finish(x)
 elif a==0x1402ae9f0:m.finish(string+0x100)
 elif a==0x14003d8c0:m.wq(x,string+0x200);m.wi(x+8,0);m.finish(x)
 elif a==0x14018dea0:u.mem_write(x,bytes(17));m.finish(x)
 elif a==0x1409bfa50:captured.append(dict(id=y&65535,value=last_number,lostAbilities=bool(m.si(u.reg_read(UC_X86_REG_RSP)+0x30))));m.finish()
 elif any(lo<=a<hi for lo,hi in extra):return
 else:s.hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,hook)
def rows():
 global captured,last_number
 captured=[];last_number=0;s.call(0x1409bfda0,[page,42]);return list(captured)
def commit():
 global closed_codes
 closed_codes=[];s.call(0x1409c8d10,[page]);assert closed_codes==[0x8010]
 return m.si(s.actor+0xe0)&0xffffffff
def run(c,index):
 c=copy.deepcopy(c)
 for cls in c['source']['classes']:
  if cls['id']>=len(c['tables']['classes']['orderedRows']):cls['id']=0
 c['source']['lostAbilities']=bool(index%2)
 s.run(c);m.wq(creature+0x3b0,s.actor);m.wi(page+0xf80,42);m.wq(page,vtable);m.wq(vtable,destructor_stub)
 m.wq(page+0x188,string);m.wq(string,vtable+0x200);m.wq(vtable+0x2d0,text_stub)
 for at,cls in enumerate(c['source']['classes']):u.mem_write(s.actor+at*0x150+0x297,bytes([int(c['source']['lostAbilities'])if at==0 else 0]))
 m.wi(s.actor+0xe0,0);before=rows();mask=commit();after=rows();update=None
 count=len(c['tables']['skills']['orderedRows'])&255
 if count:
  id=(index*7)%count;rank=[0,1,127,128,255][index%5]
  s.call(0x1407fa8b0,[s.actor,id,rank]);unchanged=m.si(s.actor+0xe0)&0xffffffff
  update=dict(id=id,rank=rank,maskBeforeCommit=unchanged,entriesBeforeCommit=rows(),mask=commit(),entries=rows())
 return dict(case=c,initial=before,mask=mask,entries=after,update=update)
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-skill-summary-observations-v2.json';assert not out.exists(),'Preserve prior evidence'
 prior=json.loads((m.root/'backups/animations/native-pregame-skill-observations-v1.json').read_text());assert prior['target']==m.digest
 result=[run(row['case'],index)for index,row in enumerate(prior['rows'])]
 out.write_text(json.dumps(dict(target=m.digest,procedures=['0x1409bfda0','0x1409c8d10','0x1407fa8b0'],scope=__doc__,rows=result),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(result))))
