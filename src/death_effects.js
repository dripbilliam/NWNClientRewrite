const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native death ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native death provider ${name} is unavailable`);return p[name];};

// OnApplyDeath14042aedc..14042aff2 selects body3/animation8 or body4/6.
// Already-dead body3/4 keeps its existing pose. Creator is the ORIGINAL
// creature source, queried before a self-kill substitutes LastDamager for XP.
export function deathAnimation(actor,creator){
  if(((integer(actor.nativeBodyState,'body state')&255)-3&255)<=1)return null;
  let forward=true;
  if(creator){
    if(![actor,creator].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(Number.isFinite))||
      !Array.isArray(actor.orientation)||actor.orientation.length!==3||!actor.orientation.every(Number.isFinite))throw new Error('Native death orientation is unavailable');
    const f=Math.fround,direction=normalizeOrientation(creator.position.map((v,i)=>f(f(v)-f(actor.position[i])))),orientation=normalizeOrientation(actor.orientation);
    const dot=f(f(f(direction[2]*orientation[2])+f(direction[0]*orientation[0]))+f(direction[1]*orientation[1]));
    // Native promotes this float dot to DOUBLE before comparing .707.
    forward=dot>=.707;
  }
  return {body:forward?3:4,animation:forward?8:6};
}

// OnApplyDeath14042ab6b..14042ac95. Query immunity before testing spell ID;
// +108 bypass is an INT, independent of the subtype and spell source.
export async function deathBlockedByImmunity(actor,effect,p){
  if((integer(effect.subtype,'effect subtype')&56)!==8||integer(effect.bypassImmunity,'effect bypass')!==0)return false;
  const creator=await required(p,'creature')(effect.creatorId);
  if(await required(p,'immunity')(actor,32,creator,1)===0||integer(effect.spellId,'effect spell ID')===-1)return false;
  const data={type:0,objects:[actor.id]};
  if(creator)await required(p,'feedback')(creator,127,structuredClone(data));
  await required(p,'feedback')(actor,127,data);
  return true;
}

// OnApplyDeath14042b12b..14042b2b4. The Type_FD comparison is BYTE 'B'
// followed by NUL, not a guessed visual category. Failed GetSTRINGEntry does
// not preserve a visual even when the table default contains B.
export function preserveDeathEffect(effect,p){
  const duration=integer(effect.durationType,'effect duration')&7,type=integer(effect.type,'effect type')&65535;
  if(duration===3||duration===4||type===32)return true;
  if(type===30){
    const visual=integer(effect.integers?.[0]??0,'visual integer');
    const entry=required(p,'visualType')(visual);
    if(entry.found&&typeof entry.value==='string'&&entry.value.split('\0')[0]==='B')return true;
  }
  return(integer(effect.subtype,'effect subtype')&56)===32&&![8,9,23].includes(type);
}
export function deathVisualType(table,index){
  if(!table)throw new Error('Native death visualeffects.2da is unavailable');
  index=integer(index,'visual index');
  const column=table.columns.find(c=>c.toLowerCase()==='type_fd'),row=table.orderedRows?table.orderedRows[index]:[...table.rows.values()][index];
  if(!row||!column)return{found:false,value:table.defaultValue??''};
  const value=row[column];return value===undefined||value===''||value==='****'?{found:false,value:''}:{found:true,value};
}
import {normalizeOrientation} from './combat_lifecycle.js';
