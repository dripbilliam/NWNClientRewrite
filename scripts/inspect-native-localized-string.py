"""Original CExoLocString::GetString coordinator with captured embedded-list
lookup and independently verified TLK fetch. Compare output retention, order,
gender state and fallback, not full TLK I/O or embedded-list allocation.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
loc,out,internal,tlk=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x4000
d=json.loads((m.root/'backups/animations/rea-stats-save-localized-name.json').read_text())['structuredContent']['normalized_result']
ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
def exostring(p,s):
 global cursor
 b=s.encode('ascii');ptr=m.heap+0x10000+cursor;cursor+=len(b)+16;u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14016a3b0:
  key=y&0xffffffff;calls.append(['internal',key]);entry=c['entries'].get(str(key))
  if entry is not None:exostring(z,''if entry.startswith('\0')else entry)
  m.finish(0 if entry is None else 1);return
 if a==0x140198c60:
  calls.append(['fetch',y&0xffffffff,w&0xffffffff,u.mem_read(tlk+0x28,1)[0]]);exostring(z,c['fetchText']);m.finish(c['fetchStatus']);return
 if a==0x14003d8c0:
  b=bytes(u.mem_read(y,z&0xffffffff)).decode('ascii')if y else'';exostring(x,''if b.startswith('\0')else b);m.finish(x);return
 if a==0x140c10370:m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured localized-string dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor
 c=case;calls=[];cursor=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(loc,internal);m.wi(loc+8,42);m.wq(0x1412df968,tlk if c['table']else 0);u.mem_write(tlk+0x28,bytes([c['initialGender']]));exostring(out,'previous')
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,c['translate']);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[loc,c['language']&0xffffffff,out,c['gender']]):u.reg_write(r,v)
 try:u.emu_start(0x140169920,m.stop,count=20000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,status=u.reg_read(UC_X86_REG_RAX)&0xffffffff,text=text(out),gender=u.mem_read(tlk+0x28,1)[0],calls=calls)
cases=[]
for language,gender,translate,table in itertools.product([0,1,2,5,-1],[0,1,2,255],[0,1],[0,1]):
 for entries,status,textValue in [({},0,'ignored'),({},1,'TLK'),({},1,''),({'0':'English'},0,''),({'2':'French','3':'Female'},1,''),({'8':'Language Four'},1,''),({'9':'Female Four'},1,''),({'0':''},1,'TLK'),({'2':'\0hidden'},1,'TLK'),({'10':'A\0B'},1,'TLK')]:
  cases.append(dict(language=language,gender=gender,translate=translate,table=table,initialGender=1,entries=entries,fetchStatus=status,fetchText=textValue))
observations=[run(c)for c in cases]
output=m.root/'backups/animations/native-localized-string-observations.json';output.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n')
print(json.dumps(dict(cases=len(cases),output=str(output))))
