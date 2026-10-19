"""Original whole situation/stack load bodies. Captured GFF/heap/string,
DataBlock/shared-pointer, jump-map storage and engine-load boundaries.
"""
import importlib,sys,json,struct,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
vm,out,gff,root,impl,vtable=[m.heap+n*0x1000 for n in range(1,7)];fake=m.stop+0x100;previous=m.heap+0xf000
def alloc(n):
 global cursor
 assert 0<=n<0xa0000;p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;return p
def exo(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def string(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('ascii')
def std(p,s):
 b=s.encode('ascii');m.wq(p+16,len(b));m.wq(p+24,15 if len(b)<=15 else len(b))
 if len(b)<=15:u.mem_write(p,b+b'\0')
 else:a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a)
def stdtext(p):return bytes(u.mem_read(m.q(p)if m.q(p+24)>15 else p,m.q(p+16))).decode('ascii')
def typed(p,name,t,d):
 f=records[m.si(p)]['fields'].get(name);return(f['value'],1)if f and f['type']==t else(d,0)
readers={0x1401a1250:1,0x1401a1510:4,0x1401a1650:8,0x1401a1770:5}
def hook(u,a,n,_):
 global snapshotPtr
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in readers:
  t=readers[a];d=m.q(rsp+0x28);d=struct.unpack('<f',struct.pack('<I',d&0xffffffff))[0]if t==8 else d;v,status=typed(y,string(z),t,d);m.wi(w,status)
  if t==8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish();return
  m.finish(v&255 if t==1 else v);return
 if a==0x1401a1130:
  v,status=typed(z,string(w),10,text(m.q(rsp+0x30)));m.wi(m.q(rsp+0x28),status);exo(y,''if v.startswith('\0')else v);m.finish(y);return
 if a==0x1401a1870:
  v,status=typed(y,string(m.q(rsp+0x28)),13,[]);m.wi(m.q(rsp+0x30),status)
  if status:u.mem_write(z,bytes(v[:w&0xffffffff]));m.finish(z)
  else:m.finish(m.q(rsp+0x38))
  return
 if a==0x1401a02c0:
  v,status=typed(z,string(w),15,[])
  if status:lists.append(v);m.wi(y,len(lists)-1)
  m.finish(status);return
 if a==0x1401a0370:m.finish(len(lists[m.si(y)]));return
 if a==0x1401a03f0:
  rows=lists[m.si(z)];status=int(w<len(rows))
  if status:records.append(rows[w]);m.wi(y,len(records)-1)
  m.finish(status);return
 if a==0x1401a04e0:
  v,status=typed(z,string(w),14,None)
  if status:records.append(v);m.wi(y,len(records)-1)
  m.finish(status);return
 if a in [0x140c10324,0x140c10368]:m.finish(alloc(x));return
 if a==0x14027db60:u.mem_write(x,bytes(0xa0));snapshotPtr=x;m.finish(x);return
 if a==0x140108a10:control=alloc(32);m.wq(x,control);m.finish(x);return
 if a==0x140308e00:
  ptr=alloc(y);m.wq(m.q(x),ptr);m.wq(m.q(x)+16,y);m.finish();return
 if a==0x1403092e0:m.wq(m.q(x)+8,y);m.finish();return
 if a==0x140174060:
  m.wq(x,m.q(y));ref=m.q(y+8);m.wq(x+8,ref)
  if ref:m.wi(ref+8,m.si(ref+8)+1)
  m.finish(x);return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x1401881e0:exo(x,text(y));m.finish(x);return
 if a==0x14003dc20:std(x,bytes(u.mem_read(y,z)).decode('ascii'));m.finish(x);return
 if a==0x140279340:
  label=stdtext(z);calls.append(['jump',label])
  if label not in jumps:p=alloc(0x48);std(p+16,label);jumps[label]=p
  m.wq(y,jumps[label]);m.finish(y);return
 if a==fake:
  kind=(y&0xffffffff)-0x100000000 if y&0x80000000 else y;row=records[m.si(m.q(rsp+0x28))];marker=row['fields'].get('EngineMarker',dict(value=0))['value'];calls.append(['engine',kind,marker]);p=alloc(8);tokens[p]=dict(kind=kind,marker=marker);m.wq(z,p);m.finish(1);return
 if a==0x140115890:line=m.si(rsp+0x28);failures.append(line);calls.append(['failure',line]);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a in [0x140c10360,0x140c10370]:m.finish();return
 if not(0x140282ab0<=a<=0x140283229 or 0x140283230<=a<=0x1402835fa):raise RuntimeError(f'Uncaptured VM-load dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def blob(p):
 if not m.q(p):return None
 block=m.q(m.q(p));return list(u.mem_read(m.q(block),m.q(block+8)))
def cell(p):
 t=u.mem_read(p+16,1)[0];v=text(p)if t==5 else m.rf(p)if t==4 else m.si(p)&0xffffffff if t==6 else m.si(p)if t==3 else tokens.get(m.q(p),0);return dict(type=t,value=v)
def snapshot():
 p=m.q(out)
 if p==previous:return'previous'
 q=m.q(p);sp=m.si(q);cap=m.si(q+8);s=dict(basePointer=m.si(q+4),stackPointer=sp,totalSize=cap,cells=[cell(m.q(q+16)+i*24)for i in range(max(0,sp))]if cap>0 and not any(n in failures for n in [0x165,0x166,0x167])else[])
 if failures:s['loadFailureLine']=failures[-1]
 js=[]
 for key,j in jumps.items():js.append(dict(label=key,vmInstPtr=m.si(j+0x38),instPtr=m.si(j+0x3c),stackPtr=m.si(j+0x40),instPtrLevel=m.si(j+0x44),fromJmp=u.mem_read(j+0x30,1)[0],retVal=m.si(j+0x34)))
 return dict(code=blob(p+0x28),ndb=blob(p+0x38),instructionPtr=m.si(p+12),secondaryPtr=m.si(p+16),name=text(p+0x18),stackSize=m.si(p+8),stack=s,jumps=js,scriptChunk=text(p+0x90),scriptEventId=m.si(p+0x48))
def run(case):
 global cursor,records,lists,calls,tokens,jumps,failures,snapshotPtr
 cursor=0x10000;records=[case['data']];lists=[];calls=[];tokens={};jumps={};failures=[];snapshotPtr=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(root,0);m.wq(out,previous);m.wq(vm+0x858,impl);m.wq(impl,vtable);m.wq(vtable+0x58,fake);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[vm,out,gff,root]):u.reg_write(reg,v)
 try:u.emu_start(0x140282ab0,m.stop,count=300000)
 except Exception:print(json.dumps(dict(name=case['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-3:])));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,status=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=snapshot(),calls=calls)
def f(t,v):return dict(type=t,value=v)
def node(fields):return dict(type=2,fields=fields)
saved=json.loads((m.root/'backups/animations/native-script-situation-save-observations.json').read_text());cases=[dict(name='missing-code',data=node({})),dict(name='mistyped-code-size',data=node(dict(CodeSize=f(4,10))))]
for row in saved['cases']:cases.append(dict(name=row['case']['name'],data=copy.deepcopy(row['output'])))
for line,field,value in [(0x165,'BasePointer',-1),(0x166,'StackPointer',-1),(0x167,'TotalSize',-1)]:
 data=node(dict(CodeSize=f(5,2),Code=f(13,[0x20,0]),Stack=f(14,node({field:f(5,value)}))));cases.append(dict(name='stack-failure-'+hex(line),data=data))
data=node(dict(CodeSize=f(5,2),Code=f(13,[0x20,0]),Stack=f(14,node(dict(BasePointer=f(5,0),StackPointer=f(5,2),TotalSize=f(5,18))))));cases.append(dict(name='missing-stack-list',data=copy.deepcopy(data)));data['fields']['Stack']['value']['fields']['Stack']=f(15,[node(dict(Type=f(1,3),Value=f(5,17)))]);cases.append(dict(name='short-stack-list',data=data))
path=m.root/'backups/animations/native-script-situation-load-observations.json';path.write_text(json.dumps(dict(target=m.digest,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(path))))
