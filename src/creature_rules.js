export const creatureRoot = object => object.creatureData ?? object.authored;

// Native GFF alignment bytes clamp to 0..100, then map 0..30 /31..69 /70..100
// to the simple alignment enums used by conditional effects.
export function creatureAlignment(root) {
  const good = Math.min(100, Math.max(0, root.GoodEvil ?? 50));
  const lawful = Math.min(100, Math.max(0, root.LawfulChaotic ?? 50));
  return { race: root.Race, goodEvil: good < 31 ? 5 : good > 69 ? 4 : 1, lawChaos: lawful < 31 ? 3 : lawful > 69 ? 2 : 1 };
}
