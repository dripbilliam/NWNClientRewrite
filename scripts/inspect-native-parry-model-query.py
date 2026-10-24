"""Whole original model18 getters for simple, head and composite body contexts.
Synthetic model pointers/virtual-base displacement; no model loader execution.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def hook(u,a,n,data):
 if any(lo<=a<hi for lo,hi in [(0x14099e6bc,0x14099e6e6),(0x14099b174,0x14099b1b0),(0x140964690,0x1409646a0)]):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for kind,address in [('body',0x14099e6bc),('head',0x14099b174),('simple',0x140964690)]:
 for displacement in [0,8,32]:
  for present in [False,True]:
   t.reset(dict(format=1));context=m.heap+0x9000;pointer=m.heap+0xa000 if present else 0;m.wi(context-4,displacement);m.wq(context-displacement-16,pointer);m.wq(context+0xc8,pointer)
   value=w.call(address,[context,18,0,0]);rows.append(dict(kind=kind,displacement=displacement,present=present,value=bool(value)));assert bool(value)==(kind=='body'and present),(kind,displacement,present,hex(value))
out=m.root/'backups/animations/native-parry-model-query-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
