import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { TGALoader } from 'three/addons/loaders/TGALoader.js';
import './style.css';

const canvas = document.querySelector('#model-canvas');
const viewport = document.querySelector('#viewport-frame');
const fileInput = document.querySelector('#model-file');
const openButton = document.querySelector('#open-button');
const wireButton = document.querySelector('#wireframe-button');
const statusText = document.querySelector('#status-text');
const statusLight = document.querySelector('#connection-light');
const emptyState = document.querySelector('#empty-state');

const scene = new THREE.Scene();
scene.background = new THREE.Color('#19211e');
const camera = new THREE.PerspectiveCamera(42, 1, 0.01, 1000);
camera.position.set(3, 2.5, 3);
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.12;

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.target.set(0, 0.5, 0);

scene.add(new THREE.HemisphereLight(0xdde9e2, 0x202a25, 2.2));
const keyLight = new THREE.DirectionalLight(0xffe0bd, 3.4);
keyLight.position.set(3, 6, 4);
scene.add(keyLight);
const fillLight = new THREE.DirectionalLight(0x91d5c4, 1.3);
fillLight.position.set(-4, 2, -3);
scene.add(fillLight);

const grid = new THREE.GridHelper(10, 20, 0x638279, 0x344840);
grid.material.transparent = true;
grid.material.opacity = 0.5;
scene.add(grid);
const axes = new THREE.AxesHelper(0.7);
scene.add(axes);

let loadedRoot = null;
let loadedTextures = [];
let wireframe = false;

function resizeRenderer() {
  const bounds = viewport.getBoundingClientRect();
  if (!bounds.width || !bounds.height) return;
  renderer.setSize(bounds.width, bounds.height, false);
  camera.aspect = bounds.width / bounds.height;
  camera.updateProjectionMatrix();
}

new ResizeObserver(resizeRenderer).observe(viewport);
window.addEventListener('resize', resizeRenderer);
resizeRenderer();

renderer.setAnimationLoop(() => {
  controls.update();
  renderer.render(scene, camera);
});

openButton.addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', async (event) => {
  const files = [...(event.target.files || [])];
  const file = files.find((item) => item.name.toLowerCase().endsWith('.mdl'));
  if (!file) {
    setStatus('SELECT AN ASCII MDL', false);
    return;
  }
  try {
    setStatus('PARSING MODEL', false);
    const [parsed, textures] = await Promise.all([
      file.text().then(parseAsciiMdl),
      loadTextures(files.filter((item) => item.name.toLowerCase().endsWith('.tga')))
    ]);
    const object = buildObject(parsed, textures);
    if (loadedRoot) {
      scene.remove(loadedRoot);
      loadedRoot.traverse((child) => {
        if (child.isMesh) {
          child.geometry.dispose();
          child.material.dispose();
        }
      });
      loadedTextures.forEach((texture) => texture.dispose());
    }
    loadedRoot = object;
    loadedTextures = [...textures.values()];
    scene.add(loadedRoot);
    frameObject(object);
    updateInspector(parsed, file.name, textures);
    emptyState.classList.add('hidden');
    setStatus('MODEL RENDERED', true);
  } catch (error) {
    console.error(error);
    setStatus(error.message || 'MODEL LOAD FAILED', false);
  } finally {
    fileInput.value = '';
  }
});

wireButton.addEventListener('click', () => {
  wireframe = !wireframe;
  wireButton.setAttribute('aria-pressed', String(wireframe));
  wireButton.textContent = wireframe ? 'Solid' : 'Wireframe';
  loadedRoot?.traverse((object) => {
    if (object.isMesh) object.material.wireframe = wireframe;
  });
});

function setStatus(message, success) {
  statusText.textContent = message.toUpperCase();
  statusLight.style.background = success ? '#45a79a' : '#ce613b';
}

function parseAsciiMdl(text) {
  if (!text.startsWith('#MAXMODEL ASCII')) {
    throw new Error('This viewer currently supports ASCII MDL files only.');
  }

  const lines = text.replaceAll('\r', '').split('\n');
  const nodes = [];
  let modelName = 'unnamed';
  let current = null;
  let inModelGeometry = false;
  let pendingArray = null;

  for (const sourceLine of lines) {
    const line = sourceLine.trim();
    if (!line || line.startsWith('#')) continue;

    if (pendingArray && pendingArray.remaining > 0) {
      const values = line.split(/\s+/).map(Number);
      if (values.some((value) => !Number.isFinite(value))) {
        throw new Error(`Invalid ${pendingArray.kind} data near ${pendingArray.node.name}.`);
      }
      pendingArray.node[pendingArray.kind].push(values);
      pendingArray.remaining -= 1;
      continue;
    }
    pendingArray = null;

    if (line.startsWith('newmodel ')) {
      modelName = line.slice('newmodel '.length).trim();
      continue;
    }
    if (line.startsWith('beginmodelgeom ')) {
      inModelGeometry = true;
      continue;
    }
    if (line.startsWith('endmodelgeom ')) {
      inModelGeometry = false;
      current = null;
      continue;
    }
    if (!inModelGeometry) continue;

    const nodeMatch = line.match(/^node\s+(\S+)\s+(.+)$/i);
    if (nodeMatch) {
      current = {
        type: nodeMatch[1].toLowerCase(),
        name: nodeMatch[2].trim(),
        parent: 'NULL',
        position: [0, 0, 0],
        orientation: [0, 0, 0, 1],
        bitmap: '',
        verts: [],
        tverts: [],
        faces: []
      };
      nodes.push(current);
      continue;
    }
    if (line === 'endnode') {
      current = null;
      continue;
    }
    if (!current) continue;

    let match = line.match(/^parent\s+(.+)$/i);
    if (match) {
      current.parent = match[1].trim();
      continue;
    }
    match = line.match(/^bitmap\s+(\S+)/i);
    if (match) {
      current.bitmap = match[1];
      continue;
    }
    match = line.match(/^position\s+(.+)$/i);
    if (match) {
      current.position = parseNumberList(match[1], 3, current.name);
      continue;
    }
    match = line.match(/^orientation\s+(.+)$/i);
    if (match) {
      current.orientation = parseNumberList(match[1], 4, current.name);
      continue;
    }
    match = line.match(/^(verts|tverts|faces)\s+(\d+)$/i);
    if (match) {
      const kind = match[1].toLowerCase();
      const count = Number(match[2]);
      if (count > 1_000_000) throw new Error(`Unreasonable ${kind} count in ${current.name}.`);
      pendingArray = { kind, node: current, remaining: count };
    }
  }

  if (pendingArray?.remaining > 0) {
    throw new Error(`Truncated ${pendingArray.kind} section in ${pendingArray.node.name}.`);
  }
  if (nodes.length === 0) throw new Error('No model nodes were found.');

  const byName = new Map(nodes.map((node) => [node.name, node]));
  const materialNames = [...new Set(nodes.filter((node) => node.type === 'trimesh' && node.bitmap && node.bitmap.toLowerCase() !== 'null').map((node) => node.bitmap))];
  return { modelName, nodes, byName, materialNames };
}

function parseNumberList(value, length, name) {
  const values = value.split(/\s+/).map(Number);
  if (values.length < length || values.slice(0, length).some((item) => !Number.isFinite(item))) {
    throw new Error(`Invalid transform in node ${name}.`);
  }
  return values.slice(0, length);
}

async function loadTextures(files) {
  const loader = new TGALoader();
  const textures = new Map();
  for (const file of files) {
    const image = loader.parse(await file.arrayBuffer());
    const texture = new THREE.DataTexture(image.data, image.width, image.height, THREE.RGBAFormat);
    texture.flipY = image.flipY;
    texture.generateMipmaps = image.generateMipmaps;
    texture.minFilter = image.minFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.updateMatrix();
    texture.needsUpdate = true;
    textures.set(file.name.replace(/\.tga$/i, '').toLowerCase(), texture);
  }
  return textures;
}

function buildObject(parsed, textures) {
  const root = new THREE.Group();
  root.name = parsed.modelName;
  const groups = new Map();

  for (const node of parsed.nodes) {
    const group = new THREE.Group();
    group.name = node.name;
    group.position.set(node.position[0], node.position[2], -node.position[1]);
    const source = node.orientation;
    const sourceLength = Math.hypot(...source);
    const orientation = sourceLength > 1e-6
      ? new THREE.Quaternion(source[0], source[1], source[2], source[3]).normalize()
      : new THREE.Quaternion();
    const basis = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2);
    group.quaternion.copy(basis).multiply(orientation).multiply(basis.clone().invert());
    groups.set(node.name, group);

    if (node.type === 'trimesh') {
      const mesh = buildMesh(node, textures);
      if (mesh) group.add(mesh);
    }
  }

  for (const node of parsed.nodes) {
    const group = groups.get(node.name);
    const parent = groups.get(node.parent);
    (parent || root).add(group);
  }
  return root;
}

function buildMesh(node, textures) {
  if (node.verts.length === 0 || node.faces.length === 0) return null;
  const positions = [];
  const uvs = [];
  const geometry = new THREE.BufferGeometry();

  for (const face of node.faces) {
    if (face.length < 7) continue;
    const vertexIndices = face.slice(0, 3);
    const uvIndices = face.slice(4, 7);
    for (let corner = 0; corner < 3; corner += 1) {
      const vertex = node.verts[vertexIndices[corner]];
      if (!vertex || vertex.length < 3) throw new Error(`Face index outside vertex array in ${node.name}.`);
      positions.push(vertex[0], vertex[2], -vertex[1]);
      const uv = node.tverts[uvIndices[corner]];
      uvs.push(uv?.[0] ?? 0, uv ? 1 - uv[1] : 0);
    }
  }

  if (positions.length === 0) return null;
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();

  const map = textures.get(node.bitmap.toLowerCase());
  const materialOptions = {
    color: map ? 0xffffff : colorForName(node.bitmap || node.name),
    roughness: 0.78,
    metalness: 0.02,
    side: THREE.DoubleSide
  };
  if (map) {
    materialOptions.map = map;
    materialOptions.alphaTest = 0.035;
  }
  const material = new THREE.MeshStandardMaterial(materialOptions);
  material.name = node.bitmap || 'untextured';
  return new THREE.Mesh(geometry, material);
}

function colorForName(name) {
  let hash = 2166136261;
  for (const char of name.toLowerCase()) hash = Math.imul(hash ^ char.charCodeAt(0), 16777619);
  const hue = ((hash >>> 0) % 360) / 360;
  return new THREE.Color().setHSL(hue, 0.38, 0.57);
}

function frameObject(object) {
  const bounds = new THREE.Box3().setFromObject(object);
  if (bounds.isEmpty()) throw new Error('The model contains no renderable triangle meshes.');
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const longest = Math.max(size.x, size.y, size.z, 0.1);
  const distance = longest * 2.2;
  controls.target.copy(center);
  camera.position.set(center.x + distance, center.y + distance * 0.72, center.z + distance);
  camera.near = Math.max(longest / 1000, 0.001);
  camera.far = longest * 100;
  camera.updateProjectionMatrix();
  controls.update();
  grid.position.y = bounds.min.y;
  axes.position.copy(bounds.min);
}

function updateInspector(parsed, filename, textures) {
  const meshes = parsed.nodes.filter((node) => node.type === 'trimesh' && node.faces.length > 0);
  const vertices = meshes.reduce((total, node) => total + node.verts.length, 0);
  const faces = meshes.reduce((total, node) => total + node.faces.length, 0);
  document.querySelector('#model-title').textContent = parsed.modelName || filename.replace(/\.mdl$/i, '');
  document.querySelector('#node-count').textContent = parsed.nodes.length.toLocaleString();
  document.querySelector('#mesh-count').textContent = meshes.length.toLocaleString();
  document.querySelector('#vertex-count').textContent = vertices.toLocaleString();
  document.querySelector('#face-count').textContent = faces.toLocaleString();
  document.querySelector('#format-value').textContent = 'ASCII MDL';
  document.querySelector('#geometry-value').textContent = `${meshes.length} meshes`;
  document.querySelector('#hierarchy-value').textContent = `${parsed.nodes.length} nodes`;
  const list = document.querySelector('#material-list');
  list.replaceChildren();
  if (parsed.materialNames.length === 0) {
    list.innerHTML = '<span class="muted">No bitmap references</span>';
  } else {
    for (const name of parsed.materialNames) {
      const row = document.createElement('div');
      row.className = 'material-row';
      const swatch = document.createElement('span');
      swatch.className = 'material-swatch';
      swatch.style.background = `#${colorForName(name).getHexString()}`;
      const label = document.createElement('span');
      label.textContent = `${name}${textures.has(name.toLowerCase()) ? ' · TGA' : ''}`;
      row.append(swatch, label);
      list.append(row);
    }
  }
  document.querySelector('#view-caption').textContent = `${parsed.modelName.toUpperCase()} · ASCII MDL`;
}
