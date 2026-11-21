import fs from 'node:fs/promises';
import {NetworkMotion as Before} from '../backups/animations/network-motion-before-facing-v1.mjs';
import {NetworkMotion as After} from '../src/network_motion.js';
import {NetworkWorld} from '../src/network_world.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {openLocalModule} from './local-module.mjs';import {loadNetworkObjectRules} from '../src/network_object_rules.js';
const root=new URL('../',import.meta.url),dir=new URL('backups/animations/',root),capture=JSON.parse(await fs.readFile(new URL('local-network-movement-v91.json',dir),'utf8'));
const resolver=await openLocalModule('../FullDecomp/NwnRootInstall','../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm'),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),before=new Before(),after=new After(),stats={frames:0,pathPackets:0,canonicalUnchanged:true,before:{maxFrameTurn:0,maxPacketTurn:0,frameTurnsOver20Degrees:0},after:{maxFrameTurn:0,maxPacketTurn:0,frameTurnsOver20Degrees:0}};
const angle=(a,b)=>Math.abs(Math.atan2(Math.sin(b-a),Math.cos(b-a)))*180/Math.PI;
const rotations=m=>new Map([...m.objects.keys()].map(id=>[id,m.pose(id).rotation]));
const compare=(m,old,s,key)=>{for(const [id,r]of old){const now=m.pose(id);if(!now)continue;const turn=angle(r,now.rotation);s[key]=Math.max(s[key],turn);if(key==='maxFrameTurn'&&turn>20)s.frameTurnsOver20Degrees++;}};
let at=capture.wireTimes[0];
for(let i=0;i<capture.wireMessages.length;i++){
 const next=capture.wireTimes[i],canonical=JSON.stringify([...world.registry.objects]);
 while(at<next){const dt=Math.min(1000/60,next-at),old=rotations(before),now=rotations(after);before.update(dt/1000);after.update(dt/1000);compare(before,old,stats.before,'maxFrameTurn');compare(after,now,stats.after,'maxFrameTurn');stats.frames++;at+=dt;}
 if(canonical!==JSON.stringify([...world.registry.objects]))throw new Error('Movement changed canonical state');
 const msg=decodeServerGameMessage(Buffer.from(capture.wireMessages[i],'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(msg);
 if(msg.kind==='client-area'){before.objects.clear();after.objects.clear();}
 if(msg.kind==='object-updates')for(const event of world.presentationChanges){if(event.action!=='movement')continue;const obj=world.registry.get(event.id);if(!obj||obj.replicationRemoved||obj.areaId!==world.areaId)continue;const old=rotations(before),now=rotations(after);before.observe(obj,event.changes,event.created);after.observe(obj,event.changes,event.created);if(event.changes.path?.length)stats.pathPackets++;if(!event.created){compare(before,old,stats.before,'maxPacketTurn');compare(after,now,stats.after,'maxPacketTurn');}}
}
const result={scope:'Same real vanilla-server wire delivery times, isolated 60Hz movement replay. Flat height boundary; not a GPU frame-rate or visual turn-clip test.',capture:'local-network-movement-v91.json',...stats};
if(!stats.pathPackets||stats.after.maxPacketTurn>.001||stats.after.maxFrameTurn>6.1)throw new Error('Native turning replay bound failed '+JSON.stringify(result));
await fs.writeFile(new URL('network-facing-replay-v1.json',dir),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
