"""Execute unchanged CGuiListBox::HandleKeyEvent1e9790 over selection boundaries.
Line-count/state/color, wrapper scrolling and selected/unselected callbacks are
captured GUI helper boundaries. No original process, window, network or pixels.
This proves the list key policy, not the entire browser or keyboard mapping.
"""
import hashlib, importlib.util, itertools, json
from pathlib import Path
spec=importlib.util.spec_from_file_location('key_coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
owner,string,string_vtable,display,wrapper_vtable=[m.heap+n*0x1000 for n in range(5)]
helpers={name:m.stop+0x100+i*0x10 for i,name in enumerate(['count','state','set-state','color','select','unselect','scroll'])}

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a in helpers.values():
  name=next(name for name,address in helpers.items() if address==a)
  row=u.reg_read(UC_X86_REG_RDX)&0xffffffff;row=row-0x100000000 if row>0x7fffffff else row
  if name=='count':m.finish(case['count'])
  elif name=='state':m.finish(0)
  else:
   if name in ['select','unselect','scroll']:calls.append([name,row])
   m.finish()
  return
 if not 0x1401e9790<=a<=0x1401e99a1:raise RuntimeError(f'Uncaptured list-key dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(count,selected,key,pressed,disabled):
 global case,calls
 case=dict(count=count,selected=selected,key=key,pressed=pressed,disabled=disabled);calls=[]
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(owner+0x80,wrapper_vtable);m.wq(wrapper_vtable,helpers['scroll']);m.wq(owner+0x88,display)
 m.wi(display,0);m.wi(display+4,4);m.wq(owner+0x90,string);m.wq(string,string_vtable)
 for offset,name in [(0xe8,'count'),(0xf0,'state'),(0xf8,'set-state'),(0x108,'color')]:m.wq(string_vtable+offset,helpers[name])
 m.wq(owner+0x408,owner);m.wq(owner+0x410,helpers['select']);m.wq(owner+0x418,owner);m.wq(owner+0x420,helpers['unselect'])
 m.wi(owner+0x42c,selected);u.mem_write(owner+0xe8,bytes([disabled]))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,owner),(UC_X86_REG_RDX,key),(UC_X86_REG_R8,pressed)]:u.reg_write(reg,value)
 u.emu_start(0x1401e9790,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return case|dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,after=m.si(owner+0x42c),calls=calls)

rows=[]
for count in [0,1,5,130]:
 for selected,key,pressed,disabled in itertools.product(sorted(set([-1,0,max(0,count-1)])),range(0x2a,0x30),[0,1],[0,1]):rows.append(run(count,selected,key,pressed,disabled))
out=m.root/'backups/animations/native-server-list-key-observations-v1.json';assert not out.exists()
out.write_text(json.dumps(dict(binarySha256=m.digest,harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limits=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(rows=len(rows),output=str(out))))
