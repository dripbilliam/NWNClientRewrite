"""Execute unchanged original pregame CCharPageFeats::SetData1409c0db0.
Only external UI/name/rules lookup services are captured. Original list traversal,
successor admission and duplicate behavior execute in the original instructions.
This is not a visual or original-client live-input comparison.
"""
import importlib.util, json, struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
page,stats,main,bonus,ids,feats,string,vtable=[m.heap+n for n in [0x1000,0x4000,0x6000,0x7000,0x8000,0x10000,0x90000,0x91000]]
text_stub=m.stop+0x100
creature=m.heap+0x3000
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1401edf80:m.wi(page+0x5a0,0);m.finish()
 elif a==0x140800c90:m.finish(creature)
 elif a==0x1407f3dc0:m.finish(case['main'][y&65535])
 elif a==0x1407f0ae0:m.finish(case['bonus'][y&65535])
 elif a==0x1402a3bd0:m.finish(feats+(y&65535)*0x100 if str(y&65535)in case['successors']else 0)
 elif a==0x1402a12d0:m.finish(string+0x80)
 elif a==0x1409c0630:
  selected.append(y&65535);m.wi(ids+4*(len(selected)-1),y&65535);m.wi(page+0x5a0,len(selected));m.finish()
 elif a in[0x140c10370,0x1401fb540,text_stub,0x140115890]:m.finish()
 elif not 0x1409c0920<=a<=0x1409c1217:raise AssertionError(f'Uncaptured summary feat dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c,live=False):
 global case,selected
 case=c;selected=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(stats+0x118,main);m.wi(stats+0x120,len(c['main']));m.wq(stats+0x128,bonus);m.wi(stats+0x130,len(c['bonus']))
 for ptr,values in[(main,c['main']),(bonus,c['bonus'])]:
  for i,v in enumerate(values):u.mem_write(ptr+2*i,struct.pack('<H',v&65535))
 for feat,next_id in c['successors'].items():m.wi(feats+int(feat)*0x100+0x54,next_id)
 m.wq(page+0x920,ids);m.wq(page+0x188,string);m.wq(string,vtable);m.wq(vtable+0xd0,text_stub)
 m.wq(creature+0x3b0,stats)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,page);u.reg_write(UC_X86_REG_RDX,42 if live else stats)
 u.emu_start(0x1409c0920 if live else 0x1409c0db0,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 for ptr,values in[(main,c['main']),(bonus,c['bonus'])]:assert list(struct.unpack('<'+'H'*len(values),u.mem_read(ptr,len(values)*2)))==values
 return dict(case=c,selected=list(selected))
if __name__=='__main__':
 prior=json.loads((m.root/'backups/animations/native-record-feat-observations-v1.json').read_text())
 assert prior['target']==m.digest
 rows=[run(row['case'])for row in prior['rows']]
 assert [row['selected']for row in rows]==[row['selected']for row in prior['rows']]
 out=m.root/'backups/animations/native-pregame-feat-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 out.write_text(json.dumps(dict(target=m.digest,procedure='0x1409c0db0',scope=__doc__,rows=rows),indent=2))
 print(json.dumps(dict(output=str(out),rows=len(rows),matchesGameplayAdmission=True)))
