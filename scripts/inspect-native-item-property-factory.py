"""Complete unchanged shared item-property command factory. Capture VM pops,
effect constructor/storage/creator, active-table queries/cache, allocation and
engine-structure push/destruction. No spell bodies, module names or assets are
embedded; tests constructor selection, validation and exact 2DA query order.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
command,effect,rules,twodas=[m.heap+i*0x1000 for i in range(4)]
tables={'definition':m.heap+0x4000,'subtype':m.heap+0x5000,'cost':m.heap+0x6000,'IPRP_PARAMTABLE':m.heap+0x7000,'param':m.heap+0x8000};names={ptr:name for name,ptr in tables.items()}
def signed(value):return struct.unpack('<i',struct.pack('<I',value&0xffffffff))[0]
def text(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode('ascii') if m.q(ptr) else ''
def string(ptr,value):
 global cursor
 raw=value.encode('ascii');buf=m.heap+cursor;cursor+=(len(raw)+16)&~15;u.mem_write(buf,raw+b'\0');m.wq(ptr,buf);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1)
def query(table,column,string_):
 defaults={'definition':{'CostTableResRef':[1,3],'Param1ResRef':[1,0],'SubTypeResRef':[1,'subtype']},'subtype':{'Name':[1,1],'Param1ResRef':[1,0]},'cost':{'Name':[1,1]},'IPRP_PARAMTABLE':{'TableResRef':[1,'param']},'param':{}}
 return case.get('queries',{}).get(table,{}).get(column,defaults[table].get(column,[0,'' if string_ else 0]))
def hook(u,a,n,_):
 global cursor,popped,pushed,replayIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if 'replay'in case and a in [0x1401a68f0,0x1401a7010,0x1402b31e0,0x1402b38a0]:
  entry=case['replay'][replayIndex];replayIndex+=1;trace.append(entry)
  if a in [0x1401a68f0,0x1401a7010]:
   kind='string' if a==0x1401a68f0 else 'int';assert (entry['kind'],entry['table'],entry['row'],entry['column'])==(kind,names[x],signed(y),text(z))
   if kind=='string':string(q,entry['value'])
   else:m.wi(q,entry['value'])
   m.finish(entry['status'])
  else:
   if a==0x1402b31e0:assert (entry['kind'],entry['name'])==('table',text(y))
   else:assert (entry['kind'],entry['id'])==('cost',y&255)
   m.finish(tables[entry['result']['name']] if entry['result'] else 0)
  return
 if a in [0x140c10324,0x140c10368]:buf=m.heap+cursor;cursor+=(x+16)&~15;m.finish(buf)
 elif a==0x1404233d0:m.finish(effect)
 elif a==0x140425290:values[:]=[-1]*y;m.finish()
 elif a==0x140425110:trace.append(['creator',signed(y)]);m.finish()
 elif a==0x140425210:values[y]=signed(z);m.finish()
 elif a==0x140423fc0:m.finish(values[y]&0xffffffff)
 elif a==0x140286110:m.wi(y,case['args'][popped]);popped+=1;m.finish(1)
 elif a in [0x1401a68f0,0x1401a7010]:
  table=names[x];column=text(z);status,value=query(table,column,a==0x1401a68f0);trace.append(['string' if a==0x1401a68f0 else 'int',table,signed(y),column,status,value])
  if a==0x1401a68f0:string(q,value)
  else:m.wi(q,value)
  m.finish(status)
 elif a==0x1402b31e0:
  name=text(y);available=name in tables and name not in case.get('missing',[]);trace.append(['table',name,bool(available)]);m.finish(tables[name] if available else 0)
 elif a==0x1402b38a0:available='cost' not in case.get('missing',[]);trace.append(['cost',y&255,bool(available)]);m.finish(tables['cost'] if available else 0)
 elif a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('ascii'));m.finish(x)
 elif a==0x140286330:pushed=True;m.finish(1)
 elif a in [0x140423770,0x140c10360,0x140c10370]:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not 0x1405338c0<=a<0x140534ae3:raise RuntimeError(f'Unmapped item-property factory dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,trace,values,cursor,popped,pushed,replayIndex
 case=c;trace=[];values=[];cursor=0x10000;popped=0;pushed=False;replayIndex=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,twodas);m.wq(twodas+0x168,tables['definition']);m.wi(command+0xc,c.get('creator',99))
 for name,ptr in tables.items():m.wi(ptr+0x50,c.get('counts',{}).get(name,16))
 for entry in c.get('replay',[]):
  result=entry.get('result')
  if result:m.wi(tables[result['name']]+0x50,result['count'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,c['ordinal'],len(c['args'])]):u.reg_write(reg,value)
 try:u.emu_start(0x1405338c0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and pushed
 if 'replay'in case:assert replayIndex==len(case['replay'])
 return dict(case=c,result=signed(u.reg_read(UC_X86_REG_RAX)),type=int.from_bytes(u.mem_read(effect+8,2),'little'),durationType=int.from_bytes(u.mem_read(effect+10,2),'little'),integers=values,trace=trace)
if __name__=='__main__':
 rows=[];ordinals=[*range(616,689),733,739,758,845,846,847,954,615,955]
 for ordinal,value in itertools.product(ordinals,[0,1,3,5,17,25,-1,100]):rows.append(run(dict(ordinal=ordinal,args=[value]*6)))
 for ordinal,index in itertools.product(ordinals,range(6)):
  args=[3]*6;args[index]=-1;rows.append(run(dict(ordinal=ordinal,args=args)))
 variants=[dict(missing=['subtype']),dict(missing=['cost']),dict(missing=['IPRP_PARAMTABLE']),dict(missing=['param']),dict(counts={'subtype':2}),dict(counts={'cost':2}),dict(counts={'param':2}),dict(queries={'subtype':{'Name':[0,7]}}),dict(queries={'cost':{'Name':[1,0]}}),dict(queries={'definition':{'CostTableResRef':[0,-1]}}),dict(queries={'definition':{'Param1ResRef':[0,-1]}}),dict(queries={'definition':{'SubTypeResRef':[0,'']}})]
 for ordinal,variant in itertools.product([616,617,632,655,658,676,688,733,954],variants):rows.append(run(dict(ordinal=ordinal,args=[3,1,2,0,0,0],**variant)))
 for args in [[48,-1,1,-1],[48,1,-1,-1],[48,1,1,-1],[48,-1,-1,-1],[48,1,1,1],[48,-2,1,1]]:rows.append(run(dict(ordinal=954,args=args)))
 out=m.root/'backups/animations/native-item-property-factory-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
