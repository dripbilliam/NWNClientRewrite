import {OBJECT_INVALID} from './game_object_array.js';
import {defaultFeedbackColor} from './client_feedback_format.js';

// Original6cb2e0 cases93/94 ->766a70 ->CGuiInGameFloatyText. These are
// server-script prompts, independent of the combat floating-feedback option.
export async function presentScriptFloatingFeedback(message,p){
 if(message.type!==93&&message.type!==94)return false;
 const data=message.data,raw=message.type===93?await p.parse((data.integers?.[0]??0)>>>0,{nativeB8:0,nativeBC:0}):await p.string(data.strings?.[0]??{text:''});
 const objectId=data.objects?.[0]??OBJECT_INVALID;
 if(p.creature(objectId))p.floating({objectId,raw,rgb:[1,1,1],font:'fnt_galahad14',flags:0});
 if(data.integers?.[message.type===93?1:0]===1)await p.display(raw?(message.color||defaultFeedbackColor)+raw+'</c>':'',128);
 return true;
}
