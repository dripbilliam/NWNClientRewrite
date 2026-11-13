"""Original SetMaxCharacters202390 and HandleKeyPress201480 execute unchanged.
Text-wrapper line-count/first-line access and the parent CGuiEdit key handler
are explicit providers. ASCII text lengths isolate the derived max-length
guard; parent text editing, clipboard contents, Unicode and pixels are excluded.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
edit,wrapper,vtable,text=[m.heap+n for n in [0x1000,0x3000,0x5000,0x7000]]
def hook(u,a,n,_):
 global forwarded
 if a==m.stop:u.emu_stop();return
 if a==m.stop+0x10:m.finish(1)
 elif a==m.stop+0x20:m.finish(text)
 elif a==0x1401e99b0:forwarded=True;m.finish(7)
 elif not (0x140201480<=a<0x140201550 or 0x140202390<=a<0x1402023b0):raise AssertionError(f'Unmapped original edit-key dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,value):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,edit);u.reg_write(UC_X86_REG_RDX,value&0xffffffff)
 u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def run(limit,length,name,key):
 global forwarded
 forwarded=False;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(edit+0x90,wrapper);m.wq(wrapper,vtable);m.wq(vtable+0xe8,m.stop+0x10);m.wq(vtable+0xe0,m.stop+0x20);u.mem_write(text,b'A'*length+b'\0')
 call(0x140202390,limit);result=call(0x140201480,key)
 return dict(input=dict(limit=limit,length=length,name=name,key=key),maximum=m.si(edit+0x108),forwarded=forwarded,result=result)
if __name__=='__main__':
 out=m.root/'backups/animations/native-generic-edit-key-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 keys={'letter':65,'backspace':8,'linefeed':10,'enter':13,'escape':27,'left':0x125,'right':0x127,'delete':0x12e,'home':0x124,'end':0x123,'tab':9,'paste':22,'shift':0x110}
 rows=[run(limit,length,name,key)for limit,length,(name,key) in itertools.product([-1,0,1,20,32],[0,19,20,21,32],keys.items())]
 out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,procedures=['0x140202390','0x140201480'],rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
