// Test oracle only. Compare cyclic graphs and physical aliases, including exact
// bytes of independently transferred attributes, without logging state/assets.
export function compareParticleWorkerState(reference,actual){
 const forward=new WeakMap(),reverse=new WeakMap(),paths=[];let differences=0;
 const fail=path=>{differences++;if(paths.length<12)paths.push(path);};
 const visit=(a,b,path)=>{if(Object.is(a,b))return;if(a===null||b===null||typeof a!=='object'||typeof b!=='object'){fail(path);return;}if(forward.has(a)||reverse.has(b)){if(forward.get(a)!==b||reverse.get(b)!==a)fail(path+'.alias');return;}forward.set(a,b);reverse.set(b,a);
  if(a instanceof ArrayBuffer||b instanceof ArrayBuffer){if(!(a instanceof ArrayBuffer)||!(b instanceof ArrayBuffer)||a.byteLength!==b.byteLength){fail(path+'.buffer-length');return;}const x=new Uint8Array(a),y=new Uint8Array(b);for(let i=0;i<x.length;i++)if(x[i]!==y[i])fail(path+'['+i+']');return;}
  if(ArrayBuffer.isView(a)||ArrayBuffer.isView(b)){if(a.constructor!==b.constructor||a.byteLength!==b.byteLength){fail(path+'.type/length');return;}const x=new Uint8Array(a.buffer,a.byteOffset,a.byteLength),y=new Uint8Array(b.buffer,b.byteOffset,b.byteLength);for(let i=0;i<x.length;i++)if(x[i]!==y[i])fail(path+'['+i+']');return;}
  if(Array.isArray(a)!==Array.isArray(b)){fail(path+'.type');return;}const keys=Object.keys(a);if(keys.length!==Object.keys(b).length)fail(path+'.keys');for(const key of keys){if(!Object.hasOwn(b,key))fail(path+'.'+key);else visit(a[key],b[key],path+'.'+key);}
 };visit(reference,actual,'state');return{exact:differences===0,differences,paths};
}
