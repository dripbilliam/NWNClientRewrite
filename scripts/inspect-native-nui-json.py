"""Unchanged original nlohmann UBJSON serializer on synthetic JSON objects.
Output-adapter byte writes and stack cookie are captured boundaries; scalar
encoding, traversal, ordering and recursion execute original code. No assets or
live process writes. Framing tested separately through native message owners.
"""
from pathlib import Path
import importlib,json,struct,sys
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);writer,adapter,vtable,emit,emitBytes=m.heap,m.heap+0x100,m.heap+0x200,m.heap+0xe0000,m.heap+0xe0100
data=json.loads((m.root/'backups/animations/rea-nui-native-binary-writer-v1.json').read_text())['structuredContent']['raw_result']['value'];ranges=[]
for d in [data['procedure'],*data['callees']]:
 if d['address']in ['0x1402e8eb0','0x1402d4270','0x1402d43d0','0x1402e8a40']or d['name'].startswith('nlohmann::basic_json')or d['name'].startswith('std::_Tree'):
  ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['body']['ranges'])
ranges.extend([(0x1402d4270,0x1402d43d0),(0x1402d43d0,0x1402d4830)])
for name in ['rea-nui-native-ubjson-output-helper-v1.json','rea-nui-byte-reverse-v1.json','rea-nui-number-output-v1.json']:
 d=json.loads((m.root/'backups/animations'/name).read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==emit:output.append(u.reg_read(UC_X86_REG_RDX)&255);m.finish();return
 if a==emitBytes:
  ptr=u.reg_read(UC_X86_REG_RDX);size=u.reg_read(UC_X86_REG_R8);assert size<65536;output.extend(u.mem_read(ptr,size));m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError('Unmapped native NUI serializer dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def allocate(n):
 global cursor
 ptr=m.heap+cursor;cursor+=(n+15)&~15;assert cursor<0xc0000;return ptr
def string(s):
 raw=s.encode('utf8');ptr=allocate(32);m.wq(ptr+16,len(raw));m.wq(ptr+24,15 if len(raw)<=15 else len(raw));dest=ptr if len(raw)<=15 else allocate(len(raw)+1)
 if dest!=ptr:m.wq(ptr,dest)
 u.mem_write(dest,raw+b'\0');return ptr
def build(value):
 ptr=allocate(16)
 def tag(n):u.mem_write(ptr,bytes([n]))
 if value is None:tag(0)
 elif isinstance(value,bool):tag(4);m.wq(ptr+8,int(value))
 elif isinstance(value,int):tag(5 if value<0 else 6);m.wq(ptr+8,value&0xffffffffffffffff)
 elif isinstance(value,float):tag(7);u.mem_write(ptr+8,struct.pack('<d',value))
 elif isinstance(value,str):tag(3);m.wq(ptr+8,string(value))
 elif isinstance(value,list):
  tag(2);vec=allocate(24);items=allocate(max(16,len(value)*16));m.wq(ptr+8,vec);m.wq(vec,items);m.wq(vec+8,items+len(value)*16);m.wq(vec+16,items+len(value)*16)
  for i,v in enumerate(value):u.mem_write(items+i*16,bytes(u.mem_read(build(v),16)))
 else:
  tag(1);obj=allocate(16);head=allocate(80);m.wq(ptr+8,obj);m.wq(obj,head);m.wq(obj+8,len(value));u.mem_write(head+25,b'\1');pairs=sorted(value.items());nodes=[allocate(80)for _ in pairs]
  def tree(lo,hi,parent):
   if lo>=hi:return head
   mid=(lo+hi)//2;node=nodes[mid];m.wq(node+8,parent);u.mem_write(node+24,b'\1');key,v=pairs[mid];u.mem_write(node+32,bytes(u.mem_read(string(key),32)));u.mem_write(node+64,bytes(u.mem_read(build(v),16)));m.wq(node,tree(lo,mid,node));m.wq(node+16,tree(mid+1,hi,node));return node
  root=tree(0,len(nodes),head);m.wq(head,nodes[0]if nodes else head);m.wq(head+8,root);m.wq(head+16,nodes[-1]if nodes else head)
 return ptr
def run(value):
 global cursor,output
 cursor=0x1000;output=bytearray();u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(writer,b'\1');m.wq(writer+8,adapter);m.wq(adapter,vtable);m.wq(vtable,emit);m.wq(vtable+8,emitBytes);source=build(value);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,1);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[writer,source,0,0]):u.reg_write(reg,value)
 u.emu_start(0x1402e8eb0,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;return output.hex()
values=[None,True,False,-9223372036854775808,-2147483649,-2147483648,-32769,-32768,-129,-128,-1,0,127,128,255,256,32767,32768,2147483647,2147483648,9223372036854775807,0.0,-0.0,1.0,1.5,123.125,'','☃','A longer UTF-8 string é',[1,2,3],{'version':1,'root':{'type':'row','children':[{'type':'button','id':'next','label':{'bind':'caption'}},{'type':'check','value':True}]}}]
cases=[dict(value=str(v)if isinstance(v,int)and(abs(v)>9007199254740991)else v,integer64=isinstance(v,int)and abs(v)>9007199254740991,wire=run(v))for v in values]
out=m.root/'backups/animations/native-nui-ubjson-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=cases),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),success=True)))
