"""Execute original9945d0/992240/98f7d0 +party count/first/next/index owners.

Pinned PE bytes execute in Unicorn only, with no target process/network/GPU.
Native menu publication/allocation, app/creature/name lookup and shortcut setter
are explicit captured services. Native party array/query state and signed
callback lookup execute unchanged. No service substitutes the menu decision.
"""
from pathlib import Path
import argparse, hashlib, itertools, json
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);args=parser.parse_args()
output=Path(args.report).resolve();assert output.is_relative_to(root) and not output.exists()
fixture=root/'scripts/inspect-native-creature-radial.py';text=fixture.read_text();proof=json.loads((root/'godot-client/reports/native-creature-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
prefix=text.split('\nrows=[]\n')[0]
assert prefix.count('u.hook_add(UC_HOOK_CODE, hook)')==1
prefix=prefix.replace('u.hook_add(UC_HOOK_CODE, hook)','base_hook=u.hook_add(UC_HOOK_CODE, hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_native_command_base'};exec(compile(prefix,str(fixture),'exec'),ns)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=ns['u'];u.hook_del(ns['base_hook']);heap=ns['heap'];menu=ns['menu'];actor=ns['actor'];app=ns['app'];stop=ns['stop'];stack=ns['stack'];wi=ns['wi'];wq=ns['wq'];q=ns['q'];finish=ns['finish'];read_text=ns['text']
party=heap+0x10000;array=heap+0x13000;widget=heap+0xa000
state={};published=[];assignments=[];trace=[];instructions=0
def hook(_u,address,size,_data):
    global instructions
    instructions+=1
    if instructions>200000:raise RuntimeError('Bounded original instruction budget exhausted')
    if address==stop:u.emu_stop();return
    if len(trace)>=64:trace.pop(0)
    trace.append(hex(address))
    x,y,z,w=[u.reg_read(register) for register in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
    if address==0x1406ac1a0:finish(actor);return
    if address==0x1406ac020:finish(party);return
    if address==0x1406ab9e0:finish(state['objects'].get(y&0xffffffff,0));return
    if address==0x14003d790:finish(state['dmExe']);return
    if address==0x1407f3f00:
        target=state['stats'].get(x)
        assert target is not None,hex(x)
        finish(target);return
    if address==0x140c10370:finish();return
    if address==0x140c10324:finish(heap+0x40000);return
    if address==0x1401f7950:finish(x);return
    if address in [0x1401fa3a0,0x1401fa9e0,0x1401faa40]:
        raw=q(sp+0x38);callback=q(sp+0x30)
        published.append({'slot':y,'icon':read_text(z),'label':read_text(w) if address==0x1401fa9e0 else None,'labelRef':w if address!=0x1401fa9e0 else None,'kind':'entry' if address==0x1401fa3a0 else 'branch','callback':hex(callback),'argumentHex':hex(raw),'low32':raw&0xffffffff,'partyIndex':((raw>>16)&65535)-65536 if raw&0x80000000 else (raw>>16)&65535,'command':(raw&65535)-65536 if raw&32768 else raw&65535})
        finish();return
    if address==0x140860760:
        assignments.append({'actorId':int.from_bytes(u.mem_read(x+0xe8,4),'little'),'packedWidget':y&0xffffffff,'command':((y>>16)&65535)-65536 if y&0x80000000 else (y>>16)&65535,'associateType':y&65535});finish();return
    if address==0x140115890:finish();return
    # All remaining instructions run from the pinned original image, including
    # split unwind chunks. No original OS/transport service may be reached.
    if not ns['base']<=address<ns['base']+ns['pe'].OPTIONAL_HEADER.SizeOfImage:raise RuntimeError('Unknown native lower '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def call(address,*values):
    global instructions
    instructions=0;sp=stack+0xfe08;u.mem_write(sp-0x2000,bytes(0x2100));wq(sp,stop)
    for register in [UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(register,0)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],values):u.reg_write(register,value)
    u.reg_write(UC_X86_REG_RSP,sp);u.emu_start(address,stop,count=200001)
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def reset(raw_ids,objects,mode,dm_exe):
    state.clear();state.update(objects={},stats={},mode=mode,dmExe=dm_exe)
    u.mem_write(heap,bytes(0xf0000));wq(0x1412df970,app);wq(app,app);wi(actor+8,99);wi(menu+0x7f8,99);wq(menu+0x828,widget)
    wq(party+0x1190,array);wi(party+0x1198,len(raw_ids));wi(party+0x15cc,0)
    for index,oid in enumerate(raw_ids):
        entry=heap+0x20000+index*0x400;wq(array+index*8,entry);wi(entry+0x328,oid)
    for index,(oid,kind,master) in enumerate(objects):
        creature=heap+0x60000+index*0x1000;stats=heap+0x80000+index*0x100;wrapper=heap+0x90000+index*0x40;name=heap+0x94000+index*0x80
        wi(creature+8,oid);wi(creature+0x270,master);wi(creature+0x274,kind);wq(creature+0x3b0,stats);wq(wrapper,name);u.mem_write(name,('Associate_'+str(oid)).encode()+b'\0');state['objects'][oid]=creature;state['stats'][stats]=wrapper
    published.clear();assignments.clear();trace.clear()
def run_case(ids,objects,mode,dm_exe):
    reset(ids,objects,mode,dm_exe)
    count=call(0x1408520c0,party,1,99);first=call(0x140851dd0,party,1,99);second=call(0x140851ff0,party,1,99);remaining=call(0x140852180,party,1,99)
    wi(party+0x15cc,0);published.clear();call(0x1409945d0,menu,0,mode,0);entries=published.copy();cursor=int.from_bytes(u.mem_read(party+0x15cc,4),'little')
    pages=[]
    for _ in range(8):
        if not any(row['callback']=='0x140992240' for row in (entries if not pages else pages[-1]['entries'])):break
        published.clear();call(0x140992240,menu,0,0,0);pages.append({'entries':published.copy(),'cursor':int.from_bytes(u.mem_read(party+0x15cc,4),'little')})
    for entry in entries:
        if entry['callback']=='0x140995f10':call(0x140995f10,menu,int(entry['argumentHex'],16))
    return {'case':{'ids':ids,'objects':[{'id':oid,'type':kind,'master':master} for oid,kind,master in objects],'mode':mode,'dmExe':bool(dm_exe)},'queries':{'count':count,'first':first,'second':second,'remainingAfterTwo':remaining},'entries':entries,'cursorAfterRoot':cursor,'morePages':pages,'assignments':assignments.copy()}
cases=[]
for number in [0,1,2,3,4,8,9,10]:
    ids=list(range(100,100+number));objects=[(oid,1,99) for oid in ids]
    cases.append((ids,objects));cases.append(([777,*ids,0x7f000000],[(777,2,99),*objects]))
cases.extend([([100,101,102,103],[(100,1,777),(101,3,99),(102,1,99)]),([0x7f000000],[]),([0,100],[(0,1,99),(100,1,99)]),([100,100],[(100,1,99)])])
rows=[]
try:
    for (ids,objects),mode,dm_exe in itertools.product(cases,[0,1],[0,1]):rows.append(run_case(ids,objects,mode,dm_exe))
except Exception as error:
    Path(str(output)+'.failure.json').write_text(json.dumps({'accepted':False,'error':str(error),'case':{'ids':ids,'objects':objects,'mode':mode,'dmExe':dm_exe},'trace':trace,'completedCases':len(rows)},indent=2)+'\n');raise
report={'success':True,'binarySha256':ns['digest'],'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'baseFixtureSha256':proof['scriptSha256'],'cases':len(rows),'rows':rows,'authority':__doc__,'publicConnections':0,'targetProcesses':0}
output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'success':True,'report':str(output),'cases':len(rows)}))
