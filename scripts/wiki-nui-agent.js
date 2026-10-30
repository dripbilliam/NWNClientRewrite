/* Frida agent for the exact SHA-256/build checked by wiki_nui_injector.py.
 * Calls the stock 55/{1,2,5} receiver on the real receive thread, after a real
 * message completes. It never changes a real inbound packet/message object.
 */
function filterWikiNuiPacket(input, mode, minor, token, indexed = true) {
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (bytes.length < 12) throw Error('Truncated NUI output');
  const end = view.getUint32(3, true);
  if (end < 7 || end >= bytes.length) throw Error('Invalid NUI output boundary');
  let cursor = 7;
  const need = n => { if (n < 0 || cursor + n > end) throw Error('Truncated NUI output field'); };
  const tag = n => { if (mode === 0) { need(1); if (bytes[cursor++] !== n) throw Error('Unexpected NUI output type'); } };
  if (mode === 0) { tag(3); tag(1); }
  const integer = () => { tag(8); need(4); const n = view.getInt32(cursor, true); cursor += 4; return n; };
  const string = () => { tag(14); const n = integer(); need(n); cursor += n; };
  const json = () => { tag(16); tag(7); need(4); const n = view.getUint32(cursor, true); cursor += 4; tag(15); need(n); cursor += n; };
  const countOffset = cursor + (mode === 0 ? 1 : 0), count = integer(), prefixEnd = cursor;
  if (count < 0 || count > 65535) throw Error('Invalid NUI output count');
  const records = []; let removed = 0;
  for (let i = 0; i < count; i++) {
    const start = cursor, owned = integer() === token;
    string();
    if (minor === 3) { string(); integer(); json(); }
    else if (minor === 4) { json(); if (indexed) integer(); }
    else throw Error('Unsupported NUI output subtype');
    if (owned) removed++; else records.push(bytes.subarray(start, cursor));
  }
  if (cursor !== end) throw Error('Unexpected NUI output tail');
  if (removed === 0) return { bytes, removed };
  if (records.length === 0) return { bytes: null, removed };
  const byteEnd = prefixEnd + records.reduce((n, r) => n + r.length, 0);
  const output = new Uint8Array(byteEnd + bytes.length - end);
  output.set(bytes.subarray(0, prefixEnd));
  const outView = new DataView(output.buffer);
  outView.setUint32(3, byteEnd, true); outView.setInt32(countOffset, records.length, true);
  let at = prefixEnd;
  for (const record of records) { output.set(record, at); at += record.length; }
  output.set(bytes.subarray(end), at);
  return { bytes: output, removed };
}
globalThis.WikiNuiWire = { filterWikiNuiPacket };

if (typeof Process !== 'undefined' && typeof CONFIG !== 'undefined') {
  const base = Process.mainModule.base, address = rva => base.add(rva);
  if (Process.arch !== 'x64') throw Error('Only the verified x64 NWN build is supported');
  for (const [name, spec] of Object.entries(CONFIG.signatures)) {
    const actual = Array.from(new Uint8Array(address(spec.rva).readByteArray(spec.hex.length / 2)), b => b.toString(16).padStart(2, '0')).join('');
    if (actual !== spec.hex) throw Error('In-memory function mismatch: ' + name);
  }
  const state = { active: true, queue: [], inSynthetic: false, opened: false, rendered: 0, received: 0,
    injected: 0, localEvents: 0, filteredOutput: 0, errors: 0, detached: false, collision: false };
  const emptyString = Memory.alloc(32); emptyString.writeByteArray(new Uint8Array(32)); emptyString.add(24).writeU64(15);
  const syntheticMessage = Memory.alloc(0x80);
  const mode = () => address(0x12df970).readPointer().add(0x28).readS32();
  const nativeSetRead = new NativeFunction(address(0x2da7b0), 'int', ['pointer', 'pointer', 'uint', 'uint', 'int']);
  const nativeReceive = new NativeFunction(address(0x7a5f20), 'int', ['pointer', 'uchar']);
  const nativeOverflow = new NativeFunction(address(0x2d9460), 'int', ['pointer']);
  const nativeUnderflow = new NativeFunction(address(0x2d9520), 'int', ['pointer']);
  const sendAddress = address(0x7c25c0);
  const nativeSend = new NativeFunction(sendAddress, 'uint', ['pointer', 'uint', 'uint', 'pointer', 'uint']);
  const listeners = [];
  function stringValue(p) {
    const size = p.add(16).readU64().toNumber();
    if (size > 256) throw Error('Unexpected local widget identifier length');
    return (p.add(24).readU64().compare(15) > 0 ? p.readPointer() : p).readUtf8String(size);
  }
  function reportError(error) { state.errors++; send({ kind: 'error', message: String(error.stack || error) }); }
  function pump(message) {
    if (state.inSynthetic || !state.active || state.queue.length === 0) return;
    state.inSynthetic = true;
    try {
      for (let count = 0; count < 4 && state.queue.length; count++) {
        const job = state.queue.shift();
        const bytes = new Uint8Array(job.bytes), buffer = Memory.alloc(bytes.length + 16);
        buffer.writeByteArray(bytes);
        Memory.copy(syntheticMessage, message, 0x70);
        if (nativeSetRead(syntheticMessage, buffer.add(3), bytes.length - 3, 0xffffffff, 1) !== 1)
          throw Error('Stock SetReadMessage rejected local packet');
        const result = nativeReceive(syntheticMessage, bytes[2]);
        const overflow = nativeOverflow(syntheticMessage), underflow = nativeUnderflow(syntheticMessage);
        state.injected++;
        send({ kind: 'injected', label: job.label, bytes: bytes.length, minor: bytes[2], result, overflow, underflow });
        if (result !== 1 || overflow || underflow) throw Error('Stock NUI receiver rejected local packet');
        if (bytes[2] === 2) state.opened = false;
      }
    } catch (error) { state.queue.length = 0; reportError(error); }
    finally { state.inSynthetic = false; }
  }

  // Block only our token's output, preserving mixed server-owned NUI batches.
  const sendReplacement = new NativeCallback((message, major, minor, buffer, length) => {
    if (!state.active || major !== 55 || (minor !== 3 && minor !== 4))
      return nativeSend(message, major, minor, buffer, length);
    try {
      const filtered = filterWikiNuiPacket(new Uint8Array(buffer.readByteArray(length)), mode(), minor, CONFIG.token, CONFIG.indexedBinds);
      if (filtered.removed) {
        state.filteredOutput += filtered.removed;
        send({ kind: 'filtered-output', count: filtered.removed, minor });
        if (filtered.bytes === null) return 1;
        const replacement = Memory.alloc(filtered.bytes.length); replacement.writeByteArray(filtered.bytes);
        return nativeSend(message, major, minor, replacement, filtered.bytes.length);
      }
      return nativeSend(message, major, minor, buffer, length);
    } catch (error) {
      // An undecodable NUI batch is never allowed to leak a synthetic token.
      reportError(error); return 1;
    }
  }, 'uint', ['pointer', 'uint', 'uint', 'pointer', 'uint']);
  Interceptor.replace(sendAddress, sendReplacement);
  listeners.push(Interceptor.attach(address(0x746130), {
    onEnter(args) {
      if (!state.active || args[0].add(0x230).readU32() !== CONFIG.token) return;
      // Suppress queue insertion by passing a separate, empty element name.
      const type = stringValue(args[1]), element = stringValue(args[2]), index = args[3].toInt32();
      args[2] = emptyString;
      state.localEvents++;
      if (type === 'open') state.opened = true;
      if (type === 'close') state.opened = false;
      send({ kind: 'local-event', type, element, index });
    }
  }));
  listeners.push(Interceptor.attach(address(0x7a41a0), {
    onEnter(args) {
      this.message = args[0];
      if (!state.active) return;
      state.received++;
      const size = args[2].toUInt32(), p = args[1];
      if (size > 16 && p.readU8() === 80 && p.add(1).readU8() === 55 && p.add(2).readU8() === 1) {
        const tokenOffset = 7 + (mode() === 0 ? 3 : 0);
        if (p.add(tokenOffset).readU32() === CONFIG.token) {
          // Yield ownership to a genuine server message instead of suppressing it.
          state.collision = true; state.active = false; state.queue.length = 0;
          send({ kind: 'collision', message: 'Server used the reserved local token; local injector disabled.' });
        }
      }
    },
    onLeave() { pump(this.message); }
  }));

  // This is the actual JsonWindow renderer, not the replacement client's UI.
  if (CONFIG.renderRva) listeners.push(Interceptor.attach(address(CONFIG.renderRva), {
    onEnter(args) {
      if (state.active && args[0].add(0x230).readU32() === CONFIG.token) {
        state.rendered++;
        if (state.rendered === 1) send({ kind: 'native-render', token: CONFIG.token });
      }
    }
  }));

  rpc.exports = {
    status() { return { ...state, queue: state.queue.length, mode: mode(), pid: Process.id }; },
    enqueue(bytes, label) {
      if (!state.active || state.queue.length >= 16) throw Error('Local NUI queue unavailable');
      if (!Array.isArray(bytes) || bytes.length > 256 * 1024 || bytes[0] !== 80 || bytes[1] !== 55 || ![1, 2, 5].includes(bytes[2]))
        throw Error('Invalid local NUI packet');
      state.queue.push({ bytes, label }); return state.queue.length;
    },
    detach() {
      if (state.opened || state.queue.length) throw Error('Close the local window before detaching');
      state.active = false;
      for (const listener of listeners) listener.detach();
      Interceptor.revert(sendAddress); state.detached = true; return true;
    }
  };
  send({ kind: 'ready', pid: Process.id, mode: mode(), token: CONFIG.token });
}
