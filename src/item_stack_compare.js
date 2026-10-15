const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native stack comparison ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native stack comparison provider ${name} is unavailable`);return p[name];};
const array=(item,name,n)=>{if(!Array.isArray(item[name])||item[name].length<n)throw new Error(`Native stack comparison ${name} storage is unavailable`);return item[name];};
const same=(a,b,n,mask)=>{for(let i=0;i<n;i++)if((integer(a[i],'appearance cell')&mask)!==(integer(b[i],'appearance cell')&mask))return false;return true;};
const extensions=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178];
export function nativeItemTag(text){
  if(typeof text!=='string')throw new Error('Native stack comparison tag is unavailable');
  const bytes=[...text].map(c=>{const point=c.codePointAt(0),extended=extensions.indexOf(point);if(point<=255)return point;if(extended>=0)return extended+128;throw new Error('Native stack comparison tag byte encoding is unavailable');});
  return{length:bytes.length,present:bytes.length!==0,bytes};
}

// CompareItem140466220..1404664fc. Passive pool contents, remaining-use
// flags, property IDs/custom tags/durations and names/prices are NOT compared.
// Passive COUNT and physical active-property fields are compared. Appearance
// checks are conditional on a valid base row with Stacking WORD>1.
export function compareStackItems(a,b,p){
  if(integer(a.identified,'first identified')===0||integer(b.identified,'second identified')===0)return 0;
  const aa=array(a,'activeProperties',0),ba=array(b,'activeProperties',0),ap=array(a,'passiveProperties',0),bp=array(b,'passiveProperties',0);
  if(aa.length!==ba.length||ap.length!==bp.length)return 0;
  for(const cell of ['plot','charges','baseItem','stolen'])if(integer(a[cell],cell)!==integer(b[cell],cell))return 0;
  const info=required(p,'baseInfo')(a);
  if(info&&(integer(info.stacking,'maximum stack size')&65535)>1){
    const model=integer(info.modelType,'model type')&255;
    if(model===0&&!same(array(a,'modelParts',1),array(b,'modelParts',1),1,65535))return 0;
    if(model===2&&!same(array(a,'modelParts',3),array(b,'modelParts',3),3,65535))return 0;
    if(model===1&&(!same(array(a,'modelParts',1),array(b,'modelParts',1),1,65535)||!same(array(a,'colors',6),array(b,'colors',6),6,255)))return 0;
    if(model===3&&(!same(array(a,'armorParts',19),array(b,'armorParts',19),19,65535)||!same(array(a,'colors',6),array(b,'colors',6),6,255)))return 0;
  }
  const at=required(p,'tag')(a),bt=required(p,'tag')(b);
  if(integer(at.length,'first tag length')!==integer(bt.length,'second tag length'))return 0;
  if(at.present){
    if(!Array.isArray(at.bytes)||!Array.isArray(bt.bytes))throw new Error('Native stack comparison tag storage is unavailable');
    for(let i=0;;i++){
      const av=at.bytes[i]??0,bv=bt.present?(bt.bytes[i]??0):0;
      if(av!==bv)return 0;if(bv===0)break;
    }
  }
  for(let i=0;i<aa.length;i++){
    const x=aa[i],y=ba[i];for(const [name,mask] of [['type',65535],['subtype',65535],['costTable',255],['costValue',65535],['param1',255],['param1Value',255],['usesPerDay',255]])
      if((integer(x[name],name)&mask)!==(integer(y[name],name)&mask))return 0;
  }
  return 1;
}
