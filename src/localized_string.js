import {nativeAssignedString} from './native_gff_fields.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native localized string ${n} is unavailable`);return v|0;};
// Complete CExoLocString::GetString140169920..140169ae5. Internal list
// lookup and TLK FetchInternal are lower owners. Failure retains the caller's
// output; a successful empty TLK result may search other embedded languages.
export async function getLocalizedString(loc,language,out,gender,translate,p){
 language=integer(language,'language');gender=integer(gender,'gender')&255;translate=Boolean(translate);
 const selected=language===0?0:gender;
 if(await p.internal(loc,(Math.imul(language,2)+selected)|0,out)!==0)return 1;
 if(translate&&language!==0&&await p.internal(loc,(Math.imul(language,2)+Number(gender!==1))|0,out)!==0)return 1;
 if(!p.hasTalkTable())return 0;
 p.setGender(selected);const fetched=await p.fetch(integer(loc.strRef,'StrRef')>>>0,0);
 if(fetched.status===0)return 0;
 if(typeof fetched.text!=='string')throw new Error('Native localized string fetched text is unavailable');
 out.value=nativeAssignedString(fetched.text);
 if(translate&&out.value.length===0){
  if(await p.internal(loc,0,out)===0){
   for(const g of [gender,Number(gender!==1)])for(const l of [1,2,3,4])if(await p.internal(loc,l*2+g,out)!==0)return 1;
  }
 }
 return 1;
}
