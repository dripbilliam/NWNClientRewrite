"""Whole original click-cancel sender7bf390, real native WORD codecs and
whole server input4531b0 subtype20. Synthetic controlled-creature lookup and
CancelAction boundary capture: no live AI, transport or GUI invocation.
"""
import sys,json,itertools
from pathlib import Path
limits=__doc__
sys.path.insert(0,str(Path(__file__).resolve().parent))
base=Path(__file__).with_name('inspect-native-network-interactions.py').read_text()
setup=base[:base.index('\nrows=[]')].replace('u.hook_add(UC_HOOK_CODE,hook)','base_handle=u.hook_add(UC_HOOK_CODE,hook)')
exec(compile(setup,str(Path(__file__).with_name('inspect-native-network-interactions.py')),'exec'))
u.hook_del(base_handle);old_hook=hook;ranges.append((0x1407bf390,0x1407bf437));senders['cancel']=('queue-cancel-client-sender',0x1407bf390,20)

def cancel_hook(u,a,n,data):
 if a==0x140386700:
  calls.append(['cancel',u.reg_read(UC_X86_REG_RDX)&65535,u.reg_read(UC_X86_REG_R8)&65535]);m.finish();return
 old_hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,cancel_hook)
rows=[]
for fmt,action,group in itertools.product([0,1],[0,2,4,12,19,65535],[0,1,321,65535]):
 c=dict(format=fmt,kind='cancel',actionId=action,groupId=group)
 for guards in [{},{'noActor':True},{'commandable':0}]:
  current={**c,**guards};calls=[];sent=[];t.reset(dict(format=fmt));w.call(0x1407bf390,[w.message,action,group]);assert len(sent)==1
  packet=sent[0];decoded=receive(packet,current)
  assert decoded['calls']==([]if guards else[['cancel',action,group]]),(current,decoded)
  rows.append(dict(case=dict(current),packet=packet.hex(),decoded=decoded))
out=m.root/'backups/animations/native-network-action-cancel.json';out.write_text(json.dumps(dict(target=m.digest,limits=limits,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
