"""Original6ea9e0 +7fdeb0 against exact local prediction inputs/query answers.

The original vector/search/animation-selection instructions execute unchanged.
Collision answers, controlled-object lookup, idle animation query, allocation,
path installation and timer notification remain explicit captured boundaries.
This does not execute the original world collision code, frame scheduler or GPU.
No live original process writes or copied assets.
"""
import sys,importlib,json,math,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview')
name=sys.argv[1]if len(sys.argv)>1 else'creation-performance-exact-drive-capture-v1.json';version=sys.argv[2]if len(sys.argv)>2 else'v1';assert re.fullmatch(r'creation-performance-(?:exact-drive|path-acceptance|local-delay)-capture-v\d+\.json',name);assert re.fullmatch(r'v\d+',version)
source=p.m.root/'backups/animations'/name
capture=json.loads(source.read_text());all_inputs='--all'in sys.argv[3:];previews=(capture['keyboardSmooth']['previews']if all_inputs else[])+capture['contact']['keyboard']['previews'];rows=[]
for index,preview in enumerate(previews):
 trace=preview.get('trace')
 if not trace or not trace.get('applied') or not trace.get('query',{}).get('queries'):continue
 expected=trace['query']['queries'];cursor=0;maximum_delta=0
 def recorded_line(case,start,end):
  global cursor,maximum_delta
  assert cursor<len(expected),dict(index=index,extraQuery=cursor,start=start,end=end)
  row=expected[cursor];cursor+=1
  delta=max(abs(a-b)for a,b in zip(start+end,row['from']+row['to']));maximum_delta=max(maximum_delta,delta)
  assert delta<2e-5,dict(index=index,query=cursor-1,delta=delta,nativeStart=start,nativeEnd=end,expected=row)
  return row['clear']
 p.fixture_line=recorded_line
 case=dict(position=trace['from'],render=trace['render'],orientation=trace['orientation'],walkRate=trace['walkRate'],runRate=trace['runRate'],flags=preview['flags'],correction=trace['correction'])
 native=p.run(case,'full-preview');assert cursor==len(expected),dict(index=index,used=cursor,expected=len(expected))
 observed=preview.get('path');assert bool(native['paths'])==(observed is not None),dict(index=index,paths=native['paths'],observed=observed)
 endpoint_delta=0
 if observed is not None:
  endpoint_delta=max(abs(a-b)for a,b in zip(native['paths'][0]['points'][-1],observed['target']));assert endpoint_delta<2e-5,dict(index=index,endpointDelta=endpoint_delta)
  assert abs(native['factor']-observed['factor'])<2e-6,dict(index=index,factor=native['factor'],observed=observed['factor'])
 assert native['animations']==[trace['plan']['animation']],dict(index=index,animations=native['animations'],plan=trace['plan'])
 expected_refresh=[] if observed is None or 'resendFraction' not in observed else[observed['resendFraction']]
 assert native['refresh']==expected_refresh,dict(index=index,refresh=native['refresh'],expected=expected_refresh)
 rows.append(dict(index=index,flags=preview['flags'],input=case,correction=trace['correction'],queryCount=cursor,maximumQueryDelta=maximum_delta,endpointDelta=endpoint_delta,observed=observed,nativePaths=native['paths'],nativeAnimations=native['animations'],nativeFactor=native['factor'],nativeRefresh=native['refresh']))
assert rows
report=dict(target=p.m.digest,source=source.name,selection='free-and-contact'if all_inputs else'contact-only',scope=__doc__,bundle=capture['bundle'],cases=rows,counts=dict(cases=len(rows),queries=sum(r['queryCount']for r in rows),nullPaths=sum(r['observed']is None for r in rows),correctedInputs=sum(bool(r['correction'])for r in rows)),success=True)
out=p.m.root/f'backups/animations/native-exact-drive-preview-{version}.json';out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(success=True,target=p.m.digest,counts=report['counts'],maximumQueryDelta=max(r['maximumQueryDelta']for r in rows),maximumEndpointDelta=max(r['endpointDelta']for r in rows))))
