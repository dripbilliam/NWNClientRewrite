// GetMeetsPrestigeClassRequirements140403810..1404041bb. Providers describe
// the creature BEFORE taking the candidate class/level. Requirements are exact
// case-sensitive strings; RACE, FEATOR and CLASSOR each form an OR group.
const i8=value=>(value<<24)>>24;
export function meetsClassPrerequisites(requirements,p){
 let races=null,feats=null,classes=null;
 for(const row of requirements){
  const type=row.ReqType,a=Number(row.ReqParam1),b=Number(row.ReqParam2);let pass=true;
  switch(type){
   case 'SKILL':pass=i8(p.skillRank(a&255))>=b;break;
   case 'FEAT':pass=Boolean(p.hasFeat(a&65535));break;
   case 'RACE':races=Boolean(races||p.race===a);break;
   case 'FEATOR':feats=Boolean(feats||p.hasFeat(a&65535)===1);break;
   case 'BAB':pass=p.baseAttackBonus>=a;break;
   case 'SPELL':pass=p.classes.some(c=>c.spellCaster&&c.level>=a);break;
   case 'ARCSPELL':pass=p.classes.some(c=>c.arcane&&c.level>=a);break;
   case 'VAR':pass=typeof row.ReqParam1==='string'&&row.ReqParam1!==''&&row.ReqParam1!=='****'&&p.getInt(row.ReqParam1)===b;break;
   case 'CLASSNOT':pass=!p.classes.some(c=>c.id===a);break;
   case 'CLASSOR':classes=Boolean(classes||p.classes.some(c=>c.id===a));break;
   case 'SAVE':pass=![1,2,3].includes(a)||i8(p.baseSave(a))>=b;break;
   // The original dispatch ignores unrecognized strings, including different
   // case. It does not treat a nonempty prerequisite table as a class ban.
  }
  if(!pass)return false;
 }
 return races!==false&&feats!==false&&classes!==false;
}
