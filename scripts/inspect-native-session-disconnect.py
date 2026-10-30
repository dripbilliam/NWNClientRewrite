"""Execute complete CNetLayerInternal::DisconnectFromSession140239f60..14023a016.
SendBNDM, interface notification, window shutdown and Steam/GOG presence calls
are explicit lower providers. Covers eligibility, post-send recheck, ordering
and index invalidation, not actual socket/crypto/window destruction or UI.
Read-only hash-gated original code; no live process/original file modification.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner=0x500000000;u.mem_map(owner,0x28a7000)
interface,vt,steam,gog=[m.heap+i*0x1000 for i in range(1,5)]
image_invalid_word=m.si(0x1412902e8)&0xffffffff
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x1402505b0:
  assert x==owner;calls.append(['send-bndm',y&0xffffffff])
  if case['mutation']=='index':m.wi(owner+0x28a56d8,-1)
  elif case['mutation']=='active':m.wi(owner+0x28a5698,0)
  m.finish()
 elif a==m.stop+0x10:assert x==interface and y==0;calls.append(['interface',0]);m.finish()
 elif a==0x140254b40:
  assert x==owner+0x68+case['index']*0x960;calls.append(['window-shutdown',case['index']]);m.finish()
 elif a==0x140204410:
  assert x==steam;calls.append(['steam-connected']);m.finish(case['presence']in['steam-connected','both'])
 elif a==0x140204210:assert x==steam;calls.append(['steam-clear']);m.finish()
 elif a==0x14020b8c0:assert x==gog;calls.append(['gog-clear']);m.finish()
 elif not 0x140239f60<=a<=0x14023a016:raise AssertionError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for index,active,mutation,presence,invalid_word in itertools.product([-1,0,2],[0,1],['none','index','active'],['none','steam-connected','steam-offline','gog','both'],sorted({image_invalid_word,4294967295,7})):
 case=dict(index=index,active=active,mutation=mutation,presence=presence,invalidWord=invalid_word);calls=[]
 m.wi(0x1412902e8,invalid_word)
 u.mem_write(m.stack,bytes(0x20000));m.wi(owner+0x28a56d8,index);m.wi(owner+0x28a5698,active);m.wq(owner+0x50,interface);m.wq(interface,vt);m.wq(vt+0x80,m.stop+0x10)
 m.wq(0x1412df900,steam if presence in['steam-connected','steam-offline','both']else 0);m.wq(0x1412df908,gog if presence in['gog','both']else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,owner)
 u.emu_start(0x140239f60,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 eligible=index!=-1 and active!=0;expected=[];next_index=index;next_active=active
 if eligible:
  expected.append(['send-bndm',invalid_word])
  if mutation=='none':expected.extend([['interface',0],['window-shutdown',index]]);next_index=-1
  elif mutation=='index':next_index=-1
  else:next_active=0
  if presence in['steam-connected','steam-offline','both']:expected.append(['steam-connected'])
  if presence in['steam-connected','both']:expected.append(['steam-clear'])
  if presence in['gog','both']:expected.append(['gog-clear'])
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 assert calls==expected and result==int(eligible) and m.si(owner+0x28a56d8)==next_index and m.si(owner+0x28a5698)==next_active
 rows.append(dict(case=case,calls=calls,result=result,index=m.si(owner+0x28a56d8),active=m.si(owner+0x28a5698)))
out=m.root/'backups/animations/native-session-disconnect-v1.json'
if out.exists():raise FileExistsError(out)
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,imageInvalidWord=image_invalid_word,invalidWordScope='Original PE initializer plus explicit synthetic globals; startup initialization not executed, no runtime INVALID value or packet payload semantics claim.',rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),imageInvalidWord=image_invalid_word)))
