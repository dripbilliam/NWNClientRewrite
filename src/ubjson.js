// CNWMessage WriteJSON2db680/ReadJSON2d9f40 use nlohmann UBJSON, not JSON text.
// Keep integral64-bit values as BigInt when a Number would lose bits.
const utf8=new TextEncoder(),text=new TextDecoder('utf-8',{fatal:true});
export function decodeUbjson(input){
 const bytes=input instanceof Uint8Array?input:new Uint8Array(input),view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);let cursor=0,nodes=0;
 const need=n=>{if(!Number.isSafeInteger(n)||n<0||n>bytes.length-cursor)throw Error('Truncated NUI UBJSON');},byte=()=>{need(1);return bytes[cursor++];};
 const marker=()=>{let m=byte();while(m===78)m=byte();return m;};
 const scalar=m=>{let v;switch(m){case 85:return byte();case 105:v=byte();return v>127?v-256:v;case 73:need(2);v=view.getInt16(cursor);cursor+=2;return v;case 108:need(4);v=view.getInt32(cursor);cursor+=4;return v;case 76:need(8);v=view.getBigInt64(cursor);cursor+=8;return v>=BigInt(Number.MIN_SAFE_INTEGER)&&v<=BigInt(Number.MAX_SAFE_INTEGER)?Number(v):v;case 100:need(4);v=view.getFloat32(cursor);cursor+=4;return Number.isFinite(v)?v:null;case 68:need(8);v=view.getFloat64(cursor);cursor+=8;return Number.isFinite(v)?v:null;default:throw Error('Invalid NUI UBJSON number marker');}};
 const length=()=>{const n=scalar(marker());if(typeof n==='bigint'||!Number.isSafeInteger(n)||n<0||n>64*1024*1024)throw Error('Invalid NUI UBJSON length');return n;};
 const string=()=>{const n=length();need(n);const s=text.decode(bytes.subarray(cursor,cursor+n));cursor+=n;return s;};
 const value=(m=marker(),depth=0)=>{if(depth>512||++nodes>64*1024*1024)throw Error('NUI UBJSON nesting limit');if(m===90)return null;if(m===84)return true;if(m===70)return false;if(m===67){const c=byte();if(c>127)throw Error('Invalid NUI UBJSON character');return String.fromCharCode(c);}if(m===83)return string();if(m===72){const s=string();if(!/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[Ee][+-]?\d+)?$/.test(s))throw Error('Invalid NUI high-precision number');if(/^-?\d+$/.test(s)){const n=BigInt(s);return n>=BigInt(Number.MIN_SAFE_INTEGER)&&n<=BigInt(Number.MAX_SAFE_INTEGER)?Number(n):n;}const n=Number(s);return Number.isFinite(n)?n:null;}
  if(m!==91&&m!==123)return scalar(m);
  const array=m===91,end=array?93:125,result=array?[]:{};let type=null,count=null;
  if(bytes[cursor]===36){cursor++;type=byte();if(![90,84,70,85,105,73,108,76,100,68,67,83,72,91,123].includes(type))throw Error('Invalid NUI UBJSON container type');if(bytes[cursor]!==35)throw Error('Typed NUI UBJSON container needs a count');}
  if(bytes[cursor]===35){cursor++;count=length();}
  let i=0;while(count===null?bytes[cursor]!==end:i<count){if(cursor>=bytes.length&&!(count!==null&&[90,84,70].includes(type)))throw Error('Truncated NUI UBJSON container');const key=array?i:string(),v=value(type??marker(),depth+1);if(array)result.push(v);else Object.defineProperty(result,key,{value:v,writable:true,enumerable:true,configurable:true});i++;}
  if(count===null){need(1);cursor++;}return result;
 };
 const result=value();while(bytes[cursor]===78)cursor++;if(cursor!==bytes.length)throw Error('Trailing NUI UBJSON data');return result;
}
export function encodeUbjson(value){
 const chunks=[];let size=0;const push=b=>{size+=b.length;if(size>64*1024*1024)throw Error('NUI UBJSON exceeds message storage');chunks.push(b);},tag=c=>push(Uint8Array.of(c));
 const integer=n=>{n=BigInt(n);let marker,length;if(n>=0n&&n<=255n){marker=n<128n?105:85;length=1;}else if(n>=-128n&&n<=127n){marker=105;length=1;}else if(n>=-32768n&&n<=32767n){marker=73;length=2;}else if(n>=-2147483648n&&n<=2147483647n){marker=108;length=4;}else if(n>=-9223372036854775808n&&n<=9223372036854775807n){marker=76;length=8;}else{tag(72);string(String(n));return;}tag(marker);const b=new Uint8Array(length),d=new DataView(b.buffer);if(length===1)b[0]=Number(BigInt.asUintN(8,n));else if(length===2)d.setInt16(0,Number(n));else if(length===4)d.setInt32(0,Number(n));else d.setBigInt64(0,n);push(b);};
 const string=s=>{const b=utf8.encode(s);integer(b.length);push(b);};const ancestors=new Set();
 const write=(v,depth)=>{if(depth>512)throw Error('NUI UBJSON nesting limit');if(v===null){tag(90);return;}if(typeof v==='boolean'){tag(v?84:70);return;}if(typeof v==='bigint'){integer(v);return;}if(typeof v==='number'){if(!Number.isFinite(v)){tag(90);return;}if(Number.isSafeInteger(v)&&!Object.is(v,-0)){integer(v);return;}tag(68);const b=new Uint8Array(8);new DataView(b.buffer).setFloat64(0,v);push(b);return;}if(typeof v==='string'){tag(83);string(v);return;}if(typeof v!=='object'||ancestors.has(v))throw Error('Invalid NUI JSON value');ancestors.add(v);if(Array.isArray(v)){tag(91);for(const e of v)write(e,depth+1);tag(93);}else{tag(123);for(const key of Object.keys(v).sort()){string(key);write(v[key],depth+1);}tag(125);}ancestors.delete(v);};write(value,0);const bytes=new Uint8Array(size);let offset=0;for(const b of chunks){bytes.set(b,offset);offset+=b.length;}return bytes;
}
