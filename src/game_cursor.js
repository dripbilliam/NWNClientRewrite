import {parse2da} from './area.js';
import {decodeResourceText} from './resource_archive.js';
import {networkDoorClickState} from './network_door.js';
// Native gui_mp resource sequence and MOUSECURSOR IDs, not browser emoji.
const base=['default','walk','nowalk','attack','noatck','talk','notalk','follow','examine','noexam','trans','door','use','nouse','magic','nomagic','disarm','nodisarm','action','noaction','lock','nolock','pushpin','create','nocreat','kill','nokill','heal','noheal'];
export function nativeCursorResource(id){
 if(!Number.isInteger(id)||id<1)return null;
 if(id<=58)return'gui_mp_'+base[(id-1)>>1]+(id%2?'u':'d');
 if(id>=59&&id<=90)return'gui_mp_'+(id<75?'arrun':'arwalk')+String((id-59)%16).padStart(2,'0');
 if(id===91||id===92)return'gui_mp_pickup'+(id===91?'u':'d');
 if(id>=93&&id<=292)return'gui_mp_custom'+String((id-93)>>1).padStart(2,'0')+(id%2?'u':'d');return null;
}
export function worldCursorId(target,{walkable=false,playerId=null,targeting=null,pressed=false}={}){
 const override=target?.replicated?.light?.field260??target?.lightState?.field260??target?.nativeMiscVisualFields?.[0x260]??target?.replicated?.mouseCursor;
 let id;if(targeting)id=targeting.cursor;
 else if(Number.isInteger(override)&&override>=0)id=override;
 else if(target?.objectType===10)id=target.replicated?.hasTransition&&networkDoorClickState(target)>0?21:23;
 else if(target?.objectType===7&&target.replicated?.hasTransition&&!target.replicated?.isTrap)id=21;
 else if(target?.objectType===6)id=91;
 else if(target?.objectType===9)id=(target.replicated?.field264??target.nativeUseable264??target.usable??target.authored?.Useable)?25:1;
 else if(target?.objectType===5)id=target.id===playerId?1:target.replicated?.reaction>1?7:11;
 else id=walkable?3:1;
 if(pressed&&id%2===1&&(id<=58||id>=91))id++;return id;
}
export class GameCursorAssets{
 constructor(assets){this.assets=assets;this.cache=new Map();this.names=new Map();this.ready=assets.resolver.getResource('cursors',2017).then(bytes=>{const t=parse2da(decodeResourceText(bytes));for(const row of t.rows.values()){const id=Number(row.CursorID);if(Number.isInteger(id)&&/^[\w]{1,32}$/.test(row.ResRef))this.names.set(id,row.ResRef.toLowerCase());}}).catch(()=>{});}
 get(id){if(!this.cache.has(id))this.cache.set(id,this.load(id));return this.cache.get(id);}
 async load(id){await this.ready;let name=this.names.get(id)??nativeCursorResource(id);if(!name)return null;const image=await this.assets.image(name),{width,height,data}=image;if(!width||!height||width>128||height>128||!data)throw Error('Native cursor image exceeds cursor limits');const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(data),width,height),0,0);return{id,name,width,height,url:canvas.toDataURL(),hotspot:[0,0]};}
}
