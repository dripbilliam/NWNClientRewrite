'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const file=name=>path.join(__dirname,name),sha=name=>crypto.createHash('sha256').update(fs.readFileSync(name)).digest('hex');
const parent=file('cursor_extension_g.cpp');assert.equal(sha(parent),'05fae92e89fc94eee06f21a468d8b4a4c2613c639a62cf4cb8a549aec0682ffe');
const parentContract=file('source-contract-g.json');assert.equal(sha(parentContract),'4c1bbce396c6136eeabcbcde208f4d422af776f3fd52bbea8b99a69c9b1ae863');
let source=fs.readFileSync(parent,'utf8');
const before='GDExtensionConstVariantPtr find(const Raw&dict,const Var&name){if(!dict.readable)throw std::runtime_error("Guarded Dictionary element read refused");return dictionary_at(dict.data,name.data);}';
const after=`GDExtensionConstVariantPtr find(const Raw&dict,const Var&name){
 // The public const operator[] is NOT getptr: an absent key logs an engine
 // error and yields a Nil value pointer. Test actual membership first; Nil
 // present values remain PRESENT (including model.error=null).
 if(!dict.readable)throw std::runtime_error("Guarded Dictionary element read refused");
 Var dictionary;destroy(dictionary.data);
 from[GDEXTENSION_VARIANT_TYPE_DICTIONARY](dictionary.data,const_cast<uint8_t*>(dict.data));
 if(!call(dictionary,"has",{&name}).boolean())return nullptr;
 return dictionary_at(dict.data,name.data);
}`;
assert.equal(source.split(before).length,2);source=source.replace(before,after);
const capability='put(value,"transactional_skip_rollback",Var::boolean(true));';
assert.equal(source.split(capability).length,2);source=source.replace(capability,capability+'put(value,"dictionary_has_before_const_index",Var::boolean(true));');
const target=file('cursor_extension_h.cpp');fs.writeFileSync(target,source,{flag:'wx'});
const contract=JSON.parse(fs.readFileSync(parentContract));contract.revision='H-public-dictionary-membership-before-const-index';contract.parentSource={file:parent,sha256:sha(parent)};
contract.sourcePins=contract.sourcePins.filter(pin=>pin.file!==parent).concat([target,__filename].map(name=>({file:name,sha256:sha(name)})));
contract.ops[0]+='; dictionary_has_before_const_index is required by future H seams';
contract.dictionaryAccessPolicy={ordering:'Guard Raw.readable first; reconstruct a call-local Dictionary Variant through the official from-type constructor; call builtin Dictionary.has(key); return nullptr without element access when absent; call official dictionary_operator_index_const ONLY when present.',presence:'Absent key differs from present Nil. model_error uses membership, not value truth or Nil type. Missing optional pending/radius use original defaults/fallback paths.',callbackDomain:'Concrete plain Dictionary plus canonical String/StringName key only in native scan. has is a builtin; no authored getter/coercion callback is introduced. Unknown keys remain sticky original-script fallback before find.',preservedFailure:'Actual G native fixture logged missing error-key accesses because const operator[] does not return getptr-null. G source and failed runtime capsule are retained. This correction requires actual fresh runtime acceptance.'};
contract.knownUnverified.push('H fixes actual public const Dictionary accessor behavior; no H compilation/runtime has yet occurred.');
const contractFile=file('source-contract-h.json');fs.writeFileSync(contractFile,JSON.stringify(contract,null,2)+'\n',{flag:'wx'});
const recipeFile=file('build-private-h.ps1');fs.writeFileSync(recipeFile,fs.readFileSync(file('build-private-g.ps1'),'utf8').replaceAll('source-contract-g.json','source-contract-h.json').replaceAll('cursor_extension_g.cpp','cursor_extension_h.cpp'),{flag:'wx'});
const command={version:1,status:'SOURCE_ONLY_FUTURE_COMMAND_NOT_EXECUTED',source:{file:target,sha256:sha(target)},contract:{file:contractFile,sha256:sha(contractFile)},buildRecipe:{file:recipeFile,sha256:sha(recipeFile)},futureBuild:{executable:'pwsh',arguments:['-NoProfile','-File',recipeFile,'-Label','h-source-a','-Build'],slotOwner:'Root exclusively controls compiler/native scheduling'},futureCapsule:'Requires a fresh candidate manifest explicitly pinning H; older G/F prerequisites must not silently select H. Unknown future DLL/build-receipt hashes are not invented.',nativeStarts:0,compilerStarts:0};
const commandFile=file('future-command-h.json');fs.writeFileSync(commandFile,JSON.stringify(command,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...command,futureCommand:{file:commandFile,sha256:sha(commandFile)}}));
