import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell notification ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell notification provider ${n} is unavailable`);return p[n](...args);};
// EventSpellCastAt14051d3f0 produces ScriptEvent WORD2, two INTs and
// caster object slot0. The optional harmful argument defaults to1.
export function spellCastAtEvent(casterId,spellId,harmful=1){return{type:2,objectIds:[integer(casterId,'caster ID')>>>0],integers:[integer(spellId,'spell ID'),integer(harmful,'harmful flag')]};}

// Creature ScriptEvent2,14038f8a7..14038faa2. Direct creatures and AoE
// creators alone become last casters. Exact harmful==1 writes hostile
// history; EVERY nonzero harmful value takes the combat/reputation branch.
export async function receiveSpellCastAt(actor,payload,p){
  if((integer(payload?.type,'event type')&65535)!==2)throw new Error('Native nonspell notification is unavailable');
  const source=call(p,'object',integer(payload.objectIds?.[0]??OBJECT_INVALID,'source ID')>>>0);let caster=null;
  if(source?.objectType===5)caster=source;
  else if(source?.objectType===11)caster=call(p,'creature',integer(call(p,'areaEffectCreator',source),'AoE creator')>>>0);
  actor.nativeLastSpellCaster230=caster?caster.id>>>0:OBJECT_INVALID;
  actor.nativeLastSpell234=integer(payload.integers?.[0]??0,'spell ID');actor.nativeLastSpellHarmful238=integer(payload.integers?.[1]??0,'harmful flag');
  if(actor.nativeLastSpellHarmful238===1)await call(p,'setLastHostile',actor,actor.nativeLastSpellCaster230,0);
  if(integer(await call(p,'dead',actor),'dead flag')===0){
    const name=call(p,'scriptName',actor,2);
    if(typeof name!=='string')throw new Error('Native spell notification script name is unavailable');
    if(integer(call(p,'pc',actor),'PC result')===0||name!=='default')await call(p,'runScript',actor,2);
  }
  const harmful=integer(actor.nativeLastSpellHarmful238,'current harmful flag')!==0;
  if(harmful){
    caster=call(p,'creature',actor.nativeLastSpellCaster230);
    if(caster){
      await call(p,'broadcastState',caster);await call(p,'initiative',caster);await call(p,'excited',caster,2);await call(p,'removeInvisibility',caster);
      await call(p,'factionReputation',actor,integer(call(p,'faction',caster),'caster faction'),-100);
      if(integer(call(p,'pc',caster),'caster PC result')!==0)await call(p,'associateCommand',caster,-15);
    }
    await call(p,'broadcastState',actor);await call(p,'initiative',actor);await call(p,'excited',actor,1);
  }
  await call(p,'adjustReputations',actor.id,actor.nativeLastSpellCaster230,harmful?0:3);
}
