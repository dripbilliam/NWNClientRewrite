import {initializeEncounter,spawnEncounterIfAppropriate,updateEncounterActivation,removeEncounterActiveCreature} from './encounter_activation.js';
import {areaSpatialIds,firstAreaSpatialIndex} from './nearest_objects.js';
import {inTrigger} from './trigger_geometry.js';
import {intEntry} from './combat_stats.js';
import {officialCampaign} from './combat_experience.js';
import {calculateEncounterPoints} from './encounter_activation.js';
import {makeEncounterSpawnList,padEncounterSpawnCount,splitEncounterSpawnEntry} from './encounter_spawn_list.js';
import {spawnEncounterCreatures} from './encounter_spawn.js';
import {computeSafeLocation,computeNonVisibleLocation} from './safe_location.js';
import {countVisibleToPlayers} from './area_visibility_count.js';
import {nativeCosf,nativeSinf} from './native_math.js';
import {normalizeOrientation} from './combat_lifecycle.js';
import {OBJECT_INVALID} from './game_object_array.js';
export class EncounterRuntime{
  constructor(session){this.session=session;this.points=Array.from({length:51},(_,n)=>Math.fround(1.5**n));}
  providers(){const s=this.session,c=s.combat;return{
    pow:(a,b)=>Math.fround(Math.pow(a,b)),log:Math.log,pointTable:()=>this.points,
    area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
    position:o=>{if(!Array.isArray(o.position)||o.position.length<3)throw new Error('Native encounter creature position is unavailable');return[o.position[0],-o.position[2],o.position[1]].map(Math.fround);},
    firstByX:(a,x)=>firstAreaSpatialIndex(s,a,x),spatialIds:a=>areaSpatialIds(s,a),inside:(o,point)=>Number(inTrigger(o,[point[0],point[2],-point[1]])),
    reaction:(o,id)=>s.aiReaction(o,id),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),statsPC:o=>o.nativeStatsIsPCb0,
    officialCampaign:()=>s.module?officialCampaign(s.module):0,classes:o=>o.stats?.classes,
    classInfo:id=>{const table=s.characterRules?.classes;if(!table)throw new Error('Native encounter class rules are unavailable');const count=table.orderedRows?.length??table.rows.size;
      // Original class pointer arithmetic does not validate physical bounds.
      if(id<0||id>=count)throw new Error('Native encounter class index is outside loaded storage');
      return{effective:Array.from({length:41},(_,n)=>intEntry(table,id,`EffCRLvl${String(n).padStart(2,'0')}`).value&255)};},
    possessed:o=>Number(o.isPossessedFamiliar??false),potentialLevel:o=>c.potentialLevel(o),alwaysReset:()=>Number(s.alwaysResetEncounterSpawns),
    spawn:o=>this.spawnCreatures(o),
  };}
  initialize(o,data){initializeEncounter(o,data,this.session.characterRules,this.providers());}
  spawn(o,id,cr){return spawnEncounterIfAppropriate(o,id,cr,this.providers());}
  updateActivation(o,id){return updateEncounterActivation(o,id,this.providers());}
  async creatureDied(actor){
    const s=this.session,o=s.registry.get(actor.nativeField948);if(o?.objectType!==13)return;
    const p=this.providers();await removeEncounterActiveCreature(o,actor.nativeChallengeRatingD0,0,{points:(o,cr)=>calculateEncounterPoints(o,cr,p),
      worldTime:()=>s.worldTimer.time(),exhaustedEvent:o=>s.scheduler.enqueue(o.id,{type:'nativeSubareaScript',eventId:10,callerId:o.id,payload:{scriptEvent:21,objectIds:[o.id]}})});
    actor.nativeField94c=1;
  }
  placementProviders(){const s=this.session,c=s.combat,movement=c.movementProviders(),render=p=>[p[0],p[2],Math.fround(-p[1])];
    const geometry=a=>{if(!a?.nativeGeometry)throw new Error('Native encounter placement geometry is unavailable');return a.nativeGeometry;};
    const p={height:(a,point)=>geometry(a).height(point),safePoint:(a,point,path,flag)=>movement.safePoint(a,render(point),path,flag),
      lineWalkable:(a,from,to)=>geometry(a).lineWalkable(from,to),polygons:(a,...args)=>geometry(a).detailedPolygons(...args),
      lineOfSight:(a,...args)=>geometry(a).lineOfSight(...args),warning:message=>c.warning({id:OBJECT_INVALID},message),
      spatialIds:a=>areaSpatialIds(s,a),object:id=>s.registry.get(id),client:c.broadcastProviders().client,position:this.providers().position};
    p.countVisible=(a,point,limit)=>countVisibleToPlayers(a,point,limit,p);return p;
  }
  spawnCreatures(o){const s=this.session,p=this.providers(),placement=this.placementProviders(),list={random:()=>s.random.next(),points:(o,cr)=>calculateEncounterPoints(o,cr,p)};
    return spawnEncounterCreatures(o,{...p,
      makeList:(o,out)=>makeEncounterSpawnList(o,out,list),splitEntry:(o,out,n,entry)=>splitEncounterSpawnEntry(o,out,n,entry,list),padList:(o,out)=>padEncounterSpawnCount(o,out,list),
      construct:()=>s.register('creature',`runtime:creature:${s.registry.nextObjectId[0]}`,{areaId:OBJECT_INVALID,position:[0,0,0],authored:{},inventory:[],registerAI:true}),
      loadTemplate:(o,name)=>s.loadCreatureTemplate(o,name),destroy:o=>{
        if(o.inventory?.length||o.effects?.length)throw new Error('Native failed encounter creature destructor inventory/effect cleanup is unavailable');
        s.aiMaster.removeObject(o);s.unregister(o.id);},
      safeLocation:(a,origin,range,path,flag,out)=>computeSafeLocation(a,origin,range,path,flag,out,placement),
      nonVisibleLocation:(a,origin,path,flag,out,range)=>computeNonVisibleLocation(a,origin,path,flag,out,range,placement),height:placement.height,
      addToArea:(o,a,point)=>{o.areaId=a.id;o.position=[point[0],point[2],Math.fround(-point[1])];a.objects.push(o.id);a.nativeSpatial.insert(o.id);s.refreshCombat(o);},
      playerCount:a=>a.nativePlayerCount150,setAILevel:(o,n)=>s.aiMaster.setLevel(o,n),setOrientation:(o,v)=>{o.orientation=[v[0],v[2],Math.fround(-v[1])];},
      cos:nativeCosf,sin:nativeSinf,normalize:v=>{const n=normalizeOrientation([v[0],v[2],Math.fround(-v[1])]);return[n[0],Math.fround(-n[2]),n[1]];},
      warning:message=>s.combat.warning(o,message),
    });
  }
}
