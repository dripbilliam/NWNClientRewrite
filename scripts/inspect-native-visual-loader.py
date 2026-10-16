"""Complete unchanged LoadVisualEffect14096cf10..14096ed64 with explicit
synthetic client/model/table/settings, string/heap and empty-controller-map
copy/destruction boundaries. Produces model/program/anchor metadata only;
no installed assets. Does not prove lower controller import or rendering.
"""
import importlib,json,struct,itertools
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,app,rules,settings,client,render,host,vt,point,inputmap,desthead,srchead,creature,stats=[m.heap+n*0x1000 for n in range(15)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def cs(ptr):return string(m.q(ptr))
def allocate(size):
 global allocation
 ptr=m.heap+0x80000+allocation*0x200;allocation+=1;return ptr
def writecs(ptr,value):
 data=value.encode()+b'\0';dst=allocate(len(data));u.mem_write(dst,data);m.wq(ptr,dst);m.wi(ptr+8,len(data)-1);m.wi(ptr+12,len(data))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10370,0x140c10360,0x140369220,0x140369860]:m.finish()
 elif a==0x140c10368:m.finish(allocate(x))
 elif a==0x14003d8c0:
  value=string(y);count=z&0xffffffff;writecs(x,value if count==0xffffffff else value[:count]);m.finish(x)
 elif a==0x1401881e0:writecs(x,cs(y));m.finish(x)
 elif a==0x14016ab00:writecs(y,cs(x)+cs(z));m.finish(y)
 elif a==0x14016afb0:writecs(x,string(y).replace('%d',str(z&0xffffffff)));m.finish(x)
 elif a==0x1403594d0:assert y==srchead and z==desthead;m.finish(desthead)
 elif a==0x1406abb60:calls.append(['client',y&0xffffffff]);m.finish(client if y==123 and c['client']or y==789 and c['source']else 0)
 elif a==0x1406ab9b0:calls.append(['settings']);m.finish(settings)
 elif a==0x1401a68f0:
  column=cs(z);row=c['strings']if y==c['visual']else c['alternateStrings']if y==789 else{};value=row.get(column,'');calls.append(['string',y&0xffffffff,column]);writecs(w,value);m.finish(int(value!=''))
 elif a==0x1401a7010:
  column=cs(z);row=({'SIZECATEGORY':c['size']}if c['sizeFound']else{})if x==rules+0x700 else c['ints']if y==c['visual']else{};found=column in row;value=row.get(column,0);calls.append(['integer',y&0xffffffff,column]);m.wi(w,value);m.finish(int(found))
 elif a==0x1400931f0:
  name,alias=string(x),string(y);calls.append(['load',name,alias,z&0xffffffff]);ptr=m.heap+0x20000+len(loaded)*0x1000;loaded[ptr]=dict(name=name,alias=alias);m.wq(ptr,vt);m.finish(0 if alias in c['failModels']else ptr)
 elif a==0x140115890:calls.append(['warning',m.si(u.reg_read(UC_X86_REG_RSP)+0x28),string(m.q(u.reg_read(UC_X86_REG_RSP)+0x38))]);m.finish()
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a in [m.stop+0x20,m.stop+0x30,m.stop+0x40]:
  calls.append(['view',{m.stop+0x20:0xa0,m.stop+0x30:0x28,m.stop+0x40:0x58}[a]]);m.finish(creature if a==m.stop+0x40 and c['creature']else client+0x100 if a==m.stop+0x20 and c['first']else client+0x500 if a==m.stop+0x30 and c['second']else 0)
 elif a==m.stop+0x50:calls.append(['modelHandle',y&255,z&0xffffffff]);m.finish(host if c['host']else 0)
 elif a==m.stop+0x60:calls.append(['node',string(y)]);m.finish(host if c['anchor']else 0)
 elif a==m.stop+0x70:calls.append(['modelSetting',loaded[x]['alias'],y&0xffffffff]);m.finish()
 elif not 0x14096cf10<=a<0x14096ed64:raise RuntimeError(f'Unexpected native visual loader dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,loaded,allocation
 c=case;calls=[];loaded={};allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x280,rules+0x500);m.wi(settings+0x64,c['quality']);u.mem_write(settings+0x40,bytes([c['violence']]));m.wq(client,vt);m.wq(render,vt);m.wq(host,vt)
 m.wq(rules+0x100,rules+0x700);m.wq(creature+0x300,stats);u.mem_write(stats+0xcc,struct.pack('<H',42))
 writecs(client+0x100+0x1e0,'plc');writecs(client+0x500+0x1c8,'door')
 for off,target in [(0x18,0x10),(0xa0,0x20),(0x28,0x30),(0x58,0x40),(0x140,0x50),(0x230,0x60),(0x1a0,0x70)]:m.wq(vt+off,m.stop+target)
 for header in [desthead,srchead]:
  for off in [0,8,16]:m.wq(header+off,header)
  u.mem_write(header+0x19,b'\1')
 m.wq(effect+0x128,desthead);m.wq(inputmap,srchead)
 for i,v in enumerate([1.25,-2,3.5]):m.wf(point+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c['visual']);u.reg_write(UC_X86_REG_R8,c['instant']);u.reg_write(UC_X86_REG_R9,123);m.wi(rsp+0x28,789 if c['source']else 0x7f000000);m.wi(rsp+0x30,c['sourcePart']);m.wi(rsp+0x38,c['targetPart']);m.wq(rsp+0x40,point);m.wq(rsp+0x48,inputmap)
 try:u.emu_start(0x14096cf10,m.stop,count=300000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,models=[loaded.get(m.q(effect+0x88+i*8))for i in range(3)],programs=[int.from_bytes(u.mem_read(effect+0xd0+i*2,2),'little')for i in range(3)],anchors=[cs(effect+0x28),cs(effect+0x38)],orient=m.si(effect+0x120),duration=u.mem_read(effect+0xfc,1)[0],remaining=m.si(effect+0xcc),closed=m.si(effect+0xec),retired=[m.si(effect+0xdc+i*4)for i in range(3)])
def profile(**kw):
 c=dict(strings={'Imp_HeadCon_Node':'head_fx'},ints={'OrientWithObject':0},alternateStrings={},quality=1,violence=2,instant=0,anchor=1,client=1,source=0,creature=0,size=3,sizeFound=1,visual=456,render=1,host=1,first=0,second=0,sourcePart=0,targetPart=0,failModels=[]);c.update(kw);return c
rows=[run(profile(strings=strings,ints={'OrientWithObject':orient,**programs},quality=quality,violence=violence,instant=instant,anchor=anchor))for strings,programs,quality,violence,orient,instant,anchor in itertools.product([{}, {'Imp_HeadCon_Node':'head_fx'},{'Imp_HeadCon_Node':'head_fx','Imp_Impact_Node':'impact_fx','Imp_Root_M_Node':'ground_fx'}],[{}, {'ProgFX_Impact':10},{'ProgFX_Duration':20},{'ProgFX_Cessation':30}],[0,1],[1,2],[0,1],[0,1],[0,1])]
rows.extend(run(profile(**kw))for kw in [dict(client=0),dict(ints={}),dict(strings={'Imp_HeadCon_Node':'head_fx','LowQuality':'low_fx'},quality=0),dict(strings={'Imp_HeadCon_Node':'head_fx','LowQuality':'low_fx'},quality=1),dict(ints={'LowViolence':789},violence=1,alternateStrings={'Imp_HeadCon_Node':'lv_head','Imp_Impact_Node':'lv_imp','Imp_Root_M_Node':'lv_ground'}),dict(ints={'LowViolence':789},violence=2,alternateStrings={'Imp_HeadCon_Node':'lv_head','Imp_Impact_Node':'lv_imp','Imp_Root_M_Node':'lv_ground'}),dict(ints={'ProgFX_Impact':0,'ProgFX_Duration':20,'ProgFX_Cessation':30}),dict(ints={'OrientWithObject':-1})])
rows.extend(run(profile(**kw))for kw in [dict(source=1),dict(source=1,anchor=0),dict(source=1,instant=1),dict(strings={'Imp_HeadCon_Node':'head_fx','Imp_Impact_Node':'impact_fx','Imp_Root_M_Node':'ground_fx','LowQuality':'low_fx'},quality=0),dict(strings={'Imp_HeadCon_Node':'head_fx','Imp_Impact_Node':'impact_fx','Imp_Root_M_Node':'ground_fx'},ints={'LowViolence':789},violence=1,alternateStrings={'Imp_HeadCon_Node':'lv_head','Imp_Impact_Node':'lv_imp','Imp_Root_M_Node':'lv_ground'})])
rows.extend(run(profile(creature=1,size=size,sizeFound=found,strings=strings))for size,found,strings in itertools.product([-1,0,1,3,4,5,6],[0,1],[{'Imp_HeadCon_Node':'head_fx','Imp_Root_S_Node':'small_fx'},{'Imp_HeadCon_Node':'head_fx','Imp_Root_M_Node':'medium_fx','Imp_Root_L_Node':'large_fx','Imp_Root_H_Node':'huge_fx'},{'Imp_Root_M_Node':'medium_fx','Imp_Root_L_Node':'large_fx'},{'Imp_Root_M_Node':'medium_fx'}]))
rows.extend(run(profile(source=1,first=first,second=second,sourcePart=sourcePart,targetPart=targetPart,anchor=anchor))for first,second,sourcePart,targetPart,anchor in itertools.product([0,1],[0,1],[0,1,2,11,12,255],[0,1,2,11,12,255],[0,1]))
rows.extend(run(profile(creature=1,size=size,strings={'Imp_HeadCon_Node':'head_fx','Imp_Impact_Node':'impact_fx','Imp_Root_M_Node':'medium_fx','Imp_Root_L_Node':'large_fx','Imp_Root_H_Node':'huge_fx'},ints={'LowViolence':789},violence=1,alternateStrings=alt))for size,alt in itertools.product([0,1,3,4,5,6],[{}, {'Imp_Root_M_Node':'lv_m'}, {'Imp_Root_H_Node':'lv_h','Imp_Root_L_Node':'lv_l','Imp_Root_M_Node':'lv_m'}]))
rows.extend(run(profile(**kw))for kw in [dict(render=0),dict(host=0),dict(visual=999),dict(visual=999,strings={'Imp_Root_M_Node':'root_fx'})])
rows.extend(run(profile(strings={'Imp_HeadCon_Node':'head_fx','Imp_Impact_Node':'impact_fx','Imp_Root_M_Node':'root_fx'},failModels=names))for names in [['fxground'],['fximpact'],['fxhead'],['fxground','fximpact','fxhead']])
out=m.root/'backups/animations/native-visual-loader-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
