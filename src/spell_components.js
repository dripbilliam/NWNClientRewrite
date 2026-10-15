import {rulesetInt} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native cast component ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native cast component provider ${n} is unavailable`);return p[n];};
// Ordinary AIActionCastSpell admission1403ae4e6..1403ae997. Master spell
// metadata gates metamagic. Automatic Still/Silent use strict level<caps;
// raw metamagic equality exempts only32/16, not a mask containing either.
export function checkSpellComponents(actor,spell,index,domain,meta,rules,p){
  meta=integer(meta,'metamagic');domain=integer(domain,'domain level');index=integer(index,'class index')&255;
  const rejected=(feedback=null)=>({accepted:false,clearConsumed:feedback!==null,feedback});
  const master=required(p,'spell')(integer(spell.master,'master spell'));
  if(!master||(meta&255)!==0&&(integer(master.metamagic,'allowed metamagic')&meta&255)===0)return rejected();
  const has=feat=>integer(required(p,'hasFeat')(actor,feat),'feat result')!==0;
  const level=silent=>{
    let value=domain&255;
    if(domain===0||silent&&value===255){const type=required(p,'classType')(actor,index)&255;
      if(domain===0)value=required(p,'level')(spell.id,type)&255;
      if(value===255)value=required(p,'level')(master.id,type)&255;
      if(value===255)value=integer(spell.innate,'innate level')&255;}
    return(value+(required(p,'metamagicCost')(meta&255)&255))&255;
  };
  const automatic=(feats,labels,silent=false)=>{
    const present=feats.map(has);if(!present.some(Boolean))return false;
    const value=level(silent);
    return present.some((enabled,i)=>enabled&&value<rulesetInt(rules,labels[i],[4,7,10][i]));
  };
  const automaticStill=(integer(spell.userType,'user type')&255)===1&&automatic([863,864,865],
    ['EPIC_AUTOMATIC_LESSER_STILL_LEVEL_CAP','EPIC_AUTOMATIC_STILL_LEVEL_CAP','EPIC_AUTOMATIC_GREATER_STILL_LEVEL_CAP']);
  const flags=integer(actor.nativeField8d4,'component state')&65535,components=String(spell.components).split('\0')[0];
  if(components.includes('s')&&(flags&4)===0&&meta!==32&&!automaticStill)return rejected(210);
  const automaticSilent=automatic([860,861,862],
    ['EPIC_AUTOMATIC_LESSER_SILENT_LEVEL_CAP','EPIC_AUTOMATIC_SILENT_LEVEL_CAP','EPIC_AUTOMATIC_GREATER_SILENT_LEVEL_CAP'],true);
  if(components.includes('v')&&(flags&8)===0&&meta!==16&&!automaticSilent)return rejected(211);
  return{accepted:true,automaticStill,automaticSilent};
}

// Automatic Quicken1403aeae2..1403aecb4 has its own level fallback:
// a255 domain level still tries the master using the PREVIOUS context class.
export function automaticQuicken(actor,spell,index,domain,meta,rules,p){
  if((integer(spell.userType,'user type')&255)!==1)return false;
  const feats=[857,858,859],present=feats.map(id=>integer(required(p,'hasFeat')(actor,id),'quicken feat')!==0);
  if(!present.some(Boolean))return false;
  let level=integer(domain,'quicken domain')&255;
  if(domain===0)level=required(p,'level')(spell.id,required(p,'classType')(actor,index&255)&255)&255;
  if(level===255){
    const master=required(p,'spell')(integer(spell.master,'quicken master'));
    if(master)level=required(p,'level')(master.id,required(p,'classType')(actor,integer(actor.nativeSpellClass22c,'previous class')&255)&255)&255;
    if(level===255)level=integer(spell.innate,'quicken innate')&255;
  }
  level=(level+(required(p,'metamagicCost')(meta&255)&255))&255;
  return present.some((enabled,i)=>enabled&&level<rulesetInt(rules,['EPIC_AUTOMATIC_LESSER_QUICKEN_LEVEL_CAP','EPIC_AUTOMATIC_QUICKEN_LEVEL_CAP','EPIC_AUTOMATIC_GREATER_QUICKEN_LEVEL_CAP'][i],[4,7,10][i]));
}
