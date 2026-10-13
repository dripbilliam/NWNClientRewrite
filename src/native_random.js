// Target CRT rand() at 0x140c7ed00, used by CNWRules::RollDice 0x1402ad680.
// This is a local simulation stream. Native game startup seeding and the full
// draw order require independent observation; sharing a seed is not parity.
export class NativeRandom {
  constructor(seed = 1) { this.seed(seed); }
  seed(value) {
    if (!Number.isInteger(value) || value < 0 || value > 0xffffffff) throw new Error('Invalid native RNG seed');
    this.state = value >>> 0; this.draws = 0;
  }
  next() {
    this.state = (Math.imul(this.state, 0x343fd) + 0x269ec3) >>> 0;
    this.draws++;
    return (this.state >>> 16) & 0x7fff;
  }
  dice(count, sides) {
    count &= 255; sides &= 255;
    if (!sides) return 0;
    let total = 0;
    for (let i = 0; i < count; i++) total = (total + this.next() % sides + 1) & 65535;
    return total;
  }
  random(maximum) {
    maximum |= 0;
    if (!maximum) return 0;
    const result = this.next() % maximum;
    return maximum < 0 ? -result : result;
  }
  scriptDice(count, sides) { return this.dice(Math.max(1, count | 0), sides); }
}
