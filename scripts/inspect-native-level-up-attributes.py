"""Original CG_LEVUP_ATTRIB twelve arrows plus Cancel/Escape.
The unchanged original callbacks and actual class/ability/stat setters execute.
Object lookup, help/point/numeric GUI delivery and modal destruction are captured
boundaries. This proves private selection/point/stat transitions, not original
pixels, recommendation I/O, class admission or a server level-up result.
"""
from pathlib import Path
import types,json,copy,random
root=Path(__file__).resolve().parents[1]
source=root/'scripts/inspect-native-creation-vitals.py'
prefix=source.read_text().split("if __name__=='__main__':",1)[0]
needle='u.hook_add(UC_HOOK_CODE,hook)'
assert prefix.count(needle)==1
v=types.ModuleType('native_level_up_vitals');v.__file__=str(source)
exec(compile(prefix.replace(needle,'baseline_hook_handle='+needle),str(source),'exec'),v.__dict__)
u=v.u;m=v.m;u.hook_del(v.baseline_hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
arrows=[(0x1408e74e0,0x1408e76b0),(0x1408e28a0,0x1408e2a80),(0x1408e2360,0x1408e2540),(0x1408e2f10,0x1408e30f0),(0x1408e8030,0x1408e8310),(0x1408e1780,0x1408e1a60)]
ends={0x1408e74e0:0x1408e7569,0x1408e76b0:0x1408e7723,0x1408e28a0:0x1408e2929,0x1408e2a80:0x1408e2afc,0x1408e2360:0x1408e23e9,0x1408e2540:0x1408e25bc,0x1408e2f10:0x1408e2f99,0x1408e30f0:0x1408e316c,0x1408e8030:0x1408e80b9,0x1408e8310:0x1408e838c,0x1408e1780:0x1408e1809,0x1408e1a60:0x1408e1adc,0x1408e1180:0x1408e11b0,0x1408e33c0:0x1408e33f0}
# Exact inclusive ranges come from the retained original function dossiers.
v.ranges += [(start,end+1)for start,end in ends.items()]
present=True;calls=[]
def hook(u,address,size,unused):
    x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
    if address==0x140800c90:
        calls.append(dict(kind='object-lookup',id=x&0xffffffff,present=present));m.finish(v.creature if present else 0)
    elif address in [0x1408ef340,0x1408e0a80,0x1408ee600]:
        calls.append(dict(kind='gui-boundary',procedure=hex(address),index=y&0xffffffff if address==0x1408ef340 else None));m.finish()
    elif address==0x1401fc470:
        # CG_LEVUP_ATTRIB uses CGuiPanel::Deactivate, unlike creation's
        # CGuiModalPanel::Deactivate captured by the reused setter harness.
        calls.append(dict(kind='nonmodal-deactivation',code=y&0xffffffff));v.deactivated.append(y&0xffffffff);m.finish()
    else:v.hook(u,address,size,unused)
u.hook_add(UC_HOOK_CODE,hook)
def state():return dict(selected=m.si(v.panel+0x2310),points=m.si(v.panel+0x230c),raw=list(u.mem_read(v.actor+0x76,6)),scores=list(u.mem_read(v.actor+0x70,6)))
if __name__=='__main__':
    out=root/'godot-client/reports/native-level-up-attributes-original-v1.json'
    assert not out.exists(),'Preserve original evidence'
    old=json.loads((root/'backups/animations/native-creation-vitals-observations-v1.json').read_text())
    rows=[];rng=random.Random(83016)
    for at in range(56):
        c=copy.deepcopy(old['rows'][at%len(old['rows'])]['case']);c['operations']=[]
        c['source']['abilities']={key:rng.choice([0,1,8,18,127,254,255])for key in v.keys}
        present=True;calls=[];v.run(c);m.wi(v.panel+0x2300,42)
        selected=at%7-1;m.wi(v.panel+0x230c,1 if selected<0 else 0);m.wi(v.panel+0x2310,selected)
        event=m.heap+0x70000;m.wq(0x14140cdb8,event)
        initial=state();results=[]
        operations=[(0,1),(1,1),(1,-1),(0,-1)]+[(i,d)for i in range(6)for d in [1,-1]]
        for index,direction in operations:
            calls=[];m.wi(event+0x18,index);before=state();v.call(arrows[index][direction==1],[v.panel]);results.append(dict(operation=dict(index=index,direction=direction),before=before,state=state(),calls=calls))
        present=False;calls=[];before=state();v.call(arrows[0][1],[v.panel]);results.append(dict(operation=dict(index=0,direction=1,present=False),before=before,state=state(),calls=calls));present=True
        v.call(0x1408e1180,[v.panel]);v.call(0x1408e33c0,[v.panel]);assert v.deactivated==[2,2]
        rows.append(dict(case=c,initial=initial,results=results,cancelAndEscape=list(v.deactivated)))
    value=dict(binarySha256=m.digest,scope=__doc__,procedures=[hex(a)for a in ends],ranges=[dict(start=hex(a),end=hex(b))for a,b in ends.items()],rows=rows,scriptSha256=__import__('hashlib').sha256(Path(__file__).read_bytes()).hexdigest())
    out.write_text(json.dumps(value,indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(rows),operations=sum(len(row['results'])for row in rows))))
