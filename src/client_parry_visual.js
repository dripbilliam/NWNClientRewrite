const f=Math.fround;
// Complete SpawnHitVisuals80bb10's mode0 branch. Positions/orientation and
// impact-node pose are native Z-up floats; area visual118 owns its own lifetime.
export function clientParryVisual(actor,p){
 const target=p.object(p.targetId(actor));if(!target)return 0;
 let space=f(p.creatureSpace(target));const impact=p.impactPose(actor);if(!impact){p.warning('missing-impact');return 0;}
 const targetPosition=p.position(target),sourcePosition=p.position(actor),facing=p.orientation(actor),height=f(f(impact[2])-f(targetPosition[2]));
 if(Math.abs(height)>5)p.warning('impact-height');if(space<=f(.5))space=f(space*2);
 const position=[f(f(targetPosition[0])-f(f(facing[0])*space)),f(f(targetPosition[1])-f(f(facing[1])*space)),f(f(sourcePosition[2])+Math.abs(height))];
 return p.areaVisual(actor,118,position);
}
