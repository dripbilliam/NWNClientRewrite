"""Execute complete original797ae0 minor22 plus native permission setter/getter.

Decoded BOOL/BOOL/INT32 reads, current-actor lookup and inactive GUI refresh
services are captured boundaries. The original direct stats110/114 stores and
CNetLayer permission field writes execute unchanged. No client/server/GPU.
"""
from pathlib import Path
import hashlib,itertools,json,struct
root=Path(__file__).resolve().parents[1]
fixture=Path(__file__).with_name('inspect-native-creature-radial.py')
proof=json.loads((root/'godot-client/reports/native-creature-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
source=fixture.read_text();assert source.count('\nrows=[]\n')==1
prefix=source.split('\nrows=[]\n')[0].replace('u.hook_add(UC_HOOK_CODE, hook)','hook_handle=u.hook_add(UC_HOOK_CODE, hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_permission_fixture'};exec(compile(prefix,str(fixture),'exec'),ns)
u,heap=ns['u'],ns['heap'];u.hook_del(ns['hook_handle'])
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
net,internal,gui,stats=[heap+n for n in [0xb000,0xc000,0xd000,0x9000]]
permission_address=internal+0x28a56e0;u.mem_map(permission_address&~4095,4096)
active=None;booleans=[];reads=[]
refresh={0x14086c1a0,0x14086d2b0,0x14086caa0,0x14086bcb0,0x14086c980,0x14086c4b0,0x14086c320,0x14086c100,0x14086cf20,0x140849f80,0x1406fad10,0x140849f60}
def hook(_u,address,size,data):
 if address==0x140797ae0:
  u.reg_write(UC_X86_REG_RDX,22);ns['wq'](net+8,internal);ns['wi'](permission_address,7)
  ns['wi'](stats+0x110,active['initialOverride']);ns['wi'](stats+0x114,123)
 if address==ns['stop']+0x100:ns['finish'](net)
 elif address==0x1402d9600:reads.append(['BOOL']);ns['finish'](booleans.pop(0))
 elif address==0x1402d9ec0:reads.append(['INT',u.reg_read(UC_X86_REG_RDX)]);ns['finish'](active['parameter']&0xffffffff)
 elif address==0x1406abbc0:ns['finish'](gui)
 elif address==0x1406ac1a0:ns['finish'](ns['actor'] if active['actorPresent'] else 0)
 elif address in refresh:ns['finish'](0)
 elif address==0x140c10410:ns['finish'](u.reg_read(UC_X86_REG_RAX))
 elif 0x140237ca0<=address<=0x140237caf or 0x1402377b0<=address<=0x1402377c0:pass
 else:ns['hook'](_u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for permission,secondary,parameter,initial,present in itertools.product([0,1],[0,1],[-2147483648,0,123,2147483647],[-1,0,1],[False,True]):
 active=dict(permission=permission,secondary=secondary,parameter=parameter,initialOverride=initial,actorPresent=present)
 booleans[:]=[permission,secondary];reads.clear();ns['execute'](0x140797ae0,0x140799115)
 override=int.from_bytes(u.mem_read(stats+0x110,4),'little',signed=True);secondary_result=int.from_bytes(u.mem_read(stats+0x114,4),'little',signed=True)
 assert override==(0 if present and not permission else initial)
 assert secondary_result==(secondary if present else 123)
 assert reads==[['BOOL'],['BOOL'],['INT',32]] and not booleans
 sp=ns['stack']+0xfe08;ns['wq'](sp,ns['stop']);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,net)
 u.emu_start(0x1402377b0,ns['stop'],count=100)
 value=u.reg_read(UC_X86_REG_RAX)&0xffffffff;assert value==permission
 rows.append(dict(input=active,connectionPermission=value,override=override,secondary=secondary_result,reads=list(reads)))
report=dict(success=True,binarySha256=ns['digest'],scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),fixtureSha256=proof['scriptSha256'],cases=len(rows),rows=rows,scope=__doc__,limits=['Major31 mapping is separately established from original7a41a0 dispatcher; this executes the complete minor handler and setter/getter, not that outer dispatcher.','Reader and GUI refresh boundaries are captured; original bit decoder, malformed input, GUI pixels and live-server effects are not exercised.','Permission true does not set stats110 true; it preserves the existing override. A missing controlled actor receives no stats mutation.'])
out=ns['output'];out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,cases=len(rows),report=str(out))))
