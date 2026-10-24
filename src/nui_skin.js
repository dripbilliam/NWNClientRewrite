// The installed NUI skin uses TOML tables, scalar values and [[fonts]]. Keep
// this data-only parser separate from CSS; no server text becomes executable.
export function parseNuiSkin(source){const tables=Object.create(null),fonts=[];let target=tables['']=Object.create(null);for(const raw of source.replace(/^\uFEFF/,'').split(/\r?\n/)){let line='',quote=null,escaped=false;for(const c of raw){if(!quote&&c==='#')break;line+=c;if(escaped){escaped=false;continue;}if(c==='\\'&&quote==='"'){escaped=true;continue;}if(quote){if(c===quote)quote=null;}else if(c==='"'||c==="'")quote=c;}line=line.trim();if(!line)continue;if(/^\[\[fonts\]\]$/.test(line)){fonts.push(target=Object.create(null));continue;}const section=line.match(/^\[([\w.]+)\]$/);if(section){target=tables[section[1]]??=Object.create(null);continue;}const property=line.match(/^([\w-]+)\s*=\s*(.+)$/);if(!property)throw Error('Unsupported NUI skin syntax');const[,key,rawValue]=property;let value;if(rawValue.startsWith("'")&&rawValue.endsWith("'"))value=rawValue.slice(1,-1);else{try{value=JSON.parse(rawValue.replace(/(?<=\d)_(?=\d)/g,''));}catch{throw Error('Unsupported NUI skin value '+key);}}target[key]=value;}return{tables,fonts};}
const themes=new WeakMap();let fontSerial=0;
export function loadNuiSkin(assets,image){
 if(!assets)return Promise.resolve(null);
 if(!themes.has(assets))themes.set(assets,(async()=>{
  const bytes=await assets.resolver.getResource('nui_skin',2076),skin=parseNuiSkin(new TextDecoder('utf8',{fatal:true}).decode(bytes));
  // All font/image reads are independent. Serial IPC round trips added avoidable
  // cold-open latency; prepare these while the area's graphics are loading.
  const fontWork=Promise.all(skin.fonts.map(async spec=>{
   if(typeof spec.name!=='string'||typeof spec.resref!=='string')return null;
   const family='NUI Font '+(++fontSerial),face=await new FontFace(family,await assets.resolver.getResource(spec.resref,2074)).load();if(assets.disposed)return null;
   document.fonts.add(face);assets.fonts.push(face);return[spec.name,{family,size:Number(spec.font_size)||17,spacing:Number(spec.spacing_h)||0}];
  }));
  const names=[...new Set(Object.values(skin.tables).flatMap(Object.values).filter(v=>typeof v==='string'&&!v.startsWith('#')&&/^[a-z0-9_]{1,32}$/i.test(v)))];
  const textureWork=Promise.all(names.map(async name=>[name,await image(name)])),[fontRows,textureRows]=await Promise.all([fontWork,textureWork]);
  return assets.disposed?null:{...skin,fonts:new Map(fontRows.filter(Boolean)),textures:new Map(textureRows)};
 })());
 return themes.get(assets);
}
export const nuiSkinColor=value=>typeof value==='string'&&/^#[\da-f]{8}$/i.test(value)?value:null;
