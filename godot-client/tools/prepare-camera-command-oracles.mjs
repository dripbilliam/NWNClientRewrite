import fs from 'node:fs/promises';import crypto from 'node:crypto';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
const sources=[],target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
async function load(path){const b=await fs.readFile(path),v=JSON.parse(b);if(v.target!==target)throw Error('Wrong original camera target');sources.push({path,sha256:crypto.createHash('sha256').update(b).digest('hex'),limits:v.limits});return v;}
const commands=await load('backups/animations/native-camera-command-observations.json'),location=await load('backups/animations/native-camera-location-observations.json'),attachment=await load('backups/animations/native-camera-attachment-observations.json');
const decode=s=>decodeServerGameMessage(Uint8Array.from([80,16,s.minor,...Buffer.from(s.body,'hex')]));
if(commands.rows.length!==52||location.packets.length!==104||location.frames.length!==378||attachment.rows.length!==216||attachment.packets.length!==10)throw Error('Original camera groups incomplete');
for(const row of commands.rows)for(const s of row.steps){if(s.diagnostics.length||s.overflow||s.underflow)throw Error('Invalid native command observation');s.command=decode(s);}
for(const s of location.packets){if(s.diagnostics.length||s.overflow||s.underflow)throw Error('Invalid native location observation');s.command=decode(s);}
const output='godot-client/tests/fixtures/camera-commands-original-v1.json';await fs.writeFile(output,JSON.stringify({target,sources,commands:commands.rows,packets:location.packets,frames:location.frames,attachments:attachment.rows,attachmentPackets:attachment.packets.map(s=>({...s,minor:10,command:decode({...s,minor:10})}))},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,groups:[52,104,378,216,10]}));
