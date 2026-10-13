const f = Math.fround;

// Port of CNWSTrigger::InTrigger's upward ray crossing rules. It uses native
// world XY, ignores Z and radius, and treats vertices separately from edges.
export function inTrigger(trigger, point) {
  const vertices = trigger.geometry ?? [];
  const x = f(point[0]), y = f(-point[2]);
  let crossings = 0;
  for (let i = 0; i < vertices.length; i++) {
    const [ax, ay] = vertices[i], [bx, by] = vertices[(i + 1) % vertices.length];
    if (bx !== ax) {
      const dx = f(bx - ax), dy = f(by - ay);
      const intersection = f(ay - f(f(dy / dx) * f(ax - x)));
      if (intersection > y) {
        if (Math.abs(dy) > Math.abs(dx)) {
          if (by > ay ? intersection >= ay && intersection < by : ay > by && intersection > by && intersection <= ay) crossings++;
        } else if (bx > ax ? x >= ax && x < bx : ax > bx && x > bx && x <= ax) crossings++;
      }
    }
    if (bx === x && (by > y || ay >= y)) crossings++;
  }
  return crossings % 2 === 1;
}

export function triggerGeometry(entry) {
  const x = f(entry.XPosition ?? 0), y = f(entry.YPosition ?? 0);
  return (entry.Geometry ?? []).map(v => [f(x + f(v.PointX)), f(y + f(v.PointY))]);
}

// ReadEncounterFromGff14043d5f3..14043da59, authored-instance flag0.
// Encounters use X/Y/Z fields, unlike trigger PointX/PointY/PointZ. Missing
// Geometry leaves the constructor's empty polygon; a present empty list
// rejects the instance. Template flag1's generated 15-unit square is separate.
export function encounterGeometry(entry) {
  if (!Object.hasOwn(entry, 'Geometry')) return [];
  if (!Array.isArray(entry.Geometry) || entry.Geometry.length === 0)
    throw new Error('Native encounter has geometry but no vertices; skipping instance');
  const x = f(entry.XPosition ?? 0), y = f(entry.YPosition ?? 0);
  return entry.Geometry.map(v => [f(x + f(v.X ?? 0)), f(y + f(v.Y ?? 0))]);
}
