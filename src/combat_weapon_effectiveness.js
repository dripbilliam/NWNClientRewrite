import { currentAttackWeapon, attackWeapon } from './combat_weapon.js';
import { itemPropertyByType } from './combat_on_hit.js';

const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native weapon effectiveness provider ${name} is unavailable`);return p[name];};
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native weapon effectiveness ${name} is unavailable`);return v|0;};
// GetIsWeaponEffective 140391570..16a8. Both simulations run before the
// sum gate. Main-hand fallback uses GetCurrentAttackWeapon(0), which may
// consume natural-weapon selection RNG again. Never substitute the record.
export async function weaponEffective(actor,targetId,offhand,items,rules,p){
  targetId=integer(targetId,'target ID')>>>0;offhand=integer(offhand,'offhand flag');
  const object=await required(p,'object')(targetId);
  const target=object?await required(p,'asObject')(object):null;
  if(target&&Number(target.plot)===1)return 0;
  const physical=integer(await required(p,'damageRoll')(actor,target,offhand),'physical damage');
  // CalculateMaxElementalDamage 1403e2430 ignores its offhand argument;
  // only a non-null exact-zero plot object runs the energy/maximize query.
  const elemental=target&&Number(target.plot)===0?
    integer(await required(p,'elemental')(actor,target),'elemental damage'):0;
  if(((physical+elemental)|0)>0)return 1;
  const weapon=offhand!==0?attackWeapon(items,rules,true):currentAttackWeapon(items,rules,0,()=>required(p,'weaponAttackType')(actor));
  return Number(itemPropertyByType(weapon,82)!==null);
}
