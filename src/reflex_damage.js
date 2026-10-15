const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native Reflex damage ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native Reflex damage provider ${n} is unavailable`);return p[n](...args);};
// ExecuteCommandGetReflexAdjustedDamage14052f790. Modern five args are
// damage,target,DC,category,versus. Legacy four args target,damage,category,
// versus read an uninitialized DC stack cell; live dispatch cannot guess it.
export async function reflexAdjustedDamage(args,p){
  if(args.length<4)throw new Error('Native Reflex damage VM arguments are unavailable');
  const old=args.length===4,damage=integer(args[old?1:0],'damage'),targetId=integer(args[old?0:1],'target')>>>0,
    dc=integer(old?p.dcScratch:args[2],'DC storage'),category=integer(args[old?2:3],'category')&255,versus=integer(args[old?3:4],'versus')>>>0;
  const target=call(p,'creature',targetId);if(!target)return damage;
  let feat=0;if(call(p,'hasFeat',target,212)!==0)feat=212;else if(call(p,'hasFeat',target,206)!==0)feat=206;
  const success=(integer(await call(p,'save',target,2,dc&65535,category,versus,1,feat,0),'save result')&255)!==0;
  let result;
  if(success){result=call(p,'hasFeat',target,212)!==0||call(p,'hasFeat',target,206)!==0?0:Math.trunc(damage/2)|0;}
  else{if(call(p,'hasFeat',target,212)===0)return damage;result=Math.trunc(damage/2)|0;}
  await call(p,'evasionVisual',target,versus);return result;
}
