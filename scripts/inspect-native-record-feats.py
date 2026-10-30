"""Read-only execution of complete CCharPageFeats::SetData1409c0920.
Original ownership/successor traversal and list admission execute unchanged.
World/feat/name lookup, UI row construction and clearing are captured services;
row order here is admission order, not the separate native sorted insertion.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
page,actor,stats,main,bonus,ids,feats,string,vtable=[m.heap+n for n in [0x1000,0x3000,0x4000,0x6000,0x7000,0x8000,0x10000,0x90000,0x91000]]
text_stub=m.stop+0x100
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1401edf80:m.wi(page+0x5a0,0);m.finish()
 elif a==0x140800c90:m.finish(actor)
 elif a==0x1407f3dc0:m.finish(case['main'][y&65535])
 elif a==0x1407f0ae0:m.finish(case['bonus'][y&65535])
 elif a==0x1402a3bd0:m.finish(feats+(y&65535)*0x100 if str(y&65535)in case['successors']else 0)
 elif a==0x1402a12d0:m.finish(string+0x80)
 elif a==0x1409c0630:
  selected.append(y&65535);m.wi(ids+4*(len(selected)-1),y&65535);m.wi(page+0x5a0,len(selected));m.finish()
 elif a in[0x140c10370,0x1401fb540,text_stub,0x140115890]:m.finish()
 elif not 0x1409c0920<=a<=0x1409c0da8:raise AssertionError(f'Uncaptured feat record dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,selected
 case=c;selected=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(actor+0x3b0,stats);m.wq(stats+0x118,main);m.wi(stats+0x120,len(c['main']));m.wq(stats+0x128,bonus);m.wi(stats+0x130,len(c['bonus']))
 for ptr,values in[(main,c['main']),(bonus,c['bonus'])]:
  for i,v in enumerate(values):u.mem_write(ptr+2*i,struct.pack('<H',v&65535))
 for feat,next_id in c['successors'].items():m.wi(feats+int(feat)*0x100+0x54,next_id)
 m.wq(page+0x920,ids);m.wq(page+0x188,string);m.wq(string,vtable);m.wq(vtable+0xd0,text_stub)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,page);u.reg_write(UC_X86_REG_RDX,42)
 u.emu_start(0x1409c0920,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 for ptr,values in[(main,c['main']),(bonus,c['bonus'])]:assert list(struct.unpack('<'+'H'*len(values),u.mem_read(ptr,len(values)*2)))==values
 return dict(case=c,selected=list(selected))
if __name__=='__main__':
 simple={str(i):(-1 if i%3==0 else i+1)for i in range(1,40)}
 cases=[dict(main=a,bonus=b,successors=simple)for a,b in[([],[]),([1],[]),([1,2],[]),([1,2,3],[]),([1],[2]),([1],[2,3]),([2,3],[4]),([1,1,2],[]),([5,3,1],[6,4,2]),(list(range(1,20)),[20,21]),([1],list(range(2,22))),(list(range(1,20)),list(range(20,39))),([39,40],[])]]
 cases+=[dict(main=[1,2,3],bonus=[4],successors={'1':0,'2':65535,'3':65540,'4':-1}),dict(main=[1,2],bonus=[],successors={'1':3,'2':0,'3':2})]
 rows=[run(c)for c in cases]
 out=m.root/'backups/animations/native-record-feat-observations-v1.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),sample=rows[4])))
