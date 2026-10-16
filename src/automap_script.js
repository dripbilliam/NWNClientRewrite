// Decoded argument bodies of native VM owners14051d830,140548aa0,
// 140510f30. Stack type/underflow and push errors belong to NwScriptVm.
export async function scriptExploreArea([areaId,playerId,value=1],p){
 const area=await p.area(areaId>>>0),client=await p.client(playerId>>>0),actor=await p.creature(playerId>>>0);
 if(area&&client&&actor)await p.reveal(actor,areaId>>>0,Number((value|0)!==0));
}
export async function scriptTileExploration(command,[creatureId,areaId,x,y,value],p){
 let result=-1;const a=await p.object(areaId>>>0),o=await p.object(creatureId>>>0);
 if((x>>>0)<32&&(y>>>0)<32&&a&&o){
  const area=await p.asArea(a),actor=await p.asCreature(o);
  if(area&&actor){result=await p.explored(actor,area.id,x|0,y|0);if(command===866)await p.setTile(actor,area.id,x|0,y|0,value|0);}
 }
 return result;
}
export async function scriptAutomapExploration(command,[id,value],p){
 let result=-1;const o=await p.object(id>>>0);
 if(o&&await p.asCreature(o)){
  result=(await p.asCreature(o)).nativeAutoMapEnabled6e0|0;
  if(command===868)(await p.asCreature(o)).nativeAutoMapEnabled6e0=value|0;
 }
 return result;
}
