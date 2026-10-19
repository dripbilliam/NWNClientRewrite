"""Complete recursive FindItemWithTag and GetAppropriateListId original bodies.
Capture the independently verified AsTAG string conversion, linked-list node
access/advance, object-array lookup/item cast, string release and base-row/log
boundaries. Original recursion, length/strcmp gates, physical search order,
canonical result and panel clamping execute unchanged.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
repo,childRepo,list1,list2,node1,node2,node3,item1,item2,item3,vt,app,query,info,store=[m.heap+i*0x1000 for i in range(15)]
items={1:item1,2:item2,3:item3};ranges=[(0x1404680a0,0x1404681ce),(0x1404fb590,0x1404fb5fe)]

def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8)))if m.q(p)else b''
def string(p,value,storage):
 b=value.encode('cp1252');u.mem_write(storage,b+b'\0');m.wq(p,storage if b else 0);m.wi(p+8,len(b))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14016ac40:
  value=text(x);normalized=bytes(b for b in value if b==95 or 48<=b<=57 or 65<=b<=90 or 97<=b<=122)[:63];string(y,normalized.decode(),m.heap+0x90000);m.finish(y)
 elif a==0x14055b850:m.finish(app)
 elif a==0x1401690b0:m.finish(y+16)
 elif a==0x140296470:
  id=y&0xffffffff;trace.append(id);m.wq(z,items[id]if id!=c.get('missing')else 0);m.finish(1 if id==c.get('badStatus')else 0)
 elif a==m.stop+0x20:m.finish(x)
 elif a==0x140169110:m.wq(y,m.q(m.q(y)));m.finish()
 elif a==0x140c10370:m.finish()
 elif a==0x14029ca00:m.finish(info)
 elif a==0x140115890:trace.append('warning');m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped repository tag dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0xa0000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,app)
 for p,id,tag in[(item1,1,c.get('first','Bag')),(item2,2,c.get('child','Target')),(item3,3,c.get('last','Target'))]:
  m.wq(p,vt);m.wi(p+0x50,id);string(p+0x68,tag,p+0x500)
 m.wq(vt+0x70,m.stop+0x20);m.wq(repo+16,list1);m.wq(childRepo+16,list2);m.wq(list1,node1);m.wq(list2,node2);m.wq(node1,node3);m.wi(node1+16,1);m.wi(node2+16,2);m.wi(node3+16,3)
 if c.get('nested',True):m.wq(item1+0x3d0,childRepo)
 if c.get('empty',False):m.wq(list1,0)
 string(query,c.get('query','Target'),query+0x500);u.mem_write(info+0x33,bytes([c.get('panel',0)&255]));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 entry=0x1404fb590 if c.get('mode')=='panel'else 0x1404680a0
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX],[store if c.get('mode')=='panel'else repo,49 if c.get('mode')=='panel'else query]):u.reg_write(r,v)
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&(255 if c.get('mode')=='panel'else 0xffffffff),trace=trace)
cases=[dict(query=q,first=f,child=ch,last=l,nested=n)for q,f,ch,l,n in itertools.product(['Target','Target!','target','Bag','', 'A\0B','A'*64],['Bag','Target','','AB'],['Target','','AB'],['Target','Other'],[False,True])]
cases +=[dict(**d)for d in[dict(empty=True),*[dict(missing=i)for i in[1,2,3]],*[dict(badStatus=i)for i in[1,2,3]],dict(first='A\0B',query='A\0B')]]
cases +=[dict(mode='panel',panel=p)for p in[0,1,2,3,4,5,255,256,-1]]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-repository-tag-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
