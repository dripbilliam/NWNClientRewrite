const {createHash}=require('node:crypto');

// Manifest data is plain JSON. Keep array encoding native and bounded, and
// never construct a string proportional to the size of the entire area.
function* jsonFragments(value,ancestors=new Set()){
 if(value===null||typeof value!=='object'){
  const text=JSON.stringify(value);if(text===undefined)throw Error('Unsupported manifest value');yield text;return;
 }
 if(ancestors.has(value))throw Error('Circular manifest value');
 ancestors.add(value);
 try{
  if(Array.isArray(value)){
   yield '[';
   for(let start=0;start<value.length;){
    if(start)yield ',';
    // Numeric/string streams dominate skin and controller payloads. Encode
    // primitive runs together rather than yielding once per vertex number.
    let end=start;while(end<value.length&&end<start+1024&&(value[end]===null||typeof value[end]!=='object'))end++;
    if(end>start){yield JSON.stringify(value.slice(start,end)).slice(1,-1);start=end;}
    else{yield* jsonFragments(value[start],ancestors);start++;}
   }
   yield ']';
  }else{
   const proto=Object.getPrototypeOf(value);
   if(proto!==Object.prototype&&proto!==null)throw Error('Manifest must contain plain JSON objects');
   yield '{';let first=true;
   for(const key of Object.keys(value)){
    const child=value[key];if(['undefined','function','symbol'].includes(typeof child))continue;
    if(!first)yield ',';first=false;yield JSON.stringify(key)+':';yield* jsonFragments(child,ancestors);
   }
   yield '}';
  }
 }finally{ancestors.delete(value);}
}

async function writeJson(file,value,{chunkCharacters=256*1024}={}){
 const hash=createHash('sha256');let fragments=[],characters=0,bytes=0,writes=0;
 async function flush(){if(!characters)return;const buffer=Buffer.from(fragments.join(''),'utf8');hash.update(buffer);let offset=0;while(offset<buffer.length){const written=await file.write(buffer,offset,buffer.length-offset);if(!written.bytesWritten)throw Error('Metadata write made no progress');offset+=written.bytesWritten;}bytes+=buffer.length;writes++;fragments=[];characters=0;}
 for(const fragment of jsonFragments(value)){fragments.push(fragment);characters+=fragment.length;if(characters>=chunkCharacters)await flush();}
 fragments.push('\n');characters++;await flush();
 return{sha256:hash.digest('hex'),bytes,writes};
}
module.exports={jsonFragments,writeJson};
