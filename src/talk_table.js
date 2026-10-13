import { runtimeDiagnostics } from './runtime_diagnostics.js';
// TLK V3.0 strings are loaded from the user's installation, never bundled.
export function parseTalkTable(input) {
  const bytes = input instanceof ArrayBuffer ? new Uint8Array(input) : new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const tag = (offset, length) => new TextDecoder('ascii').decode(bytes.subarray(offset, offset + length));
  if (bytes.length < 20 || tag(0, 8) !== 'TLK V3.0') throw new Error('Unsupported TLK header');
  const language = view.getUint32(8, true), count = view.getUint32(12, true), textOffset = view.getUint32(16, true);
  if (count > 1_000_000 || 20 + count * 40 > bytes.length || textOffset < 20 + count * 40 || textOffset > bytes.length) throw new Error('Invalid TLK tables');
  const encodings = { 0: 'windows-1252', 1: 'windows-1252', 2: 'windows-1252', 3: 'windows-1252', 4: 'windows-1252', 5: 'windows-1250', 128: 'euc-kr', 129: 'big5', 130: 'gbk', 131: 'shift-jis' };
  const decoder = new TextDecoder(encodings[language] ?? 'windows-1252');
  const cache = new Map();
  return { language, count, get(index) {
    if (!Number.isInteger(index) || index < 0 || index >= count) return undefined;
    if (cache.has(index)) return cache.get(index);
    const offset = 20 + index * 40;
    if (!(view.getUint32(offset, true) & 1)) return '';
    const start = textOffset + view.getUint32(offset + 28, true), length = view.getUint32(offset + 32, true);
    if (start < textOffset || start + length > bytes.length) throw new Error(`TLK string ${index} is out of bounds`);
    const text = decoder.decode(bytes.subarray(start, start + length)); cache.set(index, text); return text;
  } };
}

export class GameText {
  constructor({ base = null, custom = null, language = 0, female = false } = {}) { Object.assign(this, { base, custom, language, female }); this.missing = new Set(); }
  strRef(ref) {
    if (!Number.isInteger(ref) || ref < 0 || ref === 0xffffffff) return undefined;
    const text = ref & 0x01000000 ? this.custom?.get(ref & 0x00ffffff) : this.base?.get(ref);
    if (text === undefined && !this.missing.has(ref)) {
      this.missing.add(ref); runtimeDiagnostics.record('text.lookup-failed', `Talk-table string ${ref} is unavailable; localized text may provide a fallback`, { strRef: ref, table: ref & 0x01000000 ? 'custom' : 'base', language: this.language }, 'info');
    }
    return text;
  }
  resolve(value, fallback = '') {
    if (typeof value === 'string') return value;
    if (!value) return fallback;
    const id = this.language * 2 + Number(this.female);
    const embedded = value.entries?.find(e => e.languageId === id) ?? value.entries?.find(e => e.languageId === this.language * 2);
    // Localized resource text explicitly supplied by a module wins over a TLK fallback.
    return embedded?.text ?? this.strRef(value.strRef ?? value.Obj_StrRef) ?? value.AurString_Text ?? value.entries?.[0]?.text ?? fallback;
  }
}
