import {objectTemplateResRef} from './create_object.js';
// Complete CNWBaseItem GetIconResRef14029dc80..14029dd31 and
// GetModelResRef14029dd90..14029de41. ABI: hidden CResRef result in RDX,
// component BYTE R8, model SHORT R9, gender CHAR on the stack.
export function baseItemReference(info,icon,component,model,gender){
 component&=255;model=model<<16>>16;gender=gender<<24>>24;let part;
 if(info.modelType===2){if(component>=3)throw new Error('Native base-item component reads beyond its three-byte character table');part='BMT'.charCodeAt(component);}
 else if(info.genderSpecific!==0&&gender!==0)part=gender;
 const number=model<0?'-'+String(-model).padStart(2,'0'):String(model).padStart(3,'0'),text=(icon?'i':'')+info.itemClass+(part===undefined?'_':'_'+String.fromCharCode(part&255)+'_')+number;
 return objectTemplateResRef(text);
}
