// Client feat target140703310. Uses requested feat metadata, without the
// server's highest-successor substitution. Child comparison is signed16 here;
// server UseFeat compares against the decoded unsigned auxiliary WORD.
export function prepareFeatTarget(request,p,{autoSelf=1}={}){
 if(!Number.isInteger(request.featId))throw new Error('Native client feat target ID is unavailable');
 const packed=request.featId|0,featId=packed&65535,auxiliary=request.auxiliary??(packed>>>16),info=p.feat(featId);
 if(!info)return {mode:'unavailable'};
 const modes={28:3,19:4,30:7,204:6,899:6,866:6,389:8,390:9,425:11,947:12},binding={...request,featId,auxiliary:auxiliary&65535};
 if(auxiliary===0&&modes[featId]!==undefined)return {mode:'mode',modeId:modes[featId],request:binding};
 if(info.targetSelf!==0&&(autoSelf&255)!==0)return {mode:'self',request:binding};
 let definition={targetType:3};
 if(info.spellId!==-1){
  definition=p.spell(info.spellId);
  if(definition)for(const id of definition.children){const child=p.spell(id>>>0);if(child&&(child.featId>>16)===(auxiliary<<16>>16)){definition=child;break;}}
 }
 const targetTypes=[];
 if(info.spellId===-1)targetTypes.push(5);
 else for(const [bit,type]of [[1,5],[2,5],[4,2],[8,6],[16,10],[32,9],[64,7]])if((definition?.targetType??0)&bit)targetTypes.push(type);
 return {mode:'target',request:binding,definition,targetTypes};
}
// Feat targeting registers creature5 for either creature bit and does not
// install the ordinary spell targeter's separate creature-veto callback.
export function featTargetAllowed(definition,target){
 const mask=definition?.targetType??0;if(!target)return Boolean(mask&4);
 return Boolean(mask&({5:3,6:8,10:16,9:32,7:64}[target.objectType]??0));
}
