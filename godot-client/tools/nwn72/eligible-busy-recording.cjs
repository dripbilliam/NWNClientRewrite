'use strict';
// Read-only census of the pinned generation-2 busy-area capture. No client or FPS run.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const capture='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf';
const pins={recording:'1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463',timeline:'6ce44bfe52a7bd8c3b08e936206360847cd3bb1ec1713bd1d21c7304882d3920'};
const output=process.argv.find(x=>x.startsWith('--report='))?.slice(9);
if(!output||!path.isAbsolute(output)||fs.existsSync(output))throw Error('Provide an unused absolute --report path');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const recordingBytes=fs.readFileSync(path.join(capture,'recording.json'));
const timelineBytes=fs.readFileSync(path.join(capture,'timeline.jsonl'));
if(hash(recordingBytes)!==pins.recording||hash(timelineBytes)!==pins.timeline)throw Error('Pinned capture bytes changed');
const recording=JSON.parse(recordingBytes);
if(recording.complete!==true||recording.timelineSha256!==pins.timeline||recording.events!==5704)throw Error('Pinned capture metadata changed');
const same=(a,b)=>{
 if(Object.is(a,b))return true;
 if(Array.isArray(a)&&Array.isArray(b))return a.length===b.length&&a.every((v,i)=>same(v,b[i]));
 if(a&&b&&typeof a==='object'&&typeof b==='object'&&!Array.isArray(a)&&!Array.isArray(b)){
  const ak=Object.keys(a),bk=Object.keys(b);return ak.length===bk.length&&ak.every(k=>Object.hasOwn(b,k)&&same(a[k],b[k]));
 }
 return false;
};
const select=(v,keys)=>keys.map(k=>Object.hasOwn(v,k)?v[k]:null);
const poseKeys=['render','orientation','animation'];
const motionKeys=['position','render','active','correction','cursor','script','factor','newPath','acceleration','walkRate','runRate','walkDistance','runDistance'];
const facingKeys=['orientation','targetOrientation'];
const stateKeys=[...new Set([...poseKeys,...motionKeys,...facingKeys,'driveHeld'])];
const sample={rows:0,actors:new Set(),frames:new Set(),first:0,comparable:0,pose_same:0,pose_changed:0,motion_same:0,motion_changed:0,facing_same:0,facing_changed:0,tracked_state_same:0,tracked_state_changed:0,keyboard_same:0,keyboard_changed:0,active:0,correcting:0,target_unsettled:0,drive_held:0,idle_tracked_unchanged:0,idle_pose_unchanged:0};
const packets={events:0,rows:0,ids:new Set(),created:0,changed_keys:{},created_ids:new Set(),empty_changes:0,complete_repeat_same_id:0,same_values_by_key:{},different_values_by_key:{},first_value_by_key:{}};
const previousSample=new Map(),previousWire=new Map();
for(const line of timelineBytes.toString('utf8').split('\n')){
 if(!line)continue;
 const event=JSON.parse(line),v=event.value;
 if(v?.areaId!==2147618622||v?.generation!==2)continue;
 if(event.kind==='movement-sample'&&v.kind==='movement-sample'){
  sample.rows++;sample.actors.add(v.actorId);sample.frames.add(v.native_frame);
  const s=v.state||{},keyboard=v.keyboard||{};
  const active=Boolean(s.active)||Boolean(keyboard.moving),correcting=Number(s.correction||0)!==0;
  const unsettled=!same(s.orientation,s.targetOrientation);
  if(active)sample.active++;if(correcting)sample.correcting++;if(unsettled)sample.target_unsettled++;if(s.driveHeld)sample.drive_held++;
  const key=[v.connection,v.generation,v.areaId,v.actorId,v.lifetime].join('/'),prior=previousSample.get(key);
  if(!prior){sample.first++;}else{
   sample.comparable++;
   const poseSame=same(select(s,poseKeys),select(prior.state,poseKeys));
   const motionSame=same(select(s,motionKeys),select(prior.state,motionKeys));
   const facingSame=same(select(s,facingKeys),select(prior.state,facingKeys));
   const allSame=same(select(s,stateKeys),select(prior.state,stateKeys));
   const keyboardSame=same(keyboard,prior.keyboard);
   sample[poseSame?'pose_same':'pose_changed']++;
   sample[motionSame?'motion_same':'motion_changed']++;
   sample[facingSame?'facing_same':'facing_changed']++;
   sample[allSame?'tracked_state_same':'tracked_state_changed']++;
   sample[keyboardSame?'keyboard_same':'keyboard_changed']++;
   if(!active&&!correcting&&!unsettled&&!s.driveHeld&&keyboardSame&&allSame)sample.idle_tracked_unchanged++;
   if(!active&&!correcting&&!unsettled&&!s.driveHeld&&poseSame)sample.idle_pose_unchanged++;
  }
  previousSample.set(key,{state:s,keyboard});
 }else if(event.kind==='frame'&&v.kind==='movement'){
  packets.events++;
  for(const row of v.records||[]){
   packets.rows++;packets.ids.add(row.id);if(row.created){packets.created++;packets.created_ids.add(row.id);}
   const changes=row.changes||{};if(!Object.keys(changes).length)packets.empty_changes++;
   const key=[v.connection,v.generation,v.areaId,row.id].join('/');
   const prior=row.created?null:previousWire.get(key);
   if(prior&&same(changes,prior))packets.complete_repeat_same_id++;
   for(const [field,value] of Object.entries(changes)){
    packets.changed_keys[field]=(packets.changed_keys[field]||0)+1;
    const priorField=prior&&Object.hasOwn(prior,field)?prior[field]:undefined;
    const bucket=priorField===undefined?'first_value_by_key':same(value,priorField)?'same_values_by_key':'different_values_by_key';
    packets[bucket][field]=(packets[bucket][field]||0)+1;
   }
   previousWire.set(key,{...prior,...changes});
  }
 }
}
const report={scope:'Pinned generation-2 Arelith busy-area capture census only. movement-sample is the recorded controlled actor, not every creature. No Godot frame, renderer, combat/effect-clock or FPS measurement; unchanged input is not authorization to skip World.apply_pose.',capture,pins,census_script_sha256:hash(fs.readFileSync(__filename)),source:{network_motion:hash(fs.readFileSync(path.join(root,'systems/network_motion.gd'))),live_world:hash(fs.readFileSync(path.join(root,'systems/native_render/live_world.gd')))},areaId:2147618622,generation:2,recordedEvents:recording.events,uniqueSampleActors:[...sample.actors],uniqueSampleFrames:sample.frames.size,samples:{...sample,actors:sample.actors.size,frames:sample.frames.size},movementPackets:{...packets,ids:packets.ids.size,created_ids:packets.created_ids.size}};
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,source:report.source,samples:{rows:sample.rows,comparable:sample.comparable,pose_same:sample.pose_same,tracked_state_same:sample.tracked_state_same,active:sample.active,idle_tracked_unchanged:sample.idle_tracked_unchanged},movementPackets:{events:packets.events,rows:packets.rows,ids:packets.ids.size}}));
