import fs from 'node:fs/promises';
const input=JSON.parse(await fs.readFile(new URL('../backups/animations/native-animation-name-observations.json',import.meta.url),'utf8'));
if(input.binarySha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw new Error('Unexpected native animation lookup build');
const names=[],rows=[],contexts={};
for(const c of input.contexts){
  if(c.names.length!==426)throw new Error('Incomplete native animation name context');
  const row=c.names.map(name=>{let id=names.indexOf(name);if(id<0){id=names.length;names.push(name);}return id;});
  const encoded=JSON.stringify(row);let index=rows.findIndex(r=>JSON.stringify(r)===encoded);
  if(index<0){index=rows.length;rows.push(row);}contexts[`${c.fieldDE}:${c.fieldDD}:${c.fieldE0}`]=index;
}
await fs.writeFile(new URL('../src/native_animation_names.js',import.meta.url),
  '// Generated from read-only native lookup140961540..140963e86; no model assets.\n'+
  '// String/allocator helpers substituted, special-walk0, movement override0, no animation overrides.\n'+
  `export const nativeAnimationNames=${JSON.stringify(names)};\nexport const nativeAnimationRows=${JSON.stringify(rows)};\nexport const nativeAnimationContexts=${JSON.stringify(contexts)};\n`);
console.log(JSON.stringify({contexts:input.contexts.length,rows:rows.length,names:names.length}));
