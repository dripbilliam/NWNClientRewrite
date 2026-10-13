import { parseGff } from './gff.js';
import { OBJECT_INVALID } from './game_object_array.js';
import { areaObjectsByX, nativeDistanceSquared } from './nearest_objects.js';

export function parseConversation(bytes) {
  const root = parseGff(bytes, 'DLG ').root;
  for (const field of ['EntryList', 'ReplyList', 'StartingList']) if (!Array.isArray(root[field])) throw new Error(`DLG ${field} is missing`);
  const validate = (links, count) => {
    for (const link of links ?? []) if (!Number.isInteger(link.Index) || link.Index < 0 || link.Index >= count) throw new Error('DLG link index is out of bounds');
  };
  validate(root.StartingList, root.EntryList.length);
  for (const node of root.EntryList) validate(node.RepliesList, root.ReplyList.length);
  for (const node of root.ReplyList) validate(node.EntriesList, root.EntryList.length);
  return root;
}

export class Conversation {
  constructor(session) { this.session = session; this.state = null; this.version = 0; this.busy = false; this.resources = new Map(); }
  changed() { this.version++; this.session.onConversation(this.state); }
  async script(name, params = [], condition = false, frame = null) {
    if (!name) return condition ? true : undefined;
    if (params.length) throw new Error('DLG script parameters are not implemented');
    const result = await this.session.vm.run(await this.session.program(name), this.state.ownerId,
      frame ? { budget: frame.budget, depth: frame.depth + 1 } : {});
    if (!condition) return;
    if (result.stack.length !== 1 || result.stack[0].type !== 3) throw new Error(`DLG condition ${name} did not return an integer`);
    return result.stack[0].value !== 0;
  }
  speaker(node) {
    const state = this.state, owner = this.session.registry.get(state.ownerId);
    if (!node.Speaker) return owner;
    const tag = String(node.Speaker).slice(0, 64);
    if (!state.speakerIds.has(node.Speaker)) {
      let id = OBJECT_INVALID, distance = 100;
      if (owner.tag === tag) id = owner.id;
      else for (const object of areaObjectsByX(this.session, this.session.registry.get(owner.areaId))) {
        const candidateDistance = nativeDistanceSquared(owner.position, object.position);
        if (object.tag === tag && candidateDistance <= distance) { id = object.id; distance = candidateDistance; }
      }
      state.speakerIds.set(node.Speaker, id);
    }
    const speaker = this.session.registry.get(state.speakerIds.get(node.Speaker));
    if (!speaker || speaker.areaId !== owner.areaId || this.session.isDead(speaker) || Math.fround(Math.sqrt(nativeDistanceSquared(owner.position, speaker.position))) > 10) return null;
    if (speaker.dialogOwnerId !== undefined && speaker.dialogOwnerId !== OBJECT_INVALID && speaker.dialogOwnerId !== owner.id) {
      const other = this.session.registry.get(speaker.dialogOwnerId);
      if (other?.dialogOwnerId === speaker.dialogOwnerId) return null;
    }
    speaker.dialogOwnerId = owner.id; state.participants.add(speaker.id);
    return speaker;
  }
  async firstEntry(links, frame) {
    for (const link of links ?? []) if (this.speaker(this.state.resource.EntryList[link.Index]) && await this.script(link.Active, link.ConditionParams, true, frame)) return link.Index;
    return null;
  }
  async start(owner, player, resRef = '', frame = null) {
    if (this.state || this.busy || !owner || !player?.isPC || owner.areaId !== player.areaId) return false;
    resRef = String(resRef || owner.authored?.Conversation || '').toLowerCase();
    if (!resRef) return false;
    this.busy = true;
    try {
      if (!this.resources.has(resRef)) this.resources.set(resRef, parseConversation(await this.session.resolver.getResource(resRef, 2029)));
      const resource = this.resources.get(resRef);
      this.state = { ownerId: owner.id, playerId: player.id, resRef, resource, entryIndex: null, replies: [], history: [], paused: false, error: null, speakerIds: new Map(), participants: new Set([owner.id, player.id]) };
      owner.conversation = this.state; owner.dialogOwnerId = owner.id; player.dialogOwnerId = owner.id;
      this.session.onClearActions(owner.id); this.session.onClearActions(player.id);
      const first = await this.firstEntry(resource.StartingList, frame);
      if (first === null) { await this.finish(false, frame); return false; }
      await this.entry(first, frame);
      return true;
    } catch (error) { this.fail(error); throw error; }
    finally { this.busy = false; this.changed(); }
  }
  fail(error) { if (this.state) { this.state.error = error.message; this.state.replies = []; this.changed(); } }
  async entry(index, frame) {
    const state = this.state, node = state.resource.EntryList[index], speaker = this.speaker(node);
    if (!speaker) throw new Error(`DLG speaker ${node.Speaker} is unavailable`);
    state.entryIndex = index; state.speakerId = speaker.id; state.replies = [];
    state.history.push({ speakerId: speaker.id, text: node.Text });
    if (state.history.length > 100) state.history.shift();
    this.changed();
    if (node.Quest && node.QuestEntry > this.session.local(state.playerId, `NW_JOURNAL_ENTRY${node.Quest}`, 'int')) {
      this.session.registry.get(state.playerId).locals.setInt(`NW_JOURNAL_ENTRY${node.Quest}`, node.QuestEntry);
      this.session.onMessage({ type: 'journal', id: state.playerId, text: 'Journal updated' });
    }
    await this.script(node.Script, node.ActionParams, false, frame);
    // Reply links retain original ordinals, including linked/reused nodes.
    for (const [ordinal, link] of (node.RepliesList ?? []).entries()) {
      if (await this.script(link.Active, link.ConditionParams, true, frame)) state.replies.push({ ordinal, index: link.Index, node: state.resource.ReplyList[link.Index] });
    }
    state.complete = state.replies.length === 0;
    this.changed();
  }
  async choose(ordinal, version) {
    if (!this.state || this.busy || this.state.paused || this.state.error || version !== this.version) return false;
    const reply = this.state.replies.find(r => r.ordinal === ordinal);
    if (!reply) return false;
    this.busy = true;
    try {
      this.state.replies = []; this.changed();
      this.state.history.push({ speakerId: this.state.playerId, text: reply.node.Text });
      await this.script(reply.node.Script, reply.node.ActionParams);
      const next = await this.firstEntry(reply.node.EntriesList);
      if (next === null) await this.finish(false); else await this.entry(next);
      return true;
    } catch (error) { this.fail(error); throw error; }
    finally { this.busy = false; this.changed(); }
  }
  async finish(aborted = false, frame = null) {
    const state = this.state; if (!state) return;
    try { await this.script(aborted ? state.resource.EndConverAbort : state.resource.EndConversation, [], false, frame); }
    finally {
      const owner = this.session.registry.get(state.ownerId), player = this.session.registry.get(state.playerId);
      if (owner) { owner.conversation = null; owner.dialogOwnerId = OBJECT_INVALID; }
      if (player) player.dialogOwnerId = OBJECT_INVALID;
      for (const id of state.participants) {
        const participant = this.session.registry.get(id);
        if (participant?.dialogOwnerId === state.ownerId) participant.dialogOwnerId = OBJECT_INVALID;
      }
      this.state = null; this.changed();
    }
  }
}
