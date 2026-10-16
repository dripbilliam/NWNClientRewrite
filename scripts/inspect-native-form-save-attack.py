"""Full original attack/save-vs/changed-save/turn-resistance item owners.
Original effect constructors and copies execute. Lower combat/base/2DA/
creator/application/allocation/string operations captured, not full combat.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-item-property-materializers');rows=[]
for type_,subtype,slot,wield,value,loading in itertools.product([56,57,58,59],[0,1,2,3,4,5,6,7,8,9,65535],[16,32,16384,32768,65536,8,1],[0,8],[0,3],[0,1]):rows.append(m.run(dict(kind='attack',type=type_,subtype=subtype,slot=slot,wield=wield,value=value,loading=loading)))
for subtype,value,status,table,saveStatus,saveValue,loading in itertools.product([0,1,2,3,9,10,11,13,18,19,20,21,22,65535],[0,3,-3,-2147483648],[0,1],[False,True],[0,1],[-1,22],[0,1]):rows.append(m.run(dict(kind='saveVs',type=40,subtype=subtype,value=value,status=status,saveTable=table,saveStatus=saveStatus,saveValue=saveValue,loading=loading)))
for cost,loading in itertools.product([0,1,65535],[0,1,3,-1]):rows.append(m.run(dict(kind='turnResistance',type=73,costValue=cost,loading=loading)))
out=m.m.root/'backups/animations/native-form-save-attack-observations.json';out.write_text(json.dumps(dict(binarySha256=m.m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
