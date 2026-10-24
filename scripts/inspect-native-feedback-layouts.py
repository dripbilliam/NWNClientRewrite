"""Bounded original CC11 receiver777f2f..779a19, including two-level type table.
Scalar readers, message-data setters, strings and final feedback are captured
lower providers. Unique scalar markers identify native slot ownership; this
layout oracle is not a real wire-codec or complete formatter validation.
"""
import importlib.util,json,itertools,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,app,table,baseitem=[m.heap+n*0x1000 for n in range(1,5)]
def si(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def cstr(p):return bytes(u.mem_read(p,256)).split(b'\0')[0].decode('latin1')if p else ''
def put(p,s):
 global stringCount
 b=s.encode('latin1');ptr=m.heap+0x60000+stringCount*0x100;stringCount+=1;assert stringCount<400
 u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1);strings[p]=s
 return p
def read(kind,args,value=None):
 i=len(reads);v=(0x80000000+i if kind=='object'else 10+i)if value is None else value;reads.append(dict(kind=kind,args=args,value=v));return v
def hook(u,a,n,_):
 global allocated
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14077a4cd:u.emu_stop();return
 if a==0x1402da450:m.finish(typeId);return
 if a==0x1402d9ec0:m.finish(read('int',[y]));return
 if a==0x1402d9bc0:m.finish(read('dword',[y]));return
 if a==0x1409737c0:m.finish(read('object',[]));return
 if a==0x1402d9600:m.finish(read('bool',[],(mode>>sum(r['kind']=='bool'for r in reads))&1));return
 if a==0x1402d9630:m.finish(read('byte',[y,z]));return
 if a==0x1402d97d0:put(y,'S'+str(read('string',[z])));m.finish(y);return
 if a==0x1409735f0:put(y,'L'+str(read('localized',[z,w])));m.finish(y);return
 if a==0x1407c4ab0:derived.append(dict(kind='server-build',minimum=[y,z,w]));m.finish(buildOk);return
 if a==0x1402d9460:m.finish(0);return
 if a==0x140c10324:ptr=m.heap+0x30000+allocated*0x100;allocated+=1;m.finish(ptr);return
 if a==0x1403ab1a0:data[x]=dict(integers={},objects={},strings={});m.finish(x);return
 if a in [0x1402da730,0x1402da770,0x1402da8a0]:
  kind={0x1402da730:'integers',0x1402da770:'objects',0x1402da8a0:'strings'}[a];value=strings.get(z,'')if kind=='strings'else si(z)if kind=='integers'else z&0xffffffff;data[x][kind][y]=value;m.finish();return
 if a==0x1406aaf90:outputs.append(dict(type=y&65535,data=data.get(z),color=strings.get(w,'')));m.finish();return
 if a in [0x1406ca3f0,0x1400f4e30]:put(x,'');m.finish(x);return
 if a in [0x14003d4e0,0x1401695e0,0x140c10370]:m.finish();return
 if a==0x140238190:put(x,cstr(y));m.finish(x);return
 if a in [0x1401881e0,0x14019e620]:put(x,strings.get(y,''));m.finish(x);return
 if a==0x14076b6d0:derived.append(dict(kind='base-item',value=y));m.finish(baseitem);return
 if a==0x14029de50:put(y,'BaseItemName');m.finish(y);return
 if not 0x140777f2f<=a<=0x140779a19:raise RuntimeError(f'Unmapped feedback dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for typeId,mode,buildOk in itertools.product(range(0x106),range(4),[0,1]):
 reads=[];outputs=[];data={};strings={};derived=[];allocated=stringCount=0;u.mem_write(m.heap,bytes(0x90000));rsp=m.stack+0x1ce00;rbp=rsp+0x100;u.mem_write(rsp,bytes(0x3000));m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df968,table)
 for reg,val in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RBP,rbp),(UC_X86_REG_R15,message),(UC_X86_REG_R14,0),(UC_X86_REG_RSI,0x140000000)]:u.reg_write(reg,val)
 error=None
 try:u.emu_start(0x140777f2f,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==0x14077a4cd
 except Exception as e:error=str(e)
 rows.append(dict(type=typeId,mode=mode,buildOk=buildOk,reads=reads,outputs=outputs,derived=derived,error=error,rip=hex(u.reg_read(UC_X86_REG_RIP))))
out=m.root/'backups/animations/native-client-feedback-layouts.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');errors={r['error']for r in rows if r['error']};print(json.dumps(dict(cases=len(rows),completed=sum(r['error']is None for r in rows),errors=sorted(errors),output=str(out))))
