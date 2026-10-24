import {intEntry} from '../../src/combat_stats.js';
import {nativeFloatEntry} from '../../src/movement_rate.js';
import {nativeStringEntry} from '../../src/spell_metadata.js';

// Original decoded presentation events only. Never roll attacks, alter HP,
// evaluate spell effects or advance a browser/Three animation frame here.
export class CombatDelivery {
 constructor({session,connection,active,tables,send,now=()=>performance.now(),diagnose=()=>{}}){Object.assign(this,{session,connection,active,tables,send,now,diagnose});this.identities=new WeakMap();this.serial=0;this.reset();}
 reset(){this.epoch=(this.epoch??0)+1;this.pending=[];this.signature=null;this.area=-1;this.generation=-1;}
 identity(object){if(!this.identities.has(object))this.identities.set(object,++this.serial);return this.identities.get(object);}
 scope(){return{areaId:this.session.world.areaId,generation:this.session.areaGeneration};}
 current(scope){return this.active()&&!this.session.closed&&scope.areaId===this.session.world.areaId&&scope.generation===this.session.areaGeneration;}
 receive(events){const scope=this.scope();if(this.area!==scope.areaId||this.generation!==scope.generation){this.reset();this.area=scope.areaId;this.generation=scope.generation;}
  for(const event of events){if(!['cast-animation','attack-animation'].includes(event.action))continue;const actor=this.session.world.registry.get(event.id);if(!actor||actor.replicationRemoved||actor.areaId!==scope.areaId)continue;if(this.pending.length>=512){this.diagnose('godot.combat-queue-capacity','Decoded combat presentation queue exceeded its bounded capacity');break;}this.pending.push({actor,event:structuredClone(event),at:this.now(),scope});}
 }
 actor(object,rules){
  const value=(table,id,column)=>{const entry=nativeFloatEntry(rules[table],id,column);return entry.found&&Number.isFinite(entry.value)?entry.value:null;};
  const appearance=object.appearance?.appearance,equipment={};for(const entry of object.appearance?.equipment??[]){const item=entry.item;if(!item)continue;const base=item.baseItem;equipment[entry.slot]={baseItem:base,weaponType:intEntry(rules.baseitems,base,'WeaponType').value,weaponWield:intEntry(rules.baseitems,base,'WeaponWield').value,weaponSize:intEntry(rules.baseitems,base,'WeaponSize').value,slashLeft:intEntry(rules.baseitems,base,'%AnimSlashL').value,slashRight:intEntry(rules.baseitems,base,'%AnimSlashR').value,preferredDistance:value('baseitems',base,'PrefAttackDist')};}
  const classes=object.replicated?.stats?.classes;
  return{id:object.id,lifetime:this.identity(object),objectType:object.objectType,equipment,monk:classes?classes.some(row=>row.id===5):null,hitDistance:appearance===undefined?null:value('appearance',appearance,'HITDIST'),preferredDistance:appearance===undefined?null:value('appearance',appearance,'PREFATCKDIST'),weaponScale:appearance===undefined?null:value('appearance',appearance,'WEAPONSCALE'),targetHeight:appearance===undefined?'':nativeStringEntry(rules.appearance,appearance,'TARGETHEIGHT').value??'',abortOnParry:appearance===undefined?null:intEntry(rules.appearance,appearance,'ABORTONPARRY').value,facingTarget:object.replicated?.facingTarget??0x7f000000,hitPoints:object.replicated?.hitPoints?.current??null,animationSpeed:object.replicated?.animationSpeed??1,base:object.replicated?.animation??0};
 }
 async flush(){const scope=this.scope();if(this.area!==scope.areaId||this.generation!==scope.generation){this.reset();this.area=scope.areaId;this.generation=scope.generation;}const epoch=this.epoch,rules=await this.tables();if(epoch!==this.epoch||!this.current(scope))return;
  const actors=[...this.session.world.registry.objects.values()].filter(o=>[5,9,10].includes(o.objectType)&&o.areaId===scope.areaId&&!o.replicationRemoved).map(o=>this.actor(o,rules));const signature=JSON.stringify(actors);
  if(signature!==this.signature){this.signature=signature;this.send({kind:'combat-actors',connection:this.connection,...scope,actors});}
  const ready=this.pending;this.pending=[];const events=ready.filter(row=>this.current(row.scope)&&row.actor===this.session.world.registry.get(row.event.id)&&!row.actor.replicationRemoved).map(row=>({...row.event,lifetime:this.identity(row.actor),ageMs:Math.max(0,Math.trunc(this.now()-row.at))}));
  if(events.length)this.send({kind:'combat-events',connection:this.connection,...scope,events});
 }
}
