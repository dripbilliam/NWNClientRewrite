const crcTable=Uint32Array.from({length:256},(_,value)=>{for(let bit=0;bit<8;bit++)value=(value>>>1)^((value&1)?0xedb88320:0);return value>>>0;});
const requireBytes=value=>{if(!(value instanceof Uint8Array))throw new Error('Native talk-token bytes are unavailable');return value;};
const copy=value=>Uint8Array.from(requireBytes(value));
const assigned=value=>value[0]===0?new Uint8Array():copy(value);
const unknown=Uint8Array.from('<UNRECOGNIZED TOKEN>',c=>c.charCodeAt(0));
// CResGFFFieldIDHash::Initialize14018d200 and Hash14018d1a0. This CRC starts
// at0, without final complement, and stops at NUL or the supplied length.
export function talkTokenHash(bytes,count=bytes.length){
 requireBytes(bytes);let hash=0;for(let i=0,end=Math.min(count>>>0,bytes.length);i<end&&bytes[i]!==0;i++)hash=(crcTable[(hash^bytes[i])&255]^(hash>>>8))>>>0;return hash;
}
export function findTalkToken(records,key,field){
 let low=0,high=records.length;while(low<high){const middle=(low+high)>>>1,value=records[middle][field]>>>0;if(value>key)high=middle;else if(value<key)low=middle+1;else return records[middle];}return null;
}
// Complete ParseStr140199e20..19a420 control flow over terminated byte input.
// Named token value resolution is a separate game callback. It may change
// suppression4c; parsing resets that field and does not recursively parse values.
export function parseTalkTokens(input,state,p){
 requireBytes(input);state.suppression4c=0;const nul=input.indexOf(0),end=nul<0?input.length:nul,parts=[];let at=0,segment=0,changed=false;
 const append=value=>{if(value.length)parts.push(copy(value));};
 while(at<end){
  if(input[at]!==60){at++;continue;}
  if(input[at+1]===60){if(state.suppression4c===0)append(input.subarray(segment,at+1));segment=at+2;at+=2;changed=true;continue;}
  if(state.suppression4c===0)append(input.subarray(segment,at));
  // Rich presentation callers preserve fixed-width native color controls.
  // Without this optional boundary the original ParseStr behavior is intact.
  const control=p.controlLength?.(input,at)??0;
  if(control>0&&at+control<=end){if(state.suppression4c===0)append(input.subarray(at,at+control));at+=control;segment=at;changed=true;continue;}
  let close=at+1;while(close<end&&input[close]!==62)close++;
  if(close===end)throw new Error('Native unterminated talk token can read beyond its string buffer');
  const name=input.subarray(at+1,close);let replacement=unknown;
  if(name.length>6&&name[0]===67&&name[1]===85&&name[2]===83&&name[3]===84&&name[4]===79&&name[5]===77){
   let key=0,place=1,valid=true;for(let i=name.length-1;i>=6;i--){const digit=name[i]-48;if(digit<0||digit>9){valid=false;break;}key=(key+Math.imul(digit,place))>>>0;place=Math.imul(place,10)>>>0;}
   if(valid&&key!==0xffffffff){const record=findTalkToken(p.custom,key,'id');if(record)replacement=assigned(requireBytes(record.bytes));}
  }else if(name.length){
   const token=findTalkToken(p.named,talkTokenHash(name),'hash');
   if(token&&token.name.length===name.length&&token.name.every((b,i)=>b===name[i])){
    const value=p.resolve(token,state);if(value!==null)replacement=assigned(requireBytes(value));
   }
  }
  append(replacement);at=close+1;segment=at;changed=true;
 }
 if(!changed)return copy(input);
 if(segment<end&&state.suppression4c===0)append(input.subarray(segment,end));
 const length=parts.reduce((n,b)=>n+b.length,0),result=new Uint8Array(length);let offset=0;for(const part of parts){result.set(part,offset);offset+=part.length;}return assigned(result);
}
