'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),moduleApi=require('node:module');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const protectedHelpers=new Set(['tools/native-production-selection.cjs','tools/native-performance-runtime.cjs']);
const seeds=['tools/replay-native-loading.mjs','tools/native-feature-manifest.cjs','tools/native-client-flags.cjs','tools/native-loading-pipeline.cjs','tools/native-render-configuration.cjs','tools/native-engine-runtime.cjs','tools/native-production-selection.cjs','tools/native-performance-runtime.cjs'];
function references(text){const refs=[];for(const pattern of [/\b(?:import|export)\s+(?:[^;'"\r\n]*?\s+from\s*)?['"]([^'"]+)['"]/g,/\brequire(?:\.resolve)?\s*\(\s*['"]([^'"]+)['"]\s*\)/g,/\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)/g,/\bnew\s+URL\s*\(\s*['"]([^'"]+)['"]\s*,/g])for(const match of text.matchAll(pattern))refs.push(match[1]);return[...new Set(refs)];}
function resolveRelative(relative,specifier){const result=path.posix.normalize(path.posix.join(path.posix.dirname(relative),specifier));assert(!result.startsWith('../')&&!path.posix.isAbsolute(result),'Driver import escapes project');return result;}
function copyClosure(sourceProject,targetProject,put){
 fs.mkdirSync(path.join(targetProject,'reports'),{recursive:true});
 const queue=[...seeds],seen=new Set(),rows=[],imports=[];
 while(queue.length){const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);
  const protectedOverlay=protectedHelpers.has(relative),source=path.join(protectedOverlay?targetProject:sourceProject,relative);assert(fs.statSync(source).isFile(),'Missing module: '+relative);const bytes=fs.readFileSync(source);
  if(!protectedOverlay)put(relative,bytes,'current private DRIVER closure, not application overlay');
  rows.push({relative,sha256:sha(bytes),source:protectedOverlay?'preserved private helper overlay':'current global driver dependency',globalSourceSHA256:protectedOverlay?null:sha(bytes)});
  for(const specifier of references(bytes.toString())){
   if(!specifier.startsWith('.')){assert(moduleApi.isBuiltin(specifier),'External driver package is not a builtin: '+specifier);imports.push({from:relative,specifier,builtin:true});continue;}
   let resolved=resolveRelative(relative,specifier);if(!path.posix.extname(resolved)){const candidates=[resolved,resolved+'.js',resolved+'.cjs',resolved+'.mjs',resolved+'/index.js'];resolved=candidates.find(file=>fs.existsSync(path.join(sourceProject,file))||fs.existsSync(path.join(targetProject,file)));assert(resolved,'Unresolved extensionless module '+specifier);}
   assert(/\.(mjs|cjs|js|json)$/.test(resolved),'Unsupported driver module '+resolved);assert(fs.existsSync(path.join(protectedHelpers.has(resolved)?targetProject:sourceProject,resolved)),'Import target missing: '+relative+' -> '+specifier);
   imports.push({from:relative,specifier,resolved});queue.push(resolved);
  }
 }
 // The display module invokes this ordinary helper through PowerShell rather
 // than importing it. Its exact current bytes are part of the driver closure.
 const display='tools/native-window-screen.ps1',displayBytes=fs.readFileSync(path.join(sourceProject,display));put(display,displayBytes,'current private driver display helper');rows.push({relative:display,sha256:sha(displayBytes),source:'current display helper',globalSourceSHA256:sha(displayBytes)});
 for(const row of rows){assert.equal(sha(fs.readFileSync(path.join(targetProject,row.relative))),row.sha256);if(row.globalSourceSHA256)assert.equal(sha(fs.readFileSync(path.join(sourceProject,row.relative))),row.globalSourceSHA256,'Driver dependency changed during copy');}
 for(const item of imports)if(item.resolved)assert(fs.statSync(path.join(targetProject,item.resolved)).isFile());
 return{rows,imports,protectedHelpers:[...protectedHelpers],scope:'Current copied replay DRIVER, recursive static ES/literal require/import/worker-URL module closure and display helper. Private selector/runtime overlays are preserved; application GDScript/native sources remain reviewedB/D exactly. Dynamic normal-helper requires are exercised during source-stage readback.'};
}
function verifyClosure(project,closure){for(const row of closure.rows)assert.equal(sha(fs.readFileSync(path.join(project,row.relative))),row.sha256,'Driver closure changed: '+row.relative);for(const item of closure.imports)if(item.resolved)assert(fs.statSync(path.join(project,item.resolved)).isFile());return true;}
module.exports={copyClosure,verifyClosure,references};
