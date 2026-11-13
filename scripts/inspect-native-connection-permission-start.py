"""Run unchanged StartConnectToSession permission initialization decisions.

Both original app-mode branches execute the complete function. App queries,
empty string copies, local window allocation, cryptographic handshake, timer
and sends are captured boundaries; no crypto or packet reaches a network.
This proves the connection-start permission field, not a connection handshake.
"""
from pathlib import Path
import hashlib,itertools,json
root=Path(__file__).resolve().parents[1]
fixture=Path(__file__).with_name('inspect-native-creature-radial.py')
proof=json.loads((root/'godot-client/reports/native-creature-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
source=fixture.read_text();assert source.count('\nrows=[]\n')==1
prefix=source.split('\nrows=[]\n')[0].replace('u.hook_add(UC_HOOK_CODE, hook)','hook_handle=u.hook_add(UC_HOOK_CODE, hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_connect_permission_fixture'};exec(compile(prefix,str(fixture),'exec'),ns)
u,heap=ns['u'],ns['heap'];u.hook_del(ns['hook_handle'])
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
internal=0x500000000;u.mem_map(internal,4096);u.mem_map(internal+0x28a5000,0x3000)
app,vt,empty,crypto,net=[heap+n for n in [0x20000,0x21000,0x22000,0x23000,0x24000]]
active=None;calls=[];trace=[]
def hook(_u,a,size,data):
 if a==ns['stop']:u.emu_stop();return
 trace.append(hex(a))
 if len(trace)>40:trace.pop(0)
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==ns['stop']+0x100:ns['finish'](active['appMode'])
 elif a in (ns['stop']+0x200,ns['stop']+0x300):ns['finish'](0)
 elif a==0x14003d8c0:u.mem_write(x,bytes(16));ns['finish'](x)
 elif a==0x140253a20:ns['wi'](z,7);ns['finish'](1)
 elif a==0x1402502f0:calls.append({'kind':'BNCS-boundary','connectionType':z&255});ns['finish'](1)
 elif a==0x140175860:ns['finish'](crypto)
 elif a==0x1406758e0:u.mem_write(x,bytes(y));ns['finish'](0)
 elif a==0x140674fe0:ns['finish'](0)
 elif a==0x1402511f0:calls.append({'kind':'direct-message-boundary','length':u.reg_read(UC_X86_REG_R9)});ns['finish'](1)
 elif a==0x14016dd40:ns['finish'](123)
 elif a==0x140c10410:ns['finish'](u.reg_read(UC_X86_REG_RAX))
 elif not 0x140254ed0<=a<=0x1402553a0:raise RuntimeError('Uncaptured original connection-start boundary '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for mode,kind,old in itertools.product([0,1],[0,16,32,255],[0,1,0x7fffffff]):
 active={'appMode':mode,'connectionType':kind,'oldPermission':old};calls.clear();trace.clear()
 u.mem_write(heap,bytes(0x100000));u.mem_write(internal,bytes(4096));u.mem_write(internal+0x28a5000,bytes(0x3000));u.mem_write(ns['stack'],bytes(0x10000))
 ns['wq'](internal+0x50,app);ns['wq'](app,vt);ns['wq'](vt+0xc0,ns['stop']+0x100);ns['wq'](vt+0x80,ns['stop']+0x200);ns['wq'](vt+0x58,ns['stop']+0x300)
 ns['wq'](internal+0x58,net);ns['wq'](net+8,net+0x100);ns['wq'](internal+0x28a5650,heap+0x25000);ns['wi'](heap+0x25000,7);ns['wi'](internal+0x28a566c,1);ns['wi'](internal+0x28a56e0,old)
 ns['wq'](0x1412df8b8,heap+0x26000);ns['wq'](heap+0x26010,heap+0x27000)
 for reg in [UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R10,UC_X86_REG_R11,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(reg,0)
 sp=ns['stack']+0xfe08;ns['wq'](sp,ns['stop']);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,internal);u.reg_write(UC_X86_REG_RDX,0);u.reg_write(UC_X86_REG_R8,empty);u.reg_write(UC_X86_REG_R9,0)
 for offset,value in [(0x28,empty),(0x30,0),(0x38,kind),(0x40,empty),(0x48,empty),(0x50,empty)]:ns['wq'](sp+offset,value)
 try:u.emu_start(0x140254ed0,ns['stop'],count=100000)
 except Exception as error:raise RuntimeError(str(error)+'; trace='+str(trace)) from error
 assert u.reg_read(UC_X86_REG_RIP)==ns['stop'] and u.reg_read(UC_X86_REG_RAX)==1
 value=int.from_bytes(u.mem_read(internal+0x28a56e0,4),'little');expected=int(kind==32) if mode==0 else 0
 assert value==expected,(active,value,expected,trace)
 assert len(calls)==1 and calls[0]['kind']==('BNCS-boundary' if mode==0 else 'direct-message-boundary')
 rows.append({'input':active,'permission':value,'calls':list(calls)})
report={'success':True,'binarySha256':ns['digest'],'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'fixtureSha256':proof['scriptSha256'],'cases':len(rows),'rows':rows,'scope':__doc__,'limits':['Success-path app/crypto/send/timer/string/window service results are authored; no actual connection or transport behavior is proved.','Normal connectionType16 yields0 in both branches, overwriting prior permission. Type32 differs by app mode and cannot be generalized from normal16.','This does not publish permission as received server data or set any creature skill override.']}
out=ns['output'];out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'success':True,'cases':len(rows),'report':str(out)}))
