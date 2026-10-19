"""Complete original GLRender::ResetRenderStates0xb6050, GPU calls captured.

Executes original cached-state changes and initialization. Imported/dynamic
OpenGL calls, memset and max-light query are explicit lower boundaries. No GPU,
live process writes or claim about every subsequent material/pass override.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
d=json.loads((m.root/'backups/animations/rea-model-culling-render-reset.json').read_text())['structuredContent']['raw_result']['value'];ranges=[(int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges']];maxLights=int(next(c['address']for c in d['callees']if c['name']=='LightManager::GetMaxLights'),16)
callbacks={};nextCallback=m.stop+0x100
def callback(pointer,name):
 global nextCallback
 callbacks[nextCallback]=name;m.wq(pointer,nextCallback);nextCallback+=0x10
for dll in m.pe.DIRECTORY_ENTRY_IMPORT:
 for entry in dll.imports:
  if entry.name and entry.name.startswith(b'gl'):callback(entry.address,entry.name.decode())
for pointer,name in [(0x141443248,'glBindFramebuffer'),(0x141443f58,'glGenVertexArrays'),(0x141443f48,'glBindVertexArray'),(0x141442150,'glActiveTexture')]:callback(pointer,name)
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in callbacks:
  name=callbacks[a];calls.append(dict(name=name,args=[x&0xffffffff,y&0xffffffff,z&0xffffffff,k&0xffffffff]))
  if name=='glGenVertexArrays':m.wi(y,1)
  m.finish();return
 if a==maxLights:m.finish(0);return
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
calls=[];w.call(0x1400b6050,[0,0,0,0]);assert any(c['name']=='glEnable'and c['args'][0]==0xb44 for c in calls);assert any(c['name']=='glFrontFace'and c['args'][0]==0x901 for c in calls)
output=m.root/'backups/animations/native-render-reset-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,calls=calls),indent=2)+'\n');print(json.dumps(dict(output=str(output),calls=len(calls),culling=[c for c in calls if c['name']=='glFrontFace'or c['args'][0]==0xb44])))
