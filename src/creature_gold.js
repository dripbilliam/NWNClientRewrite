const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native gold ${name} is unavailable`);return value|0;};
// SetGold1403a3180 uses a signed upper cap, preserving negative INTs.
export function setCreatureGold(actor,value){actor.nativeGold898=Math.min(integer(value,'value'),999999999)|0;if(actor.stats)actor.stats.gold=actor.nativeGold898;}
// AddGold14037eda0. Positive sum comparison is unsigned after DWORD wrap;
// negative removal uses unsigned magnitude and caps at the available balance.
export async function addCreatureGold(actor,amount,feedback,p){
  amount=integer(amount,'amount');feedback=integer(feedback,'feedback flag');
  const old=integer(actor.nativeGold898,'stored balance'),sum=(old+amount)|0;
  if(amount>0&&(sum>>>0)>999999999){amount=(999999999-old)|0;actor.nativeGold898=999999999;}
  else{if(amount<0&&(old>>>0)<((-amount)>>>0))amount=(-old)|0;actor.nativeGold898=(old+amount)|0;}
  if(actor.stats)actor.stats.gold=actor.nativeGold898;
  if(feedback===1&&amount!==0){if(typeof p?.feedback!=='function')throw new Error('Native gold feedback owner is unavailable');await p.feedback(actor,148,{integers:[amount]});}
}

// RemoveGold14039e9b0 is NOT AddGold(-amount): negative input can increase
// without an upper cap, and overdraft feedback reports amount-old balance.
export async function removeCreatureGold(actor,amount,feedback,p){
  amount=integer(amount,'removal amount');feedback=integer(feedback,'feedback flag');const old=integer(actor.nativeGold898,'stored balance');
  if(amount<1||(amount>>>0)<=(old>>>0))actor.nativeGold898=(old-amount)|0;
  else{amount=(amount-old)|0;actor.nativeGold898=0;}
  if(actor.stats)actor.stats.gold=actor.nativeGold898;
  if(feedback===1&&amount!==0){if(typeof p?.feedback!=='function')throw new Error('Native gold feedback owner is unavailable');await p.feedback(actor,149,{integers:[amount]});}
}
