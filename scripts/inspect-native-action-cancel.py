"""Read-only CancelAction and reverse AQ enum. Native traversal/gates execute
unchanged; special list, linked-list storage, ClearAction and disposal helpers
are captured. Reverse mapping executes exhaustively across every ushort.
"""
import importlib.util,itertools,json,re,hashlib,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,listOwner,nodes,actions,vtable=[m.heap+n*0x1000 for n in range(5)];virtual=m.stop+0x100;ranges=[]
for file in ['live-native-cancel-action-full-asm.txt','live-native-aq-reverse-map-asm.txt']:
    content=(m.root/'backups/animations'/file).read_text().replace(', \n',', ')
    for line in content.splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140376300:calls.append(['specialCount']);finish(len(specials))
    elif a==0x140376440:calls.append(['specialType',y]);finish(specials[y]&65535)
    elif a==0x140376570:calls.append(['specialId',y]);finish(sequences[y]&65535)
    elif a==0x140378dc0:calls.append(['removeSpecial',y]);specials.pop(y);sequences.pop(y);finish()
    elif a==0x140169110:
        index=(q(y)-nodes)//32;at=links.index(index)+1;nextIndex=links[at] if at<len(links) else -1;wq(y,nodes+nextIndex*32 if nextIndex>=0 else 0);finish(actions+nextIndex*0x100 if nextIndex>=0 else 0)
    elif a==0x1401690b0:finish(actions+((y-nodes)//32)*0x100)
    elif a==0x140390c10:finish(actions+links[0]*0x100 if links else 0)
    elif a==virtual:
        index=(y-actions)//0x100;calls.append(['clear',index,z]);finish(c['clear'][index])
    elif a==0x1401691f0:
        index=(y-nodes)//32;links.remove(index);wq(listOwner,nodes+links[0]*32 if links else 0);finish(actions+index*0x100)
    elif a==0x14048c470:calls.append(['dispose',(x-actions)//0x100]);finish()
    elif a==0x140c10360:finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped cancellation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,args):
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,v&0xffffffffffffffff)
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def run(case):
    global c,calls,specials,sequences,links
    c=case;calls=[];specials=c['specials'].copy();sequences=c['sequences'].copy();links=list(range(len(c['groups'])));u.mem_write(m.heap,bytes(0x100000));wq(actor,vtable);wq(vtable+0xf0,virtual);wq(actor+0x100,listOwner);wq(listOwner,nodes if links else 0)
    for n,group in enumerate(c['groups']):wq(nodes+n*32+0x10,actions+n*0x100);u.mem_write(actions+n*0x100+0x98,struct.pack('<H',group&65535))
    try:result=invoke(0x140386700,[actor,c['code'],c['group']])
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    return dict(case=c,result=result,calls=calls,specials=specials,sequences=sequences,remaining=links)
default=dict(code=3,group=7,groups=[7,8,7,7],clear=[1,1,1,1],specials=[],sequences=[])
rows=[run(default|dict(code=code,group=group,clear=clear,specials=specials,sequences=list(range(7,7+len(specials))))) for code,group,clear,specials in itertools.product([3,20,27,34,65535],[7,8,9,65543],[[1,1,1,1],[0,1,0,1],[2,1,2,0]],[[],[0,9,9],[204,899,12],[65000,65001]])]
values=[];mapping={}
for code in range(65536):
    value=invoke(0x1404abb10,[actor,code]);values.append(value&65535)
    if value!=65535:mapping[str(code)]=value
out=m.root/'backups/animations/native-action-cancel-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,mapSha256=hashlib.sha256(struct.pack('<65536H',*values)).hexdigest(),mapping=mapping),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),mappedInputs=65536)))
