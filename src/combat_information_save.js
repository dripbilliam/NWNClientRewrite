import {gffField as f,gffRecord as record} from './gff_writer.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native combat save ${n} is unavailable`);return v|0;};
const signed=v=>(v<<24)>>24;
const scalarFields=[['NumAttacks',0,0],['OnHandAttackMod',1,1],['OnHandDamageMod',2,1],['OffHandAttackMod',3,1],['OffHandDamageMod',4,1],
 ['SpellResistance',5,0],['ArcaneSpellFail',6,0],['ArmorCheckPen',7,0],['UnarmedDamDice',8,0],['UnarmedDamDie',9,0],
 ['OnHandCritRng',19,0],['OnHandCritMult',20,0],['OffHandWeaponEq',24,0],['OffHandCritRng',28,0],['OffHandCritMult',29,0]];
// Complete CCombatInformation::SaveData1402ad6d0..1402add58.
// Flags in the shared owner name the WORD at+68: damage dice/die, not status bits.
export function saveCombatInformation(cache,root){
 if(!cache||cache.disposed||!(cache.scalars instanceof Uint8Array)||cache.scalars.length!==32)throw new Error('Native combat save storage is unavailable');
 const node=record({},0xcaaa),put=(name,type,value)=>{node.fields[name]=f(type,value);};root.fields.CombatInfo=f(14,node);
 for(const [name,offset,type]of scalarFields){
  if(cache.initialized?.[offset]!==1)throw new Error(`Native combat save scalar ${offset} is uninitialized`);
  put(name,type,type===1?signed(cache.scalars[offset]):cache.scalars[offset]);
 }
 put('LeftEquip',4,integer(cache.weaponIds?.[1],'left weapon ID')>>>0);put('RightEquip',4,integer(cache.weaponIds?.[0],'right weapon ID')>>>0);
 for(let i=0;i<3;i++)for(const [name,offset]of [['CreatureDice',10],['CreatureDie',13]]){
  if(cache.initialized?.[offset+i]!==1)throw new Error(`Native combat save scalar ${offset+i} is uninitialized`);
  put(`${name}${i}`,0,cache.scalars[offset+i]);
 }
 for(const [name,index]of [['LeftString',1],['RightString',0]]){
  const text=cache.text?.[index];if(typeof text!=='string')throw new Error('Native combat save weapon name is unavailable');put(name,10,text);
 }
 const damage=integer(cache.flags,'damage dice/die');put('DamageDice',0,damage&255);put('DamageDie',0,damage>>>8&255);
 for(const [name,key,type]of [['AttackList','attackNodes',0xaaee],['DamageList','damageNodes',0xddee]]){
  const source=cache[key];if(!Array.isArray(source))throw new Error('Native combat save node list is unavailable');
  const entries=[];put(name,15,entries);
  for(const bytes of source){
   if(!(bytes instanceof Uint8Array)||bytes.length!==6)throw new Error('Native combat save node storage is unavailable');
   const fields={Modifier:f(1,signed(bytes[0]))};
   if(key==='damageNodes')fields.ModifierType=f(0,bytes[1]);
   for(const [label,i]of [['WeaponWield',2],['VersusLawChaos',3],['VersusGoodEvil',4],['VersusRace',5]])fields[label]=f(0,bytes[i]);
   entries.push(record(fields,type));
  }
 }
 return root;
}
