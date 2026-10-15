"""Original repository weight465310. Linked-list iteration, canonical item
lookup, allocations/string and cost-table/FLOAT access are captured lower
owners. Child repository calls are captured as ordered independent values.
Native pool selection, repeated recursion, INT/FLOAT rounding and sum execute.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);repo,ll,nodes,idcells,owner,children,table,rules,app,active,passive,childrepo=[m.heap+n*0x1000 for n in range(1,13)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x140465310 and x!=repo:calls.append(['nested']);m.finish(c.get('nestedValues',[5,7])[min(len([x for x in calls if x[0]=='nested'])-1,len(c.get('nestedValues',[5,7]))-1)])
    elif a==0x1401690b0:m.finish(idcells+(y-nodes)//0x30*4)
    elif a==0x140169110:
        index=(m.q(y)-nodes)//0x30+1;m.wq(y,nodes+index*0x30 if index<c.get('count',2) else 0);m.finish()
    elif a==0x14055b6c0:
        m.finish(owner if y==99 and c.get('owner',True) else children+(y-100)*0x500 if 100<=y<100+c.get('count',2) and y not in c.get('missing',[]) else 0)
    elif a==0x1402b38a0:calls.append(['table',y&255]);m.finish(table)
    elif a==0x1401a6c70:calls.append(['row',y&0xffffffff]);u.mem_write(w,struct.pack('<f',c.get('reduction',.5)));m.finish(1)
    elif a==0x140c10368:m.finish(m.heap+0xe000)
    elif a==0x140c10370:m.finish()
    elif a==0x140115890:calls.append(['warning']);m.finish()
    elif not 0x140465310<=a<0x14046569d:raise AssertionError(f'Uncaptured contents weight dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,rules);m.wi(repo+8,99);m.wq(repo+0x10,ll);m.wi(ll+0x10,c.get('count',2));m.wq(ll,nodes if c.get('count',2)>0 else 0)
    for i in range(c.get('count',2)):
        m.wi(idcells+i*4,100+i);ptr=children+i*0x500;m.wi(ptr+0x454,c.get('stack',1));m.wi(ptr+0x45c,c.get('unit',10));m.wq(ptr+0x3d0,childrepo if c.get('nested',False) else 0)
    for offset,pool,properties in [(0x368,active,c.get('active',[])),(0x378,passive,c.get('passive',[]))]:
        m.wq(owner+offset,pool);m.wi(owner+offset+8,len(properties))
        for i,p in enumerate(properties):u.mem_write(pool+i*0x30,struct.pack('<H',p[0]&65535));u.mem_write(pool+i*0x30+6,struct.pack('<H',p[1]&65535))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,repo);u.emu_start(0x140465310,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
    return dict(case=c,calls=calls,result=result if result<0x80000000 else result-0x100000000)
rows=[]
for props,unit,stack,reduction,nested in itertools.product([dict(active=[],passive=[]),dict(active=[],passive=[[32,3]]),dict(active=[[32,2]],passive=[[32,3]])],[-2147483648,-1,0,1,10,2147483647],[-1,1,2],[-1,0,.1,.5,1,2],[False,True]):rows.append(run(props|dict(unit=unit,stack=stack,reduction=reduction,nested=nested)))
for extra in [dict(count=0),dict(missing=[100]),dict(owner=False),dict(active=[[32,65537]]),dict(active=[[11,1],[32,2],[32,3]])]:rows.append(run(dict(active=[[32,1]],passive=[[32,4]])|extra))
out=m.root/'backups/animations/native-contents-weight-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
