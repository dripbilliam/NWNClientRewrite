"""Execute original Alignment bind/select/recommend/title/OK/Cancel and class restrictions.
Original SelectTab/SetChecked and GetIsAlignmentAllowed execute unchanged.
Layout import, GUI color/text/update delivery, tab-array insertion, enabled-state
delivery, ruleset lookup, object lookup and modal lifetime are explicit providers.
Raw class/creature fixtures are not a catalog loader, pixels, level-up or save oracle.
"""
import importlib.util,itertools,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,creature,stats,vtable,rules,classes,array=[m.heap+n for n in[0x1000,0x5000,0x9000,0xd000,0x10000,0x20000,0x40000]]
offsets=[0xb68,0xc30,0xcf8,0x910,0x9d8,0xaa0,0xdc0,0xe88,0xf50]
ranges=[(0x1408eade0,0x1408eb474),(0x1408e5e20,0x1408e5f53),(0x1408e1310,0x1408e1370),(0x1408e3560,0x1408e3645),(0x1408e1040,0x1408e1070),(0x1408e2b20,0x1408e2b8e),(0x1408e32c0,0x1408e32f0),(0x1401eff30,0x1401eff8c),(0x1401e5ae0,0x1401e5b38),(0x140299900,0x1402999e9),(0x1407f0f60,0x1407f0fc6)]
def word(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def byte(a,v):u.mem_write(a,bytes([v&255]))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140800c90:m.finish(creature if present else 0)
 elif a in [0x1401fe0b0,0x1401fb540,0x1401eb5c0,0x1401ec1b0,0x140c10370,m.stop+0x10]:m.finish()
 elif a==0x1401ed880:
  count=m.si(x+0x20);m.wq(x+0x18,array);m.wq(array+count*8,y);m.wi(x+0x20,count+1);m.finish()
 elif a==0x1401fb890:texts[hex(x-panel)]=y&0xffffffff;m.finish()
 elif a in [0x1401e5c60,0x1401eb800]:enabled[hex(x-panel)]=bool(y);m.finish()
 elif a==0x1402ae870:m.finish(1)
 elif a==0x1402a4130:m.finish(case.get('recommended',1))
 elif a==0x1401fc440:codes.append(y&0xffffffff);m.finish()
 elif not any(lo<=a<=hi for lo,hi in ranges):raise AssertionError(f'Unmapped original Alignment dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)
def clear():
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(panel,vtable);m.wq(vtable,m.stop+0x10);m.wq(creature+0x3b0,stats);m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes)
def allowed(mask,axes,invert,good,law):
 clear();byte(classes+0x4a1,mask);byte(classes+0x4a2,axes);m.wi(classes+0x4a4,invert)
 return dict(input=dict(mask=mask,axes=axes,invert=invert,good=good,law=law),result=call(0x140299900,[classes,good,law]))
def snapshot():
 return dict(selected=m.si(panel+0x1030),help=dict(texts),goodEvil=int.from_bytes(u.mem_read(stats+0xc6,2),'little'),lawChaos=int.from_bytes(u.mem_read(stats+0xc8,2),'little'),enabled=[enabled.get(hex(panel_offset),False)for panel_offset in offsets],recommendEnabled=enabled.get('0x828',False))
def run(c):
 global case,present,texts,enabled,codes
 case=c;present=True;texts={};enabled={};codes=[];clear()
 byte(stats+0x69,1);byte(stats+0x295,c['classId']);byte(stats+0x296,1);m.wi(panel+0x1018,42);m.wi(panel+0x1030,-1);word(stats+0xc6,c['goodEvil']);word(stats+0xc8,c['lawChaos'])
 row=classes+c['classId']*0x530;byte(row+0x4a1,c['mask']);byte(row+0x4a2,c['axes']);m.wi(row+0x4a4,c['invert'])
 call(0x1408eade0,[panel]);initial=snapshot()
 if c['title']:call(0x1408e2b20,[panel])
 titled=snapshot()
 if c['recommend']:call(0x1408e5e20,[panel])
 else:
  m.wi(panel+0x1030,c['selected']);call(0x1401eff30,[panel+0x1020,c['selected']])
  call(0x1408e1310,[panel,c['selected']])
 selected=snapshot();present=c['present']
 call(0x1408e1040 if c['cancel']else 0x1408e3560,[panel]);assert len(codes)==1
 return dict(input=c,initial=initial,titled=titled,selection=selected,output=dict(goodEvil=int.from_bytes(u.mem_read(stats+0xc6,2),'little'),lawChaos=int.from_bytes(u.mem_read(stats+0xc8,2),'little'),code=codes[0]))
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-alignment-observations-v1.json';assert not out.exists(),'Preserve previous evidence'
 restrictions=[allowed(*args)for args in itertools.product(range(32),range(4),[0,1],[1,4,5],[1,2,3])]
 rng=random.Random(65231);cases=[]
 for index in range(180):
  cases.append(dict(classId=([*range(15),37][index%16]),mask=rng.choice([0,1,2,4,8,16,21,31,255]),axes=rng.choice([0,1,2,3,255]),invert=rng.choice([0,1,-1]),goodEvil=[0,30,31,69,70,100,65535][index%7],lawChaos=[0,30,31,69,70,100,65535][index//7%7],recommended=index%2,title=index%3==0,recommend=index%3==1,selected=index%10-1,present=index%4!=0,cancel=index%5==0))
 rows=[run(c)for c in cases]
 out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,restrictions=restrictions,rows=rows,procedures=['0x140299900','0x1408eade0','0x1408e5e20','0x1408e1310','0x1408e3560','0x1408e1040','0x1408e2b20','0x1401eff30','0x1401e5ae0']),indent=2));print(json.dumps(dict(output=str(out),restrictions=len(restrictions),cases=len(rows))))

