"""Read-only CanUseItem/CheckProficiencies gate oracle, build89.8193.37-17.

Execute complete native bodies with synthetic objects and substituted queries.
This covers gate order, storage widths and proficiency, not acquisition,
property effects, item cost, spellcasting or native controller ownership.
"""
from pathlib import Path
import sys,hashlib,struct,json,itertools
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
uc=Uc(UC_ARCH_X86,UC_MODE_64);uc.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095)
uc.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
uc.mem_map(heap,0x10000);uc.mem_map(stack,0x10000);uc.mem_map(stop,0x1000)
actor,item,stats,info,app,server,vt,config= [heap+n for n in [0,0x1000,0x2000,0x3000,0x4000,0x5000,0x6000,0x7000]]
def q(a):return struct.unpack('<Q',uc.mem_read(a,8))[0]
def wi(a,v):uc.mem_write(a,struct.pack('<I',v&0xffffffff))
def wh(a,v):uc.mem_write(a,struct.pack('<H',v&65535))
def wb(a,v):uc.mem_write(a,bytes([v&255]))
def wq(a,v):uc.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=uc.reg_read(UC_X86_REG_RSP);uc.reg_write(UC_X86_REG_RIP,q(rsp));uc.reg_write(UC_X86_REG_RSP,rsp+8);uc.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};calls=[];substitutions=set()
def query(name,v):calls.append(name);finish(v)
def hook(uc,a,n,_):
    if a==stop:uc.emu_stop();return
    y=uc.reg_read(UC_X86_REG_RDX)
    if a==0x140402f80:query('isDM',case['dm'])
    elif a==0x1403d2830:query('alignmentRestrictions',case['alignment'])
    elif a==0x1403d2c00:query('classRestrictions',case['class'])
    elif a==0x1403d2ce0:query('raceRestrictions',case['race'])
    elif a==0x14055b590:query('controlledByPlayer',case['controlled'])
    elif a==stop+0x100:query('itemLevelRestrictions',0);uc.reg_write(UC_X86_REG_RAX,config)
    elif a==0x1404035c0:query('level',case['level']&255)
    elif a==0x140468d90:query('minimumEquipLevel',case['minimum']&255)
    elif a==0x14029ca00:finish(info if case.get('baseValid',1) else 0)
    elif a==0x1403d2d90 and case['kind']=='use':query('proficient',case['proficient'])
    elif a==0x140466500:query('armorClass',case['armor'])
    elif a==0x14040b900:query(f'hasFeat:{y&65535}',int((y&65535) in case['ownedFeats']))
    elif a==0x14029df20:finish(case['requiredFeats'][y&255]&65535)
    elif not (0x1403d2410<=a<0x1403d2821 or 0x1403d2d90<=a<0x1403d2ee7):raise RuntimeError(f'Unmapped item dependency {a:x}')
    else:return
    substitutions.add(hex(a))
uc.hook_add(UC_HOOK_CODE,hook)
defaults={'kind':'use','dm':0,'associate':0,'alignment':1,'class':1,'race':1,'base':22,
 'polymorph':0,'pc':0,'controlled':0,'ilr':0,'level':1,'minimum':2,'ignore':1,'identified':1,
 'weaponWield':0,'weaponType':1,'weaponSize':3,'size':3,'slots':16,'proficient':1}
cases=[]
for k,values in {'dm':[0,1,-1],'associate':[3,8,65544,65539], 'alignment':[0,2],
 'class':[0,2],'race':[0,2],'base':[14,36,49,56,57,75,78,104], 'polymorph':[1,2],
 'weaponWield':[1,257],'weaponType':[0,256],'weaponSize':[0,1,2,3,4,5,6,259],
 'slots':[0,2,32,0x20000],'proficient':[0,2],'size':[1,2,4,257]}.items():
    for value in values:cases.append({**defaults,k:value})
for pc,assoc,controlled,ilr,level,minimum,ignore,identified in itertools.product([0,1],[0,3],[0,1],[0,1],[1,258],[2],[0,1],[0,1]):
    cases.append({**defaults,'pc':pc,'associate':assoc,'controlled':controlled,'ilr':ilr,'level':level,'minimum':minimum,'ignore':ignore,'identified':identified})
for failure in ['alignment','class','race']:
    cases.append({**defaults,failure:0,'pc':1,'ignore':0,'identified':0,'ilr':1})
    cases.append({**defaults,failure:0,'pc':1,'ignore':1,'ilr':1,'level':10})
for base,size in itertools.product([49,57,104],[1,2,3]):cases.append({**defaults,'base':base,'size':size,'polymorph':1,'weaponType':0})
for valid,slots,slot,weapon,armor,owned in itertools.product([0,1],[0,2,16],[2,16],[0,3],[0,1,4,6], [[],[2],[3],[4],[12]]):
    cases.append({'kind':'proficiency','base':22,'baseValid':valid,'slots':slots,'slot':slot,'modelType':weapon,
      'armor':armor,'ownedFeats':owned,'requiredFeats':[11,12]})
cases.append({'kind':'proficiency','base':22,'slots':16,'slot':16,'modelType':0,'armor':0,'ownedFeats':[],'requiredFeats':[]})
observations=[]
for case in cases:
    uc.mem_write(heap,bytes(0x10000));calls=[]
    wq(actor+0xad0,stats);wi(item+0x40,case['base']);wq(0x1412df8f8,app);wq(0x1412df970,app)
    wq(app+0x20,heap+0x8000);wq(app+8,server);wq(server,vt);wq(vt+0x68,stop+0x100)
    wi(info+4,case['slots']);wb(info+0x16,case.get('modelType',0))
    if case['kind']=='use':
        wh(actor+0x908,case['associate']);wi(actor+0x97c,case['polymorph']);wi(actor+0x89c,case['pc']);wi(actor+0x718,case['size'])
        wi(item+0x360,case['identified']);wi(config+0x134,case['ilr'])
        for offset,key in [(8,'weaponWield'),(9,'weaponType'),(0x19,'weaponSize')]:wb(info+offset,case[key])
    else:wb(info+0x98,len(case['requiredFeats']))
    rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));wq(rsp,stop)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,item,case['ignore'] if case['kind']=='use' else case['slot']]):uc.reg_write(reg,value)
    uc.reg_write(UC_X86_REG_RSP,rsp)
    try:uc.emu_start(0x1403d2410 if case['kind']=='use' else 0x1403d2d90,stop,count=10000)
    except Exception:
        print(json.dumps({'failedCase':case,'rip':hex(uc.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
    assert uc.reg_read(UC_X86_REG_RIP)==stop
    observations.append({**case,'result':uc.reg_read(UC_X86_REG_RAX)&0xffffffff,'calls':calls})
output=root/'backups/animations/native-item-use-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'substitutions':sorted(substitutions),'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
