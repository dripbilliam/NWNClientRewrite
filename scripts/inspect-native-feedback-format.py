"""Complete original feedback formatter6cb2e0 through its native jump table.
Strings, TLK/parse/custom-token, replicated name/object lookups, allocation and
final display/audio/GUI calls are captured lower providers. Unknown lower
owners fail a case explicitly. Marker TLK text tests selection, not localization.
"""
import importlib.util,json,itertools,re,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
owner,data,app,table,gui,actor,color=[m.heap+n*0x1000 for n in range(1,8)]
def si(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def cstr(p):return bytes(u.mem_read(p,4096)).split(b'\0')[0].decode('latin1')if p else ''
def put(p,s):
 global cursor
 b=s.encode('latin1');ptr=m.heap+cursor;cursor+=(len(b)+32)&~15;assert cursor<0xff000;u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1);strings[p]=s;return p
def text(p):return strings.get(p,cstr(m.q(p))if p and m.q(p)else '')
def hook(u,a,n,_):
 global cursor
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop:u.emu_stop();return
 if a==0x1402d5740:v=ints[y]if y<len(ints)else 0;calls.append(['integer',y,v]);m.finish(v);return
 if a==0x1402d57f0:calls.append(['object',y]);m.finish(0x80000063+y);return
 if a==0x1402d5810:put(y,'String'+str(z));calls.append(['string',z]);m.finish(y);return
 if a==0x1406ab9e0:m.finish(actor if world else 0);return
 if a==0x1406d83f0:put(z,'Name'+str(y&0xffffffff)if names else '');calls.append(['name',y&0xffffffff]);m.finish(names);return
 if a==0x140198c60:put(z,('P'+str(y&0xffffffff)+json.dumps(tokens,sort_keys=True))if w else 'T'+str(y&0xffffffff));calls.append(['parse',y&0xffffffff,dict(context='none'if m.q(table+0xb0)==0 else'unknown',nativeB8=m.si(table+0xb8),nativeBC=m.si(table+0xbc))]if w else['tlk',y&0xffffffff]);m.finish(1);return
 if a==0x1401994d0:put(y,'T'+str(z&0xffffffff));calls.append(['simple-tlk',z&0xffffffff]);m.finish(y);return
 if a==0x1406d7700:put(z,'P'+str(y&0xffffffff)+json.dumps(tokens,sort_keys=True));calls.append(['parse',y&0xffffffff,dict(context='none'if w==0 else'unknown',nativeB8=m.si(sp+0x28),nativeBC=m.si(sp+0x30))]);m.finish();return
 if a==0x14019a5d0:v=text(z);tokens[y&0xffffffff]=v;calls.append(['token',y&0xffffffff,v]);m.finish();return
 if a==0x14016c810:put(x,str(si(y)));calls.append(['number',si(y)]);m.finish(x);return
 if a==0x14015d5e0:
  v=text(x).encode('latin1');p=m.heap+cursor;cursor+=(len(v)+32)&~15;u.mem_write(p,v+b'\0');m.finish(p);return
 if a==0x140238190:put(x,cstr(y));m.finish(x);return
 if a in [0x1406ca3f0,0x1400f4e30]:put(x,'');m.finish(x);return
 if a==0x14003d8c0:put(x,cstr(y)if y else '');m.finish(x);return
 if a==0x140704cc0:m.finish(0);return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x140766a70:calls.append(['floaty',text(y)]);m.finish();return
 if a in [0x1401881e0,0x14019e620,0x140260650]:put(x,text(y));m.finish(x);return
 if a==0x14016ab00:put(y,text(x)+text(z));m.finish(y);return
 if a==0x14016afb0:
  fmt=cstr(y);values=[z,w]+[m.q(sp+0x28+i*8)for i in range(6)];idx=0
  def sub(match):
   nonlocal idx
   code=match.group(0)
   if code=='%%':return '%'
   value=values[idx];idx+=1
   if code=='%s':return cstr(value)
   if code in ['%i','%d']:return str(si(value))
   if code=='%u':return str(value&0xffffffff)
   raise RuntimeError('Unsupported format '+fmt)
  put(x,re.sub(r'%%|%[siud]',sub,fmt));calls.append(['format',fmt]);m.finish(x);return
 if a==0x14003d880:put(x,'');m.finish(x);return
 if a in [0x14003d4e0,0x1401695e0,0x140c10370,0x14037bd50]:m.finish();return
 if a in [0x140c113c0,0x140c10410]:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a in [0x140c10324,0x140c10368]:p=m.heap+cursor;cursor+=(x+31)&~15;u.mem_write(p,bytes(x));m.finish(p);return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a==0x1406f68d0:outputs.append(dict(raw=text(y),flags=z));m.finish();return
 if a==0x1401f6110:calls.append(['sound',cstr(x)]);m.finish();return
 if a==0x1401e5d20:calls.append(['encourage',y]);m.finish();return
 if not 0x1406cb2e0<=a<0x1406d5028:raise RuntimeError(f'Unmapped formatter dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
profiles=[[-12,37,3,4,5,6,7,8,9,10],[0]*10,[83,-15,7,8,9,10,11,12,13,14],[-2147483648,2147483647,1,2,3,4,5,6,7,8],[2147483647,-2147483648,8,7,6,5,4,3,2,1]]
for typeId,names,world,profile in itertools.product(range(0x106),[0,1],[0,1],range(len(profiles))):
 ints=profiles[profile];calls=[];outputs=[];strings={};tokens={1:'old1',2:'old2'};cursor=0x30000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,owner);m.wq(0x1412df968,table);m.wq(0x1412df960,table);m.wq(0x1412df8f0,table);m.wq(owner,app);m.wq(owner+0x90,gui);m.wi(owner+0x48,0x80000063);m.wi(app+0x28,1);m.wi(actor+8,0x80000063);put(color,'<c\xff\xff\x01>')
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
 for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[owner,typeId,data,color]):u.reg_write(reg,val)
 error=None
 try:u.emu_start(0x1406cb2e0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 except Exception as e:error=str(e)
 rows.append(dict(type=typeId,names=names,world=world,profile=profile,calls=calls,outputs=outputs,tokens=tokens,error=error,rip=hex(u.reg_read(UC_X86_REG_RIP))))
out=m.root/'backups/animations/native-client-feedback-format-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),completed=sum(r['error']is None for r in rows),errors=sorted({r['error']for r in rows if r['error']}),output=str(out))))
