"""Original SetAreaTransitionBMP203 wrapper and C2DA string lookup, plus
bounded module entry-coordinate and ARE loading-screen read blocks. Valid
typed GFF/VM reads and string memory/case comparison are captured boundaries.
No whole module/area load or VM type-error coverage is claimed.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
client,command,module,area,info,table,columns,rowPointers,output,app,query=[m.heap+i*0x1000 for i in range(11)]
def string(ptr,value):
 global cursor
 data=value.encode('ascii');p=m.heap+cursor;cursor+=max(16,len(data)+1);u.mem_write(p,data+b'\0');m.wq(ptr,p);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1)
def text(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode('ascii') if m.q(ptr) else ''
def hook(u,a,n,_):
 if a in [m.stop,0x1404809e9,0x1403604fb]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140286110:m.wi(y,c['index']);m.finish(1)
 elif a==0x1402861b0:string(y,c['text']);m.finish(1)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(client if c['client'] else 0)
 elif a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('ascii'));m.finish(x)
 elif a==0x140c10370:m.finish()
 elif a==0x14016ae00:m.finish(int(text(x).lower()==text(y).lower()))
 elif a==0x1401a1650:
  label=bytes(u.mem_read(z,32)).split(b'\0')[0].decode('ascii');value=c['fields'].get(label);m.wi(w,int(value is not None));u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',0 if value is None else value),'little'));m.finish()
 elif a==0x1401a1950:m.wi(w,1);m.finish((c['screen'] or 0)&65535)
 elif not any(lo<=a<hi for lo,hi in [(0x14053df30,0x14053dffa),(0x1404be490,0x1404be4fc),(0x140480962,0x1404809e9),(0x1403604d4,0x1403604fb),(0x1401a68f0,0x1401a69da)]):raise RuntimeError(f'Unmapped area input dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor
 c=case;calls=[];cursor=0x30000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(module+0x108,info);m.wi(client+0x20,27);string(client+0x28,'custom')
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp-0x100);u.reg_write(UC_X86_REG_RCX,command);m.wi(command+12,c.get('self',99))
 operation=c['operation'];start={'script':0x14053df30,'entry':0x140480962,'screen':0x1403604d4,'string':0x1401a68f0}[operation]
 if operation=='entry':u.reg_write(UC_X86_REG_R14,module);u.reg_write(UC_X86_REG_XMM6,0)
 elif operation=='screen':u.reg_write(UC_X86_REG_RSI,area);u.reg_write(UC_X86_REG_R12,0)
 elif operation=='string':
  m.wq(table+0x40,columns);m.wq(table+0x48,rowPointers);m.wi(table+0x50,len(c['cells']));m.wi(table+0x54,len(c['columns']));string(table+0x28,c['default']);string(query,c['column']);string(output,'previous')
  for i,name in enumerate(c['columns']):string(columns+i*16,name)
  for i,row in enumerate(c['cells']):
   ptr=m.heap+0x10000+i*0x1000;m.wq(rowPointers+i*8,ptr)
   for j,value in enumerate(row):string(ptr+j*16,value)
  for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[table,c['row']&0xffffffff,query,output]):u.reg_write(reg,value)
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x1404809e9,0x1403604fb]
 if operation=='script':return dict(case=c,calls=calls,bmp=m.si(client+0x20),user=text(client+0x28))
 if operation=='entry':return dict(case=c,fields=[m.rf(info+0x14+i*4)for i in range(3)])
 if operation=='screen':return dict(case=c,screen=int.from_bytes(u.mem_read(area+0x350,2),'little'))
 return dict(case=c,status=u.reg_read(UC_X86_REG_RAX)&0xffffffff,value=text(output))
rows=[run(dict(operation='script',self=self,client=client_,index=index,text=value))for self,client_,index,value in itertools.product([99,0x80000001,0xffffffff],[False,True],[-1,0,1,2,65535,2147483647,4294967297],['','custom'])]
rows += [run(dict(operation='entry',fields=dict(zip(['Mod_Entry_X','Mod_Entry_Y','Mod_Entry_Z'],values))))for values in itertools.product([None,0,1.1,-2.2,2147483648],repeat=3)]
rows += [run(dict(operation='screen',screen=value))for value in [None,0,1,2,65535,65536,-1]]
rows += [run(dict(operation='string',columns=['TileSet','TILESET','Name'],cells=[['tni01','wrong','label'],['','ignored',''],[' ','other','x']],row=row,column=column,default=default))for row,column,default in itertools.product([-1,0,1,2,3],['TileSet','tileset','Missing','Name'],['','DEFAULT'])]
out=m.root/'backups/animations/native-area-message-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
