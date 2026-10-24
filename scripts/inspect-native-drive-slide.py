"""Original7fdeb0 mode2 blocked-line fallback and path factor, isolated unchanged
89.8193.37-17 instructions. Only abstract halfspace collision results and lower
allocator/UI/animation/area lookups are captured. This verifies installer search
semantics, not complete native world geometry, ghosting or server bump policy.
No live process modifications or copied game assets.
"""
import sys,importlib,json,math,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');rows=[]
for angle,distance,tilt,offset in itertools.product([0,30,90,150,225,315],[.4,.8,1.76],[-45,0,45],[0,.001]):
 a=math.radians(angle);n=math.radians(angle+tilt);position=[10.,20.,1.]
 c=dict(position=position,target=[position[0]+math.cos(a)*distance,position[1]+math.sin(a)*distance,1.],planes=[dict(origin=position,normal=[math.cos(n),math.sin(n),0],offset=offset)])
 rows.append(p.run(c,'install'))
for angle in [0,30,90,150,225,315]:
 a=math.radians(angle);position=[10.,20.,1.]
 c=dict(position=position,target=[position[0]+math.cos(a),position[1]+math.sin(a),1.],planes=[dict(origin=position,normal=[math.cos(a+side),math.sin(a+side),0]) for side in [-math.pi/4,math.pi/4]])
 rows.append(p.run(c,'install'))
for angle in [0,30,90,225]:
 a=math.radians(angle);position=[10.,20.,1.]
 rows.append(p.run(dict(position=position,render=[10.03,19.98,1.],target=[position[0]+math.cos(a),position[1]+math.sin(a),1.],planes=[dict(origin=position,normal=[math.cos(a),math.sin(a),0],offset=.001)]),'install'))
partials=[p.run(dict(position=[10.,20.,1.],target=[14.,20.,1.],wall=wall),'install')for wall in [100.,12.,11.,10.5,10.1,10.04]]
blocked=[]
for flags in [1,2,3,4,8,7,11,19]:
 position=[10.,20.,1.];planes=[dict(origin=position,normal=n)for n in [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0]]]
 blocked.append(p.run(dict(position=position,orientation=[1.,0.,0.],flags=flags,planes=planes),'full-preview'))
out=p.m.root/'backups/animations/native-drive-slide-v1.json';out.write_text(json.dumps(dict(target=p.m.digest,limits=__doc__,cases=rows,partialLines=partials,blockedAnimation=blocked),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),installed=sum(bool(r['paths'])for r in rows),queries=sum(len(r['queries'])for r in rows),partialLines=len(partials),blockedAnimations=len(blocked),output=str(out))))
