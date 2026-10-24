"""Original6f1bc0 input timer adjustment, unchanged isolated instructions.
Only CExoTimers::GetMicrosecondTimer is captured at a fixed fixture timestamp;
the native integer/double conversions and stored timestamp execute directly.
"""
import sys,importlib,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');u=p.u;m=p.m;w=p.w
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
def hook(u,a,n,data):
 if a==0x14016dd30:m.finish(10000000);return
 if 0x1406f1bc0<=a<0x1406f1c17:return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for fraction in [0,.0078125,.015625,.03125,.125,.25,.5,.5078125,.75,.9921875,1.]:
 p.t.reset(dict(format=1));m.wq(0x1412df8b8,p.owner);m.wq(p.owner+0x10,p.area)
 u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',fraction),'little'));w.call(0x1406f1bc0,[p.ui])
 rows.append(dict(fraction=fraction,nowMicroseconds=10000000,lastWireMicroseconds=m.q(p.ui+0x1a0)))
out=m.root/'backups/animations/native-drive-refresh-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
