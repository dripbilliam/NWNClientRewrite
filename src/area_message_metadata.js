import {NativeGrassMap} from './native_grass_map.js';
import {initializeAmbientMessageState} from './area_message_properties.js';
const f=Math.fround;
const read=(data,name,kind,fallback)=>{
 const v=data[name]??fallback;
 if(kind==='float'){if(typeof v!=='number')throw new Error(`Native area FLOAT ${name} is unavailable`);return f(v);}
 if(!Number.isInteger(v))throw new Error(`Native area ${kind} ${name} is unavailable`);
 return kind==='byte'?v&255:kind==='bool'?Number((v&255)!==0):kind==='dword'?v>>>0:v|0;
};

// CArea ctor140296a40..140296b51 and selected CNWSArea constructor fields.
// Sun/moon direction and wind vectors start at0. LoadProperties later reads
// their GIT overrides/defaults; these are not RGB values derived from colors.
export function initializeAreaMessageFields(area){
 const values={};
 for(const offset of [8,0x98,0x9c,0xa0,0xa4,0xa8,0xb8,0xbc,0xc0,0xc4,0xc8,0xd8,0xdc,0xe0,0xe1,0xe2,0xe3,0xe4,0x100,0x10c,0x218,0x34c,0x368,0x380])values[offset]=0;
 for(const offset of [0xac,0xb0,0xb4,0xcc,0xd0,0xd4,0xe8,0xec,0xf0,0xf4,0xf8,0xfc])values[offset]=0;
 values[0xd8]=1;values[0x104]=50;values[0x108]=45;values[0x347]=1;
 area.nativeMessageFields=values;area.nativeMessageGrassMap370=new NativeGrassMap();area.nativeAmbientSound328=initializeAmbientMessageState(area.id);
 Object.defineProperty(area,'nativeMessageGrassEntries',{enumerable:true,configurable:true,get(){return this.nativeMessageGrassMap370.entries;}});
 Object.defineProperty(values,0x380,{enumerable:true,configurable:true,get:()=>area.nativeMessageGrassMap370.size});
}

// Scalar portion of LoadAreaHeader1403600df..140360525. BYTE and BYTEasBOOL
// remain distinct; e.g. NoRest2 stays2, while SunShadows2 becomes1.
export function loadAreaMessageHeader(area,are){
 const values=area.nativeMessageFields;if(!values)throw new Error('Native area message constructor state is unavailable');
 const rules=[
  [8,'Flags','dword',0],[0xe1,'ChanceRain','int',0],[0xe2,'ChanceSnow','int',0],[0x218,'ChanceFog','int',0],[0xe3,'ChanceLightning','int',0],[0xe4,'WindPower','int',0],
  [0x98,'MoonAmbientColor','dword',0],[0x9c,'MoonDiffuseColor','dword',0],[0xa0,'MoonFogColor','dword',0],[0xa4,'MoonFogAmount','byte',0],[0xa8,'MoonShadows','bool',0],
  [0xb8,'SunAmbientColor','dword',0],[0xbc,'SunDiffuseColor','dword',0],[0xc0,'SunFogColor','dword',0],[0xc4,'SunFogAmount','byte',0],[0xc8,'SunShadows','bool',0],
  [0xe0,'SkyBox','byte',values[0xe0]],[0xd8,'DayNightCycle','bool',0],[0xdc,'IsNight','bool',0],[0x347,'PlayerVsPlayer','byte',0],
  [0x100,'NoRest','byte',values[0x100]&255],[0x104,'ShadowOpacity','byte',values[0x104]],[0x346,'LightingScheme','byte',0],
  [0x108,'FogClipDist','float',45],[0x21c,'ModSpotCheck','int',0],[0x220,'ModListenCheck','int',0],[0x350,'LoadScreenID','int',0],[0x10c,'TileBrdrDisabled','bool',values[0x10c]&255],
 ];
 for(const [offset,name,kind,fallback]of rules)values[offset]=read(are,name,kind,fallback);
 for(const offset of [0xe1,0xe2,0xe3,0xe4])values[offset]&=255;values[0x350]&=65535;
 if(values[8]&1){for(const offset of [0xe1,0xe2,0xe3,0xe4,0x218])values[offset]=0;}
 area.flags=values[8];area.pvpSetting=values[0x347];
 area.nativeChanceRainE1=values[0xe1];area.nativeChanceSnowE2=values[0xe2];area.nativeChanceLightningE3=values[0xe3];area.nativeWindPowerE4=values[0xe4];
}

// LoadTileSetInfo140362bb4..140362d19 applies defaults, zero-based source
// lights/replacement texture, and BYTEasBOOL animation inputs to native setters.
export function tileMessageMetadata(tile){
 const values={};
 for(const [offset,name]of [[0x14,'Tile_ID'],[0x24,'Tile_Orientation'],[0x18,'Tile_Height']])values[offset]=read(tile,name,'int',0);
 for(const [offset,name]of [[0x28,'Tile_MainLight1'],[0x29,'Tile_MainLight2']])values[offset]=read(tile,name,'byte',0);
 for(const [offset,name]of [[0x2a,'Tile_SrcLight1'],[0x2b,'Tile_SrcLight2'],[0x2c,'Tile_ReplaceTex']])values[offset]=(read(tile,name,'byte',1)-1)&255;
 for(const [offset,name]of [[0x2d,'Tile_AnimLoop1'],[0x2e,'Tile_AnimLoop2'],[0x2f,'Tile_AnimLoop3']])values[offset]=read(tile,name,'bool',0);
 return{nativeMessageFields:values};
}

// Shared live aliases prevent copied protocol state from drifting from AI,
// calendar/weather and the canonical spatial list. Other fields remain typed
// imported state; unsupported owners never acquire fabricated numeric defaults.
export function nativeMessageField(object,offset){
 if(object.objectType===4){
  const aliases={8:'flags',12:'width',16:'height',0xe1:'nativeChanceRainE1',0xe2:'nativeChanceSnowE2',0xe3:'nativeChanceLightningE3',0xe4:'nativeWindPowerE4',0x330:'nativeWeatherType330',0x334:'nativeWeatherOn334',0x344:'nativeWeatherOverride344',0x347:'pvpSetting'};
  if(Object.hasOwn(aliases,offset))return object[aliases[offset]];
  if(offset===0x230)return object.nativeSpatial?.count;
 }
 if(object.objectType===3){
  const aliases={0x3b9:'nativeDawnHour3b9',0x3ba:'nativeDuskHour3ba',0x3c0:'nativeCalendarYear3c0',0x3c4:'nativeCalendarMonth3c4',0x3c8:'nativeCalendarDay3c8',0x3cc:'nativeCalendarHour3cc',0x3d0:'nativeTimeTransition3d0',0x3d4:'nativeTimeOfDay3d4'};
  if(Object.hasOwn(aliases,offset))return object[aliases[offset]];
 }
 if(!object.nativeMessageFields||!Object.hasOwn(object.nativeMessageFields,offset))throw new Error(`Native message field ${offset.toString(16)} is unavailable`);
 return object.nativeMessageFields[offset];
}
