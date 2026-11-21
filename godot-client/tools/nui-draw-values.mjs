// Project resolved server draw values to finite native fields. Defaults follow
// the existing SVG renderer's nullish defaults; no executable layout data.
const numeric=(value,fallback=0)=>{const result=Number(value??fallback);return Number.isFinite(result)?result:fallback;};
const vector=value=>({x:numeric(value?.x),y:numeric(value?.y)});
export function normalizeNuiDrawCommand(value){
 const result={...value,fill:Boolean(value.fill)};
 for(const [key,fallback] of [['line_thickness',1],['order',1],['render',0],['radius',0],['amin',0],['amax',0],['image_aspect',0]])result[key]=numeric(value[key],fallback);
 result.rect={...vector(value.rect),w:Math.max(0,numeric(value.rect?.w)),h:Math.max(0,numeric(value.rect?.h))};
 for(const key of ['a','b','c','ctrl0','ctrl1'])result[key]=vector(value[key]);
 const points=Array.isArray(value.points)?value.points:[];
 result.points=typeof points[0]==='number'?points.map(item=>numeric(item)):points.map(vector);
 return result;
}
