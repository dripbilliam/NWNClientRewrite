"""Complete original shared vision/immunity/bonus-feat/spell-defense item
materializers. Original effect construction/copy/SetInteger execute, lower
2DA/creator/application/string/allocation captured; not complete spell parity.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-item-property-materializers');rows=[]
types={'darkVision':26,'trueSeeing':71,'evasion':38,'immunity':37,'bonusFeat':12,'spellLevel':78,'spellSchool':54,'spellSpecific':53,'damagePercent':20,'vulnerability':24,'spellResistance':39}
for kind in ['darkVision','trueSeeing','evasion']:
 for loading in [0,1,3,-1]:rows.append(m.run(dict(kind=kind,type=types[kind],loading=loading)))
for kind,subtype,loading in itertools.product(['immunity','spellSchool'],[0,1,2,3,4,5,6,7,8,9,10,65535],[0,1,3]):rows.append(m.run(dict(kind=kind,type=types[kind],subtype=subtype,loading=loading)))
for subtype,status,value,noStats,loading in itertools.product([0,1,65535],[0,1],[0,212,65535,-1],[False,True],[0,1,3]):rows.append(m.run(dict(kind='bonusFeat',type=12,subtype=subtype,status=status,value=value,noStats=noStats,loading=loading)))
for kind,cost,loading in itertools.product(['spellLevel'],[0,1,9,65535],[0,1,3]):rows.append(m.run(dict(kind=kind,type=types[kind],costValue=cost,loading=loading)))
for kind,subtype,cost,table,status,value,loading in itertools.product(['spellSpecific','damagePercent','vulnerability','spellResistance'],[0,2,3,33,34,65535],[0,65535],[0,255],[0,1],[0,-1,15],[0,1,3]):rows.append(m.run(dict(kind=kind,type=types[kind],subtype=subtype,costValue=cost,costTable=table,status=status,value=value,loading=loading)))
for kind in ['damagePercent','spellSpecific']:rows.append(m.run(dict(kind=kind,type=types[kind],noTable=True)))
out=m.m.root/'backups/animations/native-form-immunity-observations.json';out.write_text(json.dumps(dict(binarySha256=m.m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
