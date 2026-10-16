"""Complete unchanged ApplyACBonus, using the real effect constructor and
SetInteger instructions with captured table/base/creator/application boundaries.
Reuse the established constructor harness; no lower effect-owner claim.
"""
import importlib,json,itertools
from pathlib import Path
b=importlib.import_module('inspect-native-item-property-materializers')
rows=[b.run(dict(kind='armor',type=type_,subtype=subtype))for type_,subtype in itertools.product([1,2,3,4,5],[0,1,2,3,4,5,6,7,8,9,65535])]
rows.extend(b.run(dict(kind='armor',type=1,value=value,status=status,loading=loading,acEnchant=category))for value,status,loading,category in itertools.product([0,-1,1,6],[0,1],[0,3],[0,1,2,3,4,255]))
out=b.m.root/'backups/animations/native-item-ac-materializer-observations.json';out.write_text(json.dumps(dict(binarySha256=b.m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
