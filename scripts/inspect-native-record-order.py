"""Read-only original _stricmp140c9a9fc / __ascii_stricmp140c9a9bc.
The original mapped executable's default locale-change flag is asserted zero;
its real comparator instructions execute unchanged for CP1252 label pairs.
This does not accept alternate runtime C locale settings.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);assert m.si(0x1415d7c18)==0
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not 0x140c9a9bc<=a<=0x140c9aa41:raise AssertionError(f'Uncaptured original label comparison dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def compare(a,b):
 first=m.heap;second=m.heap+0x1000
 u.mem_write(first,a.encode('cp1252')+b'\0');u.mem_write(second,b.encode('cp1252')+b'\0')
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,first);u.reg_write(UC_X86_REG_RDX,second)
 u.emu_start(0x140c9a9fc,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return result-0x100000000 if result>=0x80000000 else result
if __name__=='__main__':
 labels=['','Animal Empathy','animal empathy','Concentration','Skill 10','Skill 2','Évasion','évasion','[Feat]','Feat: A','A\0hidden','A','Å','€','Z']
 rows=[dict(first=a.replace('\0','\\0'),second=b.replace('\0','\\0'),firstBytes=list(a.encode('cp1252')),secondBytes=list(b.encode('cp1252')),result=compare(a,b))for a,b in itertools.product(labels,labels)]
 out=m.root/'backups/animations/native-record-order-observations-v2.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
