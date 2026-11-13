import {StringDecoder} from 'node:string_decoder';

// Sticky classification is separate from the bounded human-readable log tail.
// Keep bounded context per line, including chunk-split markers and UTF-8 input.
export class NativeReplayDiagnostics {
 constructor(){this.decoder=new StringDecoder('utf8');this.prefix='';this.carry='';this.objectDb=false;this.kinds=new Set();this.bytes=0;this.closed=false;}
 write(data){
  if(this.closed)throw Error('Native diagnostic stream already ended');
  const bytes=Buffer.isBuffer(data)?data:Buffer.from(data);this.bytes+=bytes.length;
  this.scan(this.decoder.write(bytes));
 }
 scan(text){
  const parts=text.split('\n');
  for(let index=0;index<parts.length;index++){
   const part=parts[index],joined=this.carry+part;
   this.prefix=(this.prefix+part).slice(0,64);
   if(/^ERROR:/.test(this.prefix))this.kinds.add('engine-error');
   if(joined.includes('SCRIPT ERROR'))this.kinds.add('script-error');
   if(joined.includes('Parse Error'))this.kinds.add('parse-error');
   if(joined.includes('resources still in use'))this.kinds.add('resources-in-use');
   this.objectDb ||= joined.includes('ObjectDB');
   if(this.objectDb&&/leak/i.test(joined))this.kinds.add('objectdb-leak');
   this.carry=joined.slice(-64);
   if(index<parts.length-1){this.prefix='';this.carry='';this.objectDb=false;}
  }
 }
 end(){if(!this.closed){this.scan(this.decoder.end());this.closed=true;}return this.snapshot();}
 snapshot(){return {detected:this.kinds.size>0,kinds:[...this.kinds].sort(),bytes:this.bytes,closed:this.closed,scope:'Sticky classification across the complete observed byte stream; bounded marker context, not full log retention or exact error counts'};}
}
