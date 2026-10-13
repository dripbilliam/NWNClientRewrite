import { intEntry } from './combat_stats.js';

// LoadDifficultyInfo 0x1402a7d50: seven physical rows, columns 1..5.
// GetDifficultyOption 0x1402a3b80 reads the unsigned byte for the active level.
export function difficultyOption(table, level, option) {
  if (!table?.columns || !table.orderedRows || !Number.isInteger(level) || level < 0 || level > 4 ||
    !Number.isInteger(option) || option < 0 || option > 6) throw new Error('Native difficulty option state is unavailable');
  const entry = intEntry(table, option, table.columns[level + 1]);
  return entry.found ? entry.value & 255 : 0;
}
