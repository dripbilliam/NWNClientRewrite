const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));

export function sampleEmitterParticle(properties, index, count) {
  const safeCount = Math.max(1, count);
  const angle = index * GOLDEN_ANGLE;
  const radial = Math.sqrt((index + 0.5) / safeCount);
  const randomA = fract(Math.sin((index + 1) * 127.1) * 43758.5453);
  const randomB = fract(Math.sin((index + 1) * 269.5) * 24634.6345);
  const randomC = fract(Math.sin((index + 1) * 53.7) * 56445.2341);
  const spread = Math.max(0, Math.min(Math.PI, Number(properties.spread) || 0));
  const coneAngle = spread * 0.5 * Math.sqrt(randomA);
  const coneAzimuth = angle + randomB * GOLDEN_ANGLE;
  const coneRadius = Math.sin(coneAngle);
  const direction = [
    coneRadius * Math.cos(coneAzimuth),
    Math.cos(coneAngle),
    coneRadius * Math.sin(coneAzimuth)
  ];
  const velocity = Math.max(0, Number(properties.velocity) || 0);
  const randomVelocity = Math.max(0, Number(properties.randvel) || 0);
  const speed = Math.max(0, velocity + (randomC * 2 - 1) * randomVelocity);
  const width = Math.max(0, Number(properties.xsize) || 0) * 0.01;
  const depth = Math.max(0, Number(properties.ysize) || 0) * 0.01;

  return {
    origin: [
      Math.cos(angle) * radial * width * 0.5,
      0,
      Math.sin(angle) * radial * depth * 0.5
    ],
    velocity: direction.map((component) => component * speed)
  };
}

function fract(value) {
  return value - Math.floor(value);
}