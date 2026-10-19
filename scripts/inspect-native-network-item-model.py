"""Original item naming29dd90/29dc80 and complete CreateItem769130 routing.

Original model-type branches, names, resource probes, fallback selection and
armor AC thresholds execute. Native item/icon construction, body load/play,
2DA getters, formatting, visual transforms and effects are captured lower
boundaries. No GPU, live process changes, copied game assets or complete item
material/pose claim. Resource availability is an explicit synthetic fixture.
"""
import sys,importlib,json,itertools,struct,re,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['network-baseitem-model-resref','network-baseitem-icon-resref']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['raw_result']['value']['procedure'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
d=json.loads((m.root/'backups/animations/rea-network-item-model-construction-procedure.json').read_text())['structuredContent']['normalized_result']['item'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
base,parts,colors,partColors,rules,vt,out=[m.heap+n*0x1000 for n in range(10,17)]
def cstr(ptr):
 raw=bytearray()
 for i in range(4096):
  b=u.mem_read(ptr+i,1)[0]
  if b==0:return raw.decode('latin1')
  raw.append(b)
 raise AssertionError('Unbounded native fixture string')
def string(ptr,value):
 global stringCursor
 raw=value.encode('latin1');p=m.heap+stringCursor;stringCursor+=len(raw)+32;u.mem_write(p,raw+b'\0');m.wq(ptr,p);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1)
def formatter(fmt,values):
 index=0
 def sub(match):
  nonlocal index
  token=match.group(0);v=values[index];index+=1
  if token.endswith('s'):return cstr(v)if v else'(null)'
  if token.endswith('c'):return chr(v&255)
  value=v&0xffffffff
  if token.endswith('d')and value>=0x80000000:value-=0x100000000
  width=int(token[1:-1]or'0');return str(value).zfill(width)
 return re.sub(r'%0?\d*[scdu]',sub,fmt)
def hook(u,a,n,data):
 global instance
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140047000,0x14016afb0]:
  value=formatter(cstr(y),[z,k]+[m.q(sp+0x28+i*8)for i in range(10)])
  if a==0x140047000:u.mem_write(x,value.encode('latin1')+b'\0')
  else:string(x,value)
  m.finish(len(value));return
 if a==0x14029ca00:m.finish(base);return
 if a==0x14083c480:
  instance=x;u.mem_write(x,bytes(0x2b8));m.wi(x+0x40,y);m.wq(x+0x48,vt);m.wq(vt+0xf0,m.stop+0x10);m.wq(vt+0x170,m.stop+0x20);m.finish(x);return
 if a==m.stop+0x10:loads.append(dict(model=cstr(y),selector=z&255));m.finish(int(not c.get('bodyFailure')));return
 if a==m.stop+0x20:plays.append(cstr(k));m.finish(1);return
 if a==0x14018f590:
  name=cstr(y);exists=not(c.get('missingModels')and z==2002 and name!=c['defaultModel']);exists=exists and not(c.get('missingDefault')and z==2002 and name==c['defaultModel']);probes.append(dict(name=name,type=z,exists=bool(exists)));m.finish(int(exists));return
 if a in [0x1401e2ca0,0x1401e2e40,0x1401e3000]:u.mem_write(x,bytes(0x70));m.finish(x);return
 if a==0x1401e30f0:u.mem_write(x,bytes(17));m.finish(x);return
 if a in [0x1407b93a0,0x14076b6e0,0x1402a0ff0,0x140766960,0x14083e040]:m.finish(1);return
 if a==0x1401a68f0:string(k,'fixture');m.finish(1);return
 if a==0x1401a7010:m.wi(k,0);m.finish(1);return
 if a==0x1401a6c70:m.wf(k,c['ac']);m.finish(1);return
 if a in [0x140c7ed44,0x140c7fef0]:
  v=struct.unpack('<f',int(u.reg_read(UC_X86_REG_XMM0)&0xffffffff).to_bytes(4,'little'))[0];result=math.floor(v)if a==0x140c7ed44 else math.ceil(v);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',result),'little'));m.finish();return
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if a==0x140115890:diagnostics.append(dict(kind='native-warning'));m.finish();return
 if a in [0x14018de80,0x14018dea0]:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a in [0x14029dd90,0x14029dc80]:nameCalls.append(dict(kind='model'if a==0x14029dd90 else'icon',part=z&255,number=k&65535,variant=u.mem_read(sp+0x28,1)[0]))
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def setup(case):
 global c,stringCursor,probes,loads,plays,diagnostics,instance,nameCalls
 c=case;stringCursor=0xc0000;probes=[];loads=[];plays=[];diagnostics=[];instance=0;nameCalls=[];t.reset(dict(format=1));u.mem_write(base+0x16,bytes([c['modelType']]));u.mem_write(base+0x40,c['prefix'].encode()+b'\0');u.mem_write(base+0x58,b'iit_bag\0');u.mem_write(base+0x69,c['defaultModel'].encode()+b'\0');m.wi(base+0x84,c.get('variantFlag',0));m.wq(0x1412df8f8,rules);m.wq(rules+0x20,base);m.wq(rules+0x130,rules)
names=[]
for modelType,part,number,variantFlag,variant in itertools.product([0,1,2],[0,1,2],[0,1,255,256,32767,32768,65535],[0,1],[0,70]):
 case=dict(modelType=modelType,part=part,number=number,variantFlag=variantFlag,variant=variant,prefix='WSwDg',defaultModel='it_bag');setup(case);m.wi(m.stack+0x1fe08+0x28,variant);w.call(0x14029dd90,[base,out,part,number]);model=cstr(out);m.wi(m.stack+0x1fe08+0x28,variant);w.call(0x14029dc80,[base,out,part,number]);names.append(dict(case=case,model=model,icon=cstr(out)))
construct=[]
for modelType,baseId,ac,missingModels,missingDefault,bodyFailure in itertools.product([0,1,2,3],[22,80],[0,1.49,1.5,3.49,3.5,5.49,5.5,9],[0,1],[0,1],[0,1]):
 case=dict(modelType=modelType,baseId=baseId,ac=ac,missingModels=missingModels,missingDefault=missingDefault,bodyFailure=bodyFailure,prefix='WSwDg',defaultModel='it_bag');setup(case)
 for i in range(19):u.mem_write(parts+i*2,struct.pack('<H',[12,32,42][i%3]))
 u.mem_write(colors,bytes([1,2,3,4,5,6]));u.mem_write(partColors,bytes([255])*114);sp=m.stack+0x1fe08;m.wq(sp+0x28,partColors);m.wi(sp+0x30,0);m.wi(sp+0x38,77);m.wq(sp+0x40,out)
 result=w.call(0x140769130,[w.message,baseId,parts,colors]);construct.append(dict(case=case,success=bool(result),loads=loads,plays=plays,probes=probes,diagnostics=diagnostics,nameCalls=nameCalls))
output=m.root/'backups/animations/native-network-item-model-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,names=names,construct=construct),indent=2)+'\n');print(json.dumps(dict(names=len(names),construct=len(construct),output=str(output))))
