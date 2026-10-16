"""Four complete shared item materializers with original CGameEffect base
constructor/SetInteger instructions. Lower SetCreator/ApplyEffect/2DA/string/
allocator captured; no whole-spell or combat acceptance claim.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-item-property-materializers')
rows=[]
for loading,slot in itertools.product([0,1,3,-1],[1,16,0x20000]):rows.append(m.run(dict(kind='freeAction',type=75,loading=loading,slot=slot)))
for kind,type_,subtype,cost,loading,status,value in itertools.product(['skill','reduction','resistance'],[0],[0,1,2,3,33,65535],[0,1,65535],[0,1,3],[0,1],[0,-1,7]):
 rows.append(m.run(dict(kind=kind,type={'skill':52,'reduction':22,'resistance':23}[kind],subtype=subtype,costValue=cost,loading=loading,status=status,value=value)))
out=m.m.root/'backups/animations/native-polymorph-item-property-observations.json';out.write_text(json.dumps(dict(binarySha256=m.m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
