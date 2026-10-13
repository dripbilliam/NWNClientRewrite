export const GAME_PANELS = Object.freeze([
  ['journal', 'Journal', 'j'], ['inventory', 'Inventory', 'i'], ['character', 'Character Sheet', 'c'],
  ['map', 'Map', 'm'], ['spells', 'Spellbook', 'b'], ['options', 'Options', 'o'],
  ['dialogue', 'Conversation', null], ['store', 'Store', null], ['barter', 'Barter', null],
  ['party', 'Party', null], ['examine', 'Examine', null], ['main', 'Main Menu', null]
]);

export function nativeControlKind(record) {
  if (record.Obj_Type === 5) return 'label';
  if (record.Obj_Type === 6) return 'slider';
  if (record.Obj_Type === 2) return 'checkbox';
  if (record.Obj_Type === 8) {
    const model = String(record.Obj_ResRef ?? '').toLowerCase();
    if (/lst|list|load|spell|cleric|opt_vid|saveinfo|movies/.test(model)) return 'list';
    if (/txtbox|textbox|chathis|jnl|info|hlp/.test(model)) return 'text';
    return 'edit';
  }
  return [1, 9, 11].includes(record.Obj_Type) ? 'button' : 'art';
}

export function journalRows(player, definitions, text, { tab = 'quests', sort = 'name' } = {}) {
  const rows = [...(player?.journal ?? [])].flatMap(([tag, state], order) => {
    const category = definitions.get(tag), entry = category?.EntryList?.find(e => e.ID === state);
    if (!entry || Boolean(entry.End) !== (tab === 'completed')) return [];
    return [{ tag, state, name: text.resolve(category.Name, tag), text: text.resolve(entry.Text), completed: Boolean(entry.End), priority: category.Priority ?? 0, order }];
  });
  return rows.sort(sort === 'priority' ? (a, b) => a.priority - b.priority || a.name.localeCompare(b.name) : sort === 'received' ? (a, b) => a.order - b.order : (a, b) => a.name.localeCompare(b.name));
}

// This is client presentation state. Game objects, journal quest state and item
// ownership stay in ModuleSession, never in a second UI object registry.
export class GameUiState {
  constructor() { this.stack = []; this.quickbarPage = 0; this.quickbar = Array.from({ length: 3 }, () => Array(12).fill(null)); this.journalTab = 'quests'; this.journalSort = 'name'; this.selectedQuest = null; this.notes = new Map(); }
  get panel() { return this.stack.at(-1) ?? null; }
  open(panel) { if (this.panel === panel) return; this.stack.push(panel); }
  toggle(panel) { if (this.panel === panel) this.close(); else { this.stack = []; this.open(panel); } }
  close() { return this.stack.pop(); }
  reset() { this.stack = []; this.quickbar = Array.from({ length: 3 }, () => Array(12).fill(null)); this.quickbarPage = 0; this.selectedQuest = null; this.notes.clear(); }
  bind(page, slot, request) {
    if (!Number.isInteger(page) || page < 0 || page > 2 || !Number.isInteger(slot) || slot < 0 || slot > 11) throw new Error('Invalid quickbar slot');
    this.quickbar[page][slot] = request ? { ...request } : null;
  }
  activate(page, slot, registry, actorId) {
    const request = this.quickbar[page]?.[slot]; if (!request) return null;
    if (!registry.get(actorId) || request.targetId !== undefined && !registry.get(request.targetId)) return null;
    return { ...request, actorId, areaId: registry.get(actorId).areaId };
  }
}
