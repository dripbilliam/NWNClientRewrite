import {encodeGffText} from './gff_text.js';
const f=Math.fround;
const integer=(data,name,fallback)=>{const v=data[name]??fallback;if(!Number.isInteger(v))throw new Error(`Native area property INT ${name} is unavailable`);return v|0;};
const float=(data,name,fallback)=>{const v=data[name]??fallback;if(typeof v!=='number')throw new Error(`Native area property FLOAT ${name} is unavailable`);return f(v);};
const bytes=value=>{if(typeof value!=='string')throw new Error('Native area property string is unavailable');const raw=encodeGffText(value);return raw[0]===0?new Uint8Array():raw;};

// CNWSAmbientSound ctor1403584a0..1403584f0. Field30 is the real area ID.
export function initializeAmbientMessageState(areaId){
 if(!Number.isInteger(areaId))throw new Error('Native ambient area ID is unavailable');
 return{nativeMessageFields:{8:1,12:5000,16:2,20:3,24:0,28:1,32:1,36:1,40:2,44:0,45:0,48:areaId>>>0}};
}
// Load140358610..140358746 uses INT getters, including byte volumes, and
// returns the final AmbientSndNitVol getter status rather than unconditional1.
export function loadAmbientMessageState(ambient,data){
 const values=ambient.nativeMessageFields;
 for(const [offset,name]of [[12,'MusicDelay'],[16,'MusicDay'],[20,'MusicNight'],[28,'MusicBattle'],[36,'AmbientSndDay'],[40,'AmbientSndNight'],[44,'AmbientSndDayVol'],[45,'AmbientSndNitVol']]){
  values[offset]=integer(data,name,values[offset]);if(offset===44||offset===45)values[offset]&=255;
 }
 return Number(Object.hasOwn(data,'AmbientSndNitVol')&&data.AmbientSndNitVol!==undefined&&data.AmbientSndNitVol!==null);
}

// LoadGrass140361330..14036171b. Loading overlays existing keys; absent list
// does not clear the native container. Material IDs narrow to BYTE before its
// uint32 key lookup, and duplicate entries overwrite the entire stored value.
export function loadGrassMessageState(area,data){
 area.nativeMessageFields[0x368]=Number((integer(data,'GrassDefDisabled',0)&255)!==0);
 const list=data.GrassOverrides?.GrassOvrList;if(list===undefined)return;
 if(!Array.isArray(list))throw new Error('Native grass override list is unavailable');
 for(const entry of list){
  if(!entry||typeof entry!=='object')throw new Error('Native grass override structure is unavailable');
  const key=integer(entry,'GrassMaterialId',0)&255,values={[0x10]:key};
  for(const [offset,name]of [[0x28,'GrassDensity'],[0x2c,'GrassHeight'],[0x30,'GrassAmbientX'],[0x34,'GrassAmbientY'],[0x38,'GrassAmbientZ'],[0x3c,'GrassDiffuseX'],[0x40,'GrassDiffuseY'],[0x44,'GrassDiffuseZ']])values[offset]=float(entry,name,0);
  area.nativeMessageGrassMap370.set(key,{nativeMessageFields:values,nativeName18:bytes(entry.GrassTexture??'')});
 }
}

// CNWSArea::LoadProperties140361dd0..140362252, struct AreaProperties.
// Direction constants are exact binary f32 values at140ddbb40/44/48.
export function loadAreaMessageProperties(area,git){
 const data=git.AreaProperties;if(data===undefined||data===null)return 0;
 if(typeof data!=='object'||Array.isArray(data))throw new Error('Native GIT AreaProperties structure is unavailable');
 const values=area.nativeMessageFields;
 for(const [offset,name,kind]of [[0x34c,'EnvAudio','int'],[0xe0,'SkyBox','byte'],[0xa0,'MoonFogColor','dword'],[0xc0,'SunFogColor','dword'],[0xa4,'MoonFogAmount','byte'],[0xc4,'SunFogAmount','byte'],[0x98,'MoonAmbientColor','dword'],[0x9c,'MoonDiffuseColor','dword'],[0xb8,'SunAmbientColor','dword'],[0xbc,'SunDiffuseColor','dword']]){
  const value=integer(data,name,values[offset]);values[offset]=kind==='byte'?value&255:kind==='dword'?value>>>0:value;
 }
 if(Object.hasOwn(data,'DisplayName')&&data.DisplayName!==undefined&&data.DisplayName!==null){
  const name=bytes(data.DisplayName);area.nativeCustomName358=name.length?name:null;area.nativeCustomNameLength360=name.length;
 }
 for(const [offset,name]of [[0xe8,'WindDirectionX'],[0xec,'WindDirectionY'],[0xf0,'WindDirectionZ'],[0xf4,'WindMagnitude'],[0xf8,'WindYaw'],[0xfc,'WindPitch']])values[offset]=float(data,name,0);
 if(Object.hasOwn(data,'WindPitch')&&data.WindPitch!==undefined&&data.WindPitch!==null){values[0xe4]=3;area.nativeWindPowerE4=3;}
 const defaults=[0.43322429060935974,0.4873773157596588,0.7581425309181213];
 for(const [start,prefix]of [[0xac,'MoonDirection'],[0xcc,'SunDirection']])for(let i=0;i<3;i++)values[start+i*4]=float(data,prefix+['X','Y','Z'][i],defaults[i]);
 loadGrassMessageState(area,data);return loadAmbientMessageState(area.nativeAmbientSound328,data);
}
