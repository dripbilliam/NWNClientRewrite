// Native image-button callback95c800 converts a positive image_region to
// uint16 pixel coordinates. A null/zero/negative extent selects the full image.
export function nuiImageRegion(region){
 if(!(region?.w>0&&region?.h>0))return null;
 return Object.fromEntries(['x','y','w','h'].map(key=>[key,Math.trunc(Number(region[key])||0)&65535]));
}
const imageCache=new WeakMap();
export function nuiImage(assets,name,region){
 const rect=nuiImageRegion(region),key=JSON.stringify([name,rect]);let cache=imageCache.get(assets);if(!cache)imageCache.set(assets,cache=new Map());
 if(!cache.has(key)){const pending=render(assets,name,rect).catch(error=>{if(cache.get(key)===pending)cache.delete(key);throw error;});cache.set(key,pending);}return cache.get(key);
}
async function render(assets,name,rect){
 const image=await assets.image(name),source=document.createElement('canvas');
 source.width=image.width;source.height=image.height;source.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);
 if(!rect)return source.toDataURL();
 const canvas=document.createElement('canvas');canvas.width=Math.max(1,rect.w);canvas.height=Math.max(1,rect.h);
 canvas.getContext('2d').drawImage(source,rect.x,rect.y,rect.w,rect.h,0,0,rect.w,rect.h);return canvas.toDataURL();
}
