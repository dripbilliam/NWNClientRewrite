"""Original key-settings initial/default population control flow, unchanged.
Feeds controlled Keymap/INI/language query responses; captures string storage,
row construction/deletion and key-caption resolution. Input eligibility uses
the separately executed original predicate observations. This verifies caller
ordering/fallback/deduplication, not actual C2DA parsing or visible UI parity.
No original process, user profile, input or server is accessed.
"""
import importlib.util,json,struct,re,copy
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
source=json.loads((m.root/'backups/animations/rea-native-key-settings-v1.json').read_text())
ranges=[(int(b['start'],16),int(b['end'],16)+1) for row in source['dossiers'] if row['result'].get('procedure',{}).get('address') in ['0x1408be080','0x1408befa0'] for b in row['result']['procedure']['body']['ranges']]
capture=json.loads((m.root/'backups/animations/native-key-capture-observations-v1.json').read_text())
eligible={row['code']:row['result'] for row in capture['remappable']}
installed=json.loads((m.root/'godot-client/reports/native-keymap-catalog-v2.json').read_text())
panel=m.heap+0x1000;pages=[m.heap+0x4000+i*0x1000 for i in range(4)]
cursor=0;rows=[];case={};queried=[]
def cstring(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('ascii') if ptr else ''
def string(ptr):return cstring(m.q(ptr))
def signed(value):return struct.unpack('<i',struct.pack('<I',value&0xffffffff))[0]
def alloc(count):
 global cursor
 ptr=m.heap+0x10000+cursor;cursor+=(count+15)&~15;assert cursor<0x90000;return ptr
def set_string(ptr,text):
 b=text.encode('ascii')+b'\0';p=alloc(len(b));u.mem_write(p,b);m.wq(ptr,p);m.wi(ptr+8,len(b)-1);m.wi(ptr+12,len(b));return ptr
def get_integer(action,column):
 row=next((r for r in case['table'] if r['row_name'].lower()==action.lower()),{})
 key=next((k for k in row if k.lower()==column.lower()),None);value=str(row[key]) if key else ''
 if not value or value=='****':return 0,0
 return 1,int(value,16) if value.lower().startswith('0x') else int(value)
def hook(u,address,size,_):
 if address==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if address==0x140c113c0:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if address in [0x140c10370,0x140c10410,0x1401edf80]:m.finish();return
 if address==0x140c10368:m.finish(alloc(x));return
 if address==0x1406ab950:m.finish(case['language']);return
 if address==0x14016afb0:
  fmt=cstring(y)
  if fmt in ['ActionStrRef','Page','Language0']:text=fmt
  elif fmt=='Language%d':text='Language'+str(signed(z))
  elif fmt=='%s%d':text=cstring(z)+str(signed(w))
  else:raise AssertionError(fmt)
  set_string(x,text);m.finish(x);return
 if address==0x14016c810:set_string(x,str(signed(y)));m.finish(x);return
 if address==0x14016ab00:set_string(y,string(x)+string(z));m.finish(y);return
 if address==0x1401a6e00:
  action,column=string(y),string(z);found,value=get_integer(action,column);queried.append([action,column,found,value]);m.wi(w,value);m.finish(found);return
 if address==0x14016eb40:m.finish(eligible[y&255]);return
 if address==0x140168560:
  key=string(m.q(rsp+0x28));assert string(w)=='Keymapping'
  if key in case['profile']:set_string(y,str(case['profile'][key]));m.finish(1)
  else:m.finish(0)
  return
 if address==0x140c81d54:m.finish(int(cstring(x)));return
 if address==0x1408bbce0:set_string(y,'key'+str(signed(z)));m.finish(y);return
 if address==0x1408bb0c0:
  assert x in pages;rows.append(dict(action=y&0xffffffff,page=pages.index(x),strRef=signed(z),binding=int(string(w)[3:])));m.finish();return
 if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured population dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,cursor,rows,queried
 case=c;cursor=0;rows=[];queried=[];u.mem_write(m.heap,bytes(0x100000))
 for global_addr,ptr in [(0x1412df970,m.heap+0x9000),(0x1412df8f8,m.heap+0xa000),(0x1412df8c8,m.heap+0xb000),(0x1412df8b8,m.heap+0xc000)]:m.wq(global_addr,ptr)
 m.wq(m.heap+0xa000+0x130,m.heap+0xd000);m.wq(m.heap+0xd000+0x228,m.heap+0xe000)
 for i,ptr in enumerate(pages):m.wq(panel+0x158+i*8,ptr)
 for action in range(109):m.wi(panel+0x738+action*8,-1)
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel)
 u.emu_start(0x1408befa0 if c['defaults'] else 0x1408be080,m.stop,count=200000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,rows=rows,values={str(a):m.si(panel+0x738+a*8) for a in range(37,109)},languageColumns=list(dict.fromkeys(q[1] for q in queried if q[1].startswith('Language'))))
synthetic=[dict(row_name='Action37',ActionStrRef=1,Language0=79,Language1=0,Page=0),dict(row_name='Action38',ActionStrRef=2,Language0=80,Language1='****',Page=1),dict(row_name='Action39',ActionStrRef=3,Language0=81,Language1='****',Page=2)]
cases=[]
for table_name,table in [('installed',installed['rows']),('zero-only-language',synthetic)]:
 for language in [0,1,5]:
  for defaults in [False,True]:
   for profile in [{},{'Action38':'79','Action39':'0','Action108':'68'}]:
    cases.append(dict(name=table_name,table=table,language=language,defaults=defaults,profile=profile))
# An eligible language with one real mapping must not fill its other rows from
# English; a stored entry can still add a row absent from the language defaults.
partial=copy.deepcopy(synthetic);partial[0]['Language1']=104
for defaults in [False,True]:cases.append(dict(name='partial-eligible-language',table=partial,language=1,defaults=defaults,profile={'Action38':'99'}))
observed=[run(c) for c in cases]
out=m.root/'backups/animations/native-key-population-observations-v1.json';assert not out.exists(),'Preserve prior observations'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,installedKeymapSha256=installed['sha256'],rows=observed),indent=2)+'\n')
print(json.dumps(dict(output=str(out),cases=len(observed))))
