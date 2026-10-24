// Renderer-owned callbacks known to affect only their current draw's uniforms.
// Unknown callbacks may mutate later draws and require ordinary submission.
const hooks=new WeakSet();
const batchHooks=new WeakMap();
export function localRendererHook(callback){hooks.add(callback);return callback;}
export function isLocalRendererHook(callback){return hooks.has(callback);}
export function batchRendererHook(callback,description){batchHooks.set(callback,description);return localRendererHook(callback);}
export function rendererBatchHook(callback){return batchHooks.get(callback)??null;}
