"""Extend the retained original Commands oracle with named submenus and signed callbacks."""
from pathlib import Path
import argparse, hashlib, itertools, json
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);args=parser.parse_args()
output=Path(args.report).resolve();assert output.is_relative_to(root) and not output.exists()
source=root/'scripts/inspect-native-command-associate-menu.py'
prior=json.loads((root/'godot-client/reports/native-command-associate-original-v1.json').read_text())
assert hashlib.sha256(source.read_bytes()).hexdigest()==prior['scriptSha256']
ns={'__file__':str(source),'__name__':'_retained_command_oracle'}
exec(compile(source.read_text().split('\ncases=[]\n')[0],str(source),'exec'),ns)
call=ns['call'];published=ns['published'];assignments=ns['assignments'];menu=ns['menu'];reset=ns['reset']
rows=[]
try:
    for number in [0,1,2,3,4,8,9,10,11,12,18,20]:
        for prefix,mode,dm in itertools.product([False,True],[0,1],[0,1]):
            ids=list(range(100,100+number));objects=[(oid,1,99) for oid in ids]
            if prefix:ids=[777,*ids,0x7f000000];objects=[(777,2,99),*objects]
            row=ns['run_case'](ids,objects,mode,dm);submenus=[]
            for page in [row['entries'],*[page['entries'] for page in row['morePages']]]:
                for branch in page:
                    if branch['callback']!='0x14098f7d0':continue
                    published.clear();assignments.clear();call(0x14098f7d0,menu,int(branch['argumentHex'],16));entries=published.copy()
                    for entry in entries:call(0x140995f10,menu,int(entry['argumentHex'],16))
                    submenus.append({'branchArgument':branch['argumentHex'],'entries':entries,'assignments':assignments.copy()})
            row['submenus']=submenus;rows.append(row)
    callbacks=[]
    reset([100,101],[(100,1,99),(101,1,99)],1,0)
    for index,command in itertools.product([0,1,2,32767,32768,65535],[-19,-20,-18]):
        assignments.clear();raw=(index<<16)|(command&65535);call(0x140995f10,menu,raw)
        callbacks.append({'partyIndexWord':index,'command':command,'argumentHex':hex(raw),'assignment':assignments.copy()})
except Exception as error:
    Path(str(output)+'.failure.json').write_text(json.dumps({'accepted':False,'error':str(error),'trace':ns['trace'],'completedCases':len(rows)},indent=2)+'\n');raise
report={'success':True,'binarySha256':prior['binarySha256'],'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'baseScriptSha256':prior['scriptSha256'],'cases':len(rows),'callbackCases':len(callbacks),'rows':rows,'callbacks':callbacks,'authority':__doc__+' Original PE execution only; native services and bounds inherited unchanged from v1. No target process/network/GPU.','publicConnections':0,'targetProcesses':0}
output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'success':True,'cases':len(rows),'callbackCases':len(callbacks),'report':str(output)}))
