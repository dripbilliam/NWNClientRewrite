export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function choice(env, name, fallback, values) {
  const value = env[name] || fallback;
  if (!values.includes(value)) throw Error(name + ' must be one of: ' + values.join(', '));
  return value;
}

function integer(env, name, fallback, minimum, maximum) {
  const text = env[name] || String(fallback);
  if (!/^\d+$/.test(text)) throw Error(name + ' must be an integer.');
  const value = Number(text);
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw Error(name + ' is outside its supported range.');
  }
  return value;
}

function boolean(env, name, fallback) {
  if (!env[name]) return fallback;
  if (!['true', 'false'].includes(env[name])) throw Error(name + ' must be true or false.');
  return env[name] === 'true';
}

export function loadConfig(env = process.env) {
  const teamId = env.LINEAR_TEAM_ID || '';
  const projectId = env.LINEAR_PROJECT_ID || '';
  if (!teamId && !projectId) throw Error('Set LINEAR_TEAM_ID and/or LINEAR_PROJECT_ID to a UUID.');
  for (const value of [teamId, projectId].filter(Boolean)) {
    if (!UUID.test(value)) throw Error('Linear scope identifiers must be UUIDs, not names or URLs.');
  }
  const owner = env.GH_PROJECT_OWNER || 'dripbilliam';
  if (!/^[a-z\d](?:[a-z\d-]{0,38})$/i.test(owner)) throw Error('Invalid GH_PROJECT_OWNER.');
  const namespace = env.SYNC_NAMESPACE || 'nwnanalog-public-roadmap';
  if (!/^[a-z0-9][a-z0-9._/-]{0,99}$/.test(namespace)) throw Error('Invalid SYNC_NAMESPACE.');
  let statusMapping;
  try { statusMapping = JSON.parse(env.STATUS_MAPPING_JSON || '{}'); }
  catch { throw Error('STATUS_MAPPING_JSON must be a JSON object.'); }
  if (!statusMapping || Array.isArray(statusMapping) || typeof statusMapping !== 'object'
      || Object.entries(statusMapping).some(([key, value]) => !key || typeof value !== 'string' || !value.trim())) {
    throw Error('STATUS_MAPPING_JSON must map status names or UUIDs to GitHub option names.');
  }
  const publicLabel = env.LINEAR_PUBLIC_LABEL || 'public';
  if (!publicLabel.trim()) throw Error('LINEAR_PUBLIC_LABEL must not be blank.');
  return {
    teamId, projectId, owner, namespace, publicLabel, statusMapping,
    projectNumber: integer(env, 'GH_PROJECT_NUMBER', 0, 1, 2147483647),
    ownerType: choice(env, 'GH_PROJECT_OWNER_TYPE', 'user', ['user', 'organization']),
    publicationMode: choice(env, 'PUBLICATION_MODE', 'label', ['label', 'all']),
    descriptionMode: choice(env, 'DESCRIPTION_MODE', 'title-only', ['title-only', 'approved', 'full']),
    removalPolicy: choice(env, 'REMOVAL_POLICY', 'leave', ['leave', 'remove', 'archive-status']),
    archiveStatus: env.ARCHIVE_STATUS || 'Cancelled',
    unknownStatusPolicy: choice(env, 'UNKNOWN_STATUS_POLICY', 'skip', ['skip', 'fallback', 'error']),
    fallbackStatus: env.STATUS_FALLBACK || 'Backlog',
    statusField: env.GH_STATUS_FIELD || 'Status',
    includeArchived: boolean(env, 'PUBLISH_ARCHIVED_ISSUES', false),
    allowEmptySource: boolean(env, 'ALLOW_EMPTY_SOURCE_REMOVALS', false),
    requirePublicProject: boolean(env, 'REQUIRE_PUBLIC_PROJECT', true),
    maxRemovals: integer(env, 'MAX_REMOVALS', 10, 0, 10000),
    pageSize: integer(env, 'SYNC_PAGE_SIZE', 50, 1, 100),
    maxPages: integer(env, 'SYNC_MAX_PAGES', 1000, 1, 10000),
    maxRetries: integer(env, 'SYNC_MAX_RETRIES', 4, 0, 10),
    timeoutMs: integer(env, 'SYNC_REQUEST_TIMEOUT_MS', 30000, 100, 120000),
  };
}
