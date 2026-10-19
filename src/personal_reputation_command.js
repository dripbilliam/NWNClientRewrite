import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native personal reputation command ${n} is unavailable`);return v|0;};
// Complete decoded PersonalReputationAccess140537e50. The preliminary clear
// and target lookup happen for every ordinal, including ClearPersonalReputation.
// Neutral appends -100 then50; keep both records and both clears in native order.
export function personalReputationCommand(ordinal,args,self,context,p){
  const actorId=integer(args[0],'owner')>>>0,targetId=args.length>1?integer(args[1],'target')>>>0:context===1?integer(self,'self')>>>0:OBJECT_INVALID,
    decays=args.length>2?integer(args[2],'decay'):0,duration=args.length>3?Math.fround(args[3]):180;
  if(args.length>3&&typeof args[3]!=='number')throw new Error('Native personal reputation duration is unavailable');
  const actor=p.creature(actorId);if(!actor)return;
  p.clear(actor,targetId);p.creature(targetId);
  if(![390,391,392].includes(ordinal))return;
  p.clear(actor,targetId);
  if(ordinal===392)p.add(actor,targetId,-100,decays,duration);
  p.add(actor,targetId,ordinal===390?100:ordinal===391?-100:50,decays,duration);
}
