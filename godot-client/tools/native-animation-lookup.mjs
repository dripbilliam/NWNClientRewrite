// Offline migration of the existing researched native dispatch constants.
// The generated GDScript runs independently; no JS is loaded by Godot.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {nativeAnimationNames,nativeAnimationRows,nativeAnimationContexts} from '../../src/native_animation_names.js';
const sourceSha=createHash('sha256').update(await fs.readFile('src/native_animation_names.js')).digest('hex');
await fs.writeFile('godot-client/systems/native_data/animation_lookup_tables.gd','extends RefCounted\n# Researched native dispatch constants. Source SHA256: '+sourceSha+'\nconst NAMES='+JSON.stringify(nativeAnimationNames)+'\nconst ROWS='+JSON.stringify(nativeAnimationRows)+'\nconst CONTEXTS='+JSON.stringify(nativeAnimationContexts)+'\n',{flag:'wx'});
console.log(JSON.stringify({names:nativeAnimationNames.length,rows:nativeAnimationRows.length,contexts:Object.keys(nativeAnimationContexts).length,sourceSha}));
