const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native dispel provider ${n} is unavailable`);return p[n](...a);};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native dispel ${n} is unavailable`);return v|0;};
const magical=e=>(integer(e.subtype,'subtype')&0x38)===8&&[1,2].includes(integer(e.durationType,'duration')&7);
const difficulty=e=>(Math.max(0,integer(e.casterLevel,'caster level'))+11)|0;
// OnApplyDispelAllMagic14042c720 / BestMagic14042cbd0. Each uint64 ID is
// tested once, including linked hidden children. Removal is deferred event14;
// the live effect list remains intact throughout the owner's scan.
export async function applyDispel(o,e,p,best=false){
 let level=integer(e.integers?.[0],'requested level'),source=best?null:call(p,'object',e.creatorId);
 if(level<1){source=best?call(p,'object',e.creatorId):source;if(!source||source.objectType!==5)return 1;level=integer(call(p,'level',source),'creature level')&255;}
 const seen=new Set(),removed=[];
 for(;;){
  const rows=call(p,'effects',o),candidates=best?rows.filter(row=>magical(row)&&!seen.has(row.id)).slice(0,1):rows;
  if(candidates.length===0)break;
  for(const row of candidates){
   if(!magical(row)||seen.has(row.id))continue;seen.add(row.id);
   const success=(((integer(await call(p,'roll',1,20),'roll')&65535)+level)|0)>=difficulty(row);
   if(success){
    if(!best)await call(p,'enqueue',14,e.creatorId,o.id,0,{id:row.id});
    if(call(p,'spell',row.spellId))removed.push(row.spellId|0);
    if(best){
     if(removed.length){const client=call(p,'client',o.id);if(client)await call(p,'send',client,15,{objects:[o.id],integers:[1,removed[0]]});}
     await call(p,'enqueue',14,e.creatorId,o.id,0,{id:row.id});return 1;
    }
   }
  }
  if(!best)break;
 }
 if(!best&&removed.length){const data={objects:[o.id],integers:[removed.length,...removed]},target=call(p,'client',o.id);if(target)await call(p,'send',target,15,data);
  if(source&&source.id!==o.id){const client=call(p,'client',source.id);if(client)await call(p,'send',client,15,data);}}
 return 1;
}
