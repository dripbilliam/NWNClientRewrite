"""Original amount callbacks, decimal parser, number-key gate and timer buttons.
Original CRT C-locale decimal parsing executes; locale/thread-error setup is
captured as in the retained campaign-query harness. GUI text, source callbacks,
animation/audio/mouse-capture publication are captured without an OS window.
No server/network/game process or original executable modification is used.
"""
import hashlib,itertools,json,struct
from pathlib import Path
source=Path(__file__).with_name('inspect-native-campaign-queries.py')
prefix=source.read_text().split('rows=[run(')[0]
assert prefix.count('u.hook_add(UC_HOOK_CODE,hook)')==1
scope={'__file__':str(source),'__name__':'native_amount_harness'}
exec(compile(prefix.replace('u.hook_add(UC_HOOK_CODE,hook)',''),str(source),'exec'),scope)
m,u=scope['m'],scope['u'];base_hook=scope['hook'];panel=m.heap+0x20000;buffer=m.heap+0x22000;model=m.heap+0x24000;vtable=m.heap+0x25000
def signed(n):return (n&0xffffffff)-(0x100000000 if n&0x80000000 else 0)
def text(p):
 raw=b''
 while p and len(raw)<1024:
  byte=bytes(u.mem_read(p+len(raw),1))
  if byte==b'\0':break
  raw+=byte
 return raw.decode('cp1252')
def put(p,value):
 raw=value.encode('cp1252');u.mem_write(buffer,raw+b'\0');m.wq(p,buffer);m.wi(p+8,len(raw));m.wi(p+12,len(raw)+1)
def hook(u,a,n,data):
 x,y,z=[u.reg_read(scope[r]) for r in ['UC_X86_REG_RCX','UC_X86_REG_RDX','UC_X86_REG_R8']]
 if a==0x1401e93b0:put(y,case['text']);m.finish(y);return
 if a==0x14016c810:put(x,str(signed(y)));m.finish(x);return
 if a==0x1402023d0:calls.append(['text',text(m.q(y))]);m.finish();return
 if a==m.stop+0x100:calls.append(['callback',signed(y)]);m.finish();return
 if a==0x1401fc440:calls.append(['deactivate',y&0xffffffff]);m.finish();return
 if a==0x1401e9d70:calls.append(['key',signed(y)]);m.finish(17);return
 if a==0x1401fac90:m.finish(x);return
 if a==0x1401f6110:calls.append(['sound',text(x)]);m.finish();return
 if a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a==0x1401f45b0:calls.append(['capture',z&0xffffffff]);m.finish();return
 if a in [m.stop+0x110,m.stop+0x118]:calls.append(['animation' if a==m.stop+0x110 else 'down']);m.finish();return
 if any(lo<=a<hi for lo,hi in [(0x1409aa6d0,0x1409aa713),(0x1409aa720,0x1409aa740),(0x1409aa740,0x1409aa7c2),(0x1409aa810,0x1409aa89e),(0x1409aa920,0x1409aa9a6),(0x140201470,0x14020147d),(0x1401e4a20,0x1401e4acb),(0x1401e4d30,0x1401e4db2),(0x1401e4f70,0x1401e50d0)]):return
 base_hook(u,a,n,data)
u.hook_add(scope['UC_HOOK_CODE'],hook)
def run(value,address,second=0):
 global case,calls
 case=value;calls=[];scope['c']={'mode':'atoi'};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 locale,ctype=scope['locale'],scope['ctype'];m.wq(locale,ctype);m.wi(locale+8,1)
 for byte in [9,10,11,12,13,32]:u.mem_write(ctype+byte*2,struct.pack('<H',8))
 m.wi(panel+0x660,value.get('maximum',27));m.wq(panel+0xf8,panel);m.wq(panel+0x100,m.stop+0x100)
 m.wq(panel+0xd0,panel);m.wq(panel+0xd8,m.stop+0x100);m.wq(panel+0x80,panel);m.wq(panel+0x88,m.stop+0x118)
 m.wi(panel+0xe0,50000);m.wi(panel+0xe4,500000);m.wi(panel+0xe8,value.get('elapsed',0));u.mem_write(panel+0xec,bytes([value.get('initial',1)]))
 m.wq(panel+0x60,m.q(0x14128f2f0) if value.get('held',True) else 0)
 m.wq(panel+0x10,model);m.wq(model,vtable);m.wq(vtable+0x30,m.stop+0x110);m.wq(0x14140cdb8,0x12345678)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop)
 for reg,val in [('UC_X86_REG_RSP',sp),('UC_X86_REG_RCX',panel),('UC_X86_REG_RDX',second&0xffffffff)]:u.reg_write(scope[reg],val)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(scope['UC_X86_REG_RIP'])==m.stop
 return dict(case=value,calls=calls,result=signed(u.reg_read(scope['UC_X86_REG_RAX'])),elapsed=m.si(panel+0xe8),initial=int.from_bytes(u.mem_read(panel+0xec,1),'little'),eventRestored=m.q(0x14140cdb8)==0x12345678)
strings=['','0','1','26','27','28','65535','65536','-1','+2',' 12','12.5','1e9','12/3','--2','+ 2','foo','\t\n-123tail','12\0'+'34','\u00a012','2147483647','2147483648','-2147483648','-2147483649','9'*80]
rows=[]
for action,address in [('all',0x1409aa6d0),('up',0x1409aa920),('down',0x1409aa740),('confirm',0x1409aa810)]:
 for maximum,raw in itertools.product([0,1,27,65535,2147483647],strings):rows.append(dict(action=action,**run(dict(maximum=maximum,text=raw),address)))
timers=[run(dict(elapsed=elapsed,initial=initial,held=held,delta=delta),0x1401e4d30,delta) for elapsed,initial,held,delta in itertools.product([0,49999,50000,500000,2147483647],[0,1],[False,True],[0,1,49999,50000,50001,499999,500000,500001,1000000,2147483647])]
keys=[run(dict(code=code),0x140201470,code) for code in [-1,*range(129),0x123,0x12e,0x20ac]]
constructor=run({},0x1401e4a20);constructor['period']=m.si(panel+0xe0);constructor['delay']=m.si(panel+0xe4)
down=run(dict(elapsed=123,initial=0),0x1401e4f70)
for row in rows:
 if '\0' in row['case']['text']:
  # Godot's JSON reader cannot materialize NUL inside a String. Keep every
  # supplied byte, plus the exact C-string prefix consumed by the callback.
  row['case']['inputBytes']=list(row['case']['text'].encode('cp1252'));row['case']['text']=row['case']['text'].split('\0')[0]
output=m.root/'backups/animations/native-amount-dialog-observations-v2.json';assert not output.exists(),'Retain old evidence'
output.write_text(json.dumps(dict(binarySha256=m.digest,harnessSha256=hashlib.sha256(source.read_bytes()).hexdigest(),limits=__doc__,amounts=rows,timers=timers,keys=keys,constructor=constructor,down=down),indent=2)+'\n')
print(json.dumps(dict(amounts=len(rows),timers=len(timers),keys=len(keys),output=str(output))))
