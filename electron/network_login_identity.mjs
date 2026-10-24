import {createHash} from 'node:crypto';
import {encodeGffText,decodeGffText} from '../src/gff_text.js';

// CDUtil::UnScrambleKey14010fab0. This extracts the public identifier; CRC/key
// ownership validation remains separate and the real server authorizes login.
export function publicCdKey(key){
 if(typeof key!=='string'||key.length!==41||key.includes('\0'))return'';
 let stage=0,material=0,publicPart='',check=0;
 for(let i=0;i<41;i++){
  const c=key[i];if(c==='-')continue;
  if(stage===0){stage=1;if(material<=19){material++;continue;}}
  if(stage===1){stage=2;if(material>12&&check<7){check++;continue;}}
  else if(stage!==2)continue;
  stage=0;if(publicPart.length<8)publicPart+=c;else if(material<20||check<7)i--;
 }
 return publicPart;
}
const encoded=value=>{if(typeof value!=='string')throw new Error('Native login text is unavailable');try{return Buffer.from(encodeGffText(value));}catch{throw new Error('NWN login text encoding is unsupported');}};
const digest=(...parts)=>{const hash=createHash('md5');for(const bytes of parts)hash.update(bytes);return hash.digest('hex');};

// Secrets live in private main-process buffers, never renderer state, public
// object fields, diagnostic context or JSON captures. This identity never persists
// credentials; optional OS-protected storage is owned by ClientSettings.
export class NetworkLoginIdentity{
 #key;#password;#community;#public;#disposed=false;
 constructor({cdKey,password='',communityPassword=''}){
  if(typeof cdKey!=='string')throw new Error('NWN CD key is unavailable');
  const normalized=cdKey.toUpperCase(),identifier=publicCdKey(normalized);
  if(identifier.length!==8)throw new Error('Invalid NWN CD-key format');
  this.#key=encoded(normalized);this.#password=encoded(password);this.#community=encoded(communityPassword);this.#public=identifier;
 }
 get publicKey(){if(this.#disposed)throw new Error('NWN login identity is disposed');return this.#public;}
 respond(challenge){
  if(this.#disposed)throw new Error('NWN login identity is disposed');
  if(challenge.kind!=='challenge')throw new Error('Native login challenge is unavailable');
  // HandleBNCR23edf0: public8 + MD5(full key + key challenge).
  // GenerateCommunityNameResponse109b80: MD5(MD5(password) + challenge).
  const keyResponse=this.#public+digest(this.#key,encoded(challenge.keyChallenge));
  const communityResponse=digest(Buffer.from(digest(this.#community),'ascii'),encoded(challenge.communityChallenge));
  const passwordResponse=challenge.passwordRequired&&this.#password.length?digest(this.#password,encoded(challenge.passwordChallenge)):'';
  return{keyResponse,communityResponse,passwordResponse,connectionError:challenge.passwordRequired&&!this.#password.length?3:0};
 }
 toJSON(){return{kind:'nwn-login-identity',disposed:this.#disposed};}
 forPortal(password){
  if(this.#disposed)throw new Error('NWN login identity is disposed');
  const next=new NetworkLoginIdentity({cdKey:decodeGffText(this.#key),password});next.#community.fill(0);next.#community=Buffer.from(this.#community);return next;
 }
 dispose(){this.#key.fill(0);this.#password.fill(0);this.#community.fill(0);this.#public='';this.#disposed=true;}
}
