// Freeze only the controlled actor's bounded replay inputs, not live captures.
import fs from 'node:fs/promises';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const root=new URL('../backups/animations/',import.meta.url),source='creation-performance-client-collision-live-v4.json',bytes=await fs.readFile(new URL(source,root)),report=JSON.parse(bytes),k=report.contact.keyboard;
assert.equal(report.states.at(-1).phase,'closed');assert.equal(report.failure,undefined);
const ack=k.authority.find(a=>a.actionFlag===37&&a.lastInputSequence===37&&a.path?.length===1);assert.ok(ack);
const at=ack.at-k.clock.wall+k.clock.renderer,before=k.frames.filter(f=>f.at<at).at(-1),preview=k.previews.filter(p=>p.at<at&&p.path?.target).at(-1);assert.ok(before.active&&before.held&&preview.path.factor<1);
const input={scope:'Controlled local actor short-path acknowledgement replay inputs; no transport payloads',endpoint:'127.0.0.1:5121',source:{name:source,sha256:crypto.createHash('sha256').update(bytes).digest('hex')},before,acknowledgement:{sequence:ack.actionFlag,lastSequence:ack.lastInputSequence,position:ack.position,path:ack.path,script:ack.field8F4,factor:ack.field8EC},priorPath:[before.position,preview.path.target],priorFactor:preview.path.factor,
 limits:'One selected matching acknowledgement from a completed local run, explicitly chosen sequence37. The isolated replay treats collision as clear and resting animation as0; the outer reader/input poll are not executed.'};
await fs.writeFile(new URL('creation-performance-client-ack-input-v1.json',root),JSON.stringify(input,null,2)+'\n');console.log(JSON.stringify({selectedSequence:ack.actionFlag,priorFactor:preview.path.factor,before:before.at,ack:at,sourceHash:input.source.sha256}));
