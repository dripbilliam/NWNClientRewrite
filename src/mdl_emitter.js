// Semantic IDs from full MdlNodeEmitter::InternalParseField14009a030.
// Serialized offsets are relocated by ReadBinaryNode14007b6c0 before use.
export function runtimeEmitterController(type) {
  type|=0;
  if(type>=436)return type+84;
  if(type>=392)return type+64;
  if(type>=356)return type+56;
  if(type>=328)return type+48;
  if(type>=276)return type+44;
  if(type>=228)return type+36;
  if(type>=76)return type+28;
  if(type>=72)return type+24;
  return type>=8?type+8:type;
}
const fields={
  0xe8:'blurlength',0x108:'detonate',0xdc:'velocity',0xc0:'randvel',0x74:'birthrate',
  0x88:'colorstart',0x218:'colormid',0x7c:'colorend',0x224:'percentstart',0x225:'percentmid',0x226:'percentend',
  0x70:'alphastart',0x214:'alphamid',0x6c:'alphaend',0xc4:'sizestart',0x228:'sizemid',0xc8:'sizeend',
  0xcc:'sizestart_y',0x22c:'sizemid_y',0xd0:'sizeend_y',0xa4:'framestart',0xa0:'frameend',0xac:'lifeexp',
  0xb0:'mass',0xd4:'spread',0xbc:'particlerot',0xf4:'lightningscale',0x9c:'fps',0xe0:'xsize',0xe4:'ysize',
  0x78:'bounce_co',0xec:'lightningdelay',0xf0:'lightningradius',0xb4:'p2p_bezier2',0xb8:'p2p_bezier3',
  0x94:'combinetime',0x98:'drag',0xa8:'grav',0xd8:'threshold'
};
export const EMITTER_RUNTIME_FIELDS=Object.freeze(fields);
export const EMITTER_ASCII_CHANNELS=Object.fromEntries(Object.values(fields).map(name=>[name,[`emitter.${name}`,name.startsWith('color')?3:1]]));
export const BINARY_EMITTER_CHANNELS=Object.fromEntries(Array.from({length:557},(_,type)=>[type,EMITTER_ASCII_CHANNELS[fields[runtimeEmitterController(type)]]]).filter(([,channel])=>channel));
// Individual setters140061a40..140061ae8 OR these bits into node+174.
export const EMITTER_FLAGS={p2p:1,p2p_sel:2,affectedbywind:4,tinted:8,bounce:16,random:32,inherit:64,inheritvel:128,inherit_local:256,splat:512,inherit_part:1024};
