import {clientParryVisual} from './client_parry_visual.js';
import {nativeFloatEntry} from './movement_rate.js';

// SpawnHitVisuals80bb10 mode0, invoked by the existing native hit callback.
// This creates only a client type11 visual; it never changes canonical state.
export class NetworkParryVisual{
 constructor(scene){this.scene=scene;}
 receive(actor){const s=this.scene;
  try{return clientParryVisual(actor,{
   targetId:o=>o.replicated.facingTarget,
   object:id=>{const o=s.world.registry.get(id);return o?.objectType===5&&!o.replicationRemoved&&o.areaId===s.world.areaId?o:null;},
   creatureSpace:o=>nativeFloatEntry(s.tables.appearance,o.appearance.appearance,'CREPERSPACE').value,
   impactPose:o=>{const render=s.objects.get(o.id)?.wrapper,model=render&&s.poses.modelHandle(render);if(!model)return null;const position=[0,0,0],quaternion=[1,0,0,0];return s.poses.nodePoseInto(model,'impact',position,quaternion)?position:null;},
   position:o=>{const p=s.objects.get(o.id)?.wrapper.position;if(!p)throw new Error('Native parry source/target displayed position is unavailable');return[p.x,-p.z,p.y];},
   orientation:o=>{const value=s.motion.objects.get(o.id)?.orientation;if(!value)throw new Error('Native parry displayed facing is unavailable');return value;},
   warning:reason=>s.combat.failure(actor,reason==='missing-impact'?'Native parry actor has no impact node':'Native parry impact height exceeds five metres','network.scene-parry-warning'),
   areaVisual:(_o,visualId,position)=>{if(s.closed)return 0;void s.areaVisuals.receive({visualId,position});s.combat.event({kind:'parry-visual',objectId:actor.id,visualId,position});return 1;}
  });}catch(error){s.combat.failure(actor,error.message,'network.scene-combat-effect-unhandled');return 0;}
 }
}
