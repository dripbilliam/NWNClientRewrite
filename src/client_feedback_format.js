import {CLIENT_FEEDBACK_DESCRIPTORS} from './client_feedback_descriptors.js';
import {OBJECT_INVALID} from './game_object_array.js';
export const defaultFeedbackColor=String.fromCharCode(60,99,255,255,1,62);

// Direct template/token-copy branches of native6cb2e0. Other branches require
// their rule, arithmetic, floating-text or GUI owners; never invent a result.
export async function formatClientFeedback(message,p){
 const descriptor=CLIENT_FEEDBACK_DESCRIPTORS[message.type];if(!descriptor)return null;
 const data=message.data;
 for(const recipe of descriptor.tokens){
  let value;
  if(recipe.kind==='integer')value=String((data.integers[recipe.slot]??0)|0);
  else if(recipe.kind==='string')value=await p.string(data.strings[recipe.slot]??{text:''});
  else if(recipe.kind==='tlk')value=await p.tlk(recipe.ref);
  else{value=await p.name(data.objects[recipe.slot]??OBJECT_INVALID);if(value===null)value=await p.tlk(8349);}
  await p.token(recipe.id,value);
 }
 const content=descriptor.kind==='parse'?await p.parse(descriptor.ref,descriptor.parseOptions):descriptor.kind==='tlk'?await p.tlk(descriptor.ref):await p.string(data.strings[descriptor.slot]??{text:''});
 return{raw:content?(message.color||defaultFeedbackColor)+content+'</c>':'',flags:128,type:message.type};
}
