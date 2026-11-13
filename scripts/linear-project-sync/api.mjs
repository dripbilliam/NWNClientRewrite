import {setTimeout as delay} from 'node:timers/promises';

export class ApiError extends Error {
  constructor(service, status, codes, {ambiguous = false} = {}) {
    const hint = status === 401 ? 'Check the API credential.'
      : status === 403 ? 'Check project access, token permissions and rate limits.'
        : codes.includes('RATELIMITED') || codes.includes('RATE_LIMITED') || status === 429
          ? 'Rate limit reached; retry later.' : 'Request failed; check API availability and configuration.';
    // Never echo provider messages, response bodies, request variables or tokens.
    super(service + ' API error (HTTP ' + status + '). ' + hint);
    this.name = 'ApiError';
    this.status = status;
    this.codes = codes;
    this.ambiguous = ambiguous;
  }
}

function retryDelay(headers, attempt, now) {
  const retryAfter = headers.get('retry-after');
  if (retryAfter) {
    const seconds = Number(retryAfter);
    return Math.max(0, Number.isFinite(seconds) ? seconds * 1000 : Date.parse(retryAfter) - now);
  }
  const resets = [
    Number(headers.get('x-ratelimit-reset')) * 1000,
    Number(headers.get('x-ratelimit-requests-reset')),
    Number(headers.get('x-ratelimit-endpoint-requests-reset')),
  ].filter(value => value > now);
  return resets.length ? Math.max(...resets) - now : Math.min(30000, 1000 * 2 ** attempt);
}

export function createGraphqlClient({service, token, config, readOnly = false,
  fetchImpl = fetch, sleep = delay, now = Date.now, logger = console}) {
  if (!token || /[\r\n]/.test(token)) throw Error('A valid ' + service + ' API credential is required.');
  const linear = service === 'Linear';
  const url = linear ? 'https://api.linear.app/graphql' : 'https://api.github.com/graphql';
  let lastMutationFinishedAt = null;
  return {
    async request(query, variables = {}, {mutation = false} = {}) {
      if (readOnly && (mutation || /^\s*mutation\b/.test(query))) throw Error('Read-only API client rejects mutations.');
      const isMutation = mutation || /^\s*mutation\b/.test(query);
      for (let attempt = 0; ; attempt++) {
        let response, payload;
        if (isMutation && lastMutationFinishedAt !== null) {
          // GitHub recommends at least one second between mutative requests.
          // This also keeps an initial backlog import below content burst limits.
          const wait = Math.max(0, 1000 - (now() - lastMutationFinishedAt));
          if (wait) await sleep(wait);
        }
        try {
          response = await fetchImpl(url, {
            method: 'POST', redirect: 'error', signal: AbortSignal.timeout(config.timeoutMs),
            headers: {'Content-Type': 'application/json', 'User-Agent': 'NWNAnalog-Linear-Project-Sync',
              Authorization: linear ? token : 'Bearer ' + token},
            body: JSON.stringify({query, variables}),
          });
          payload = await response.json();
        } catch {
          if (response && [401, 403].includes(response.status)) {
            throw new ApiError(service, response.status, [], {ambiguous: isMutation});
          }
          if (isMutation) throw new ApiError(service, response?.status || 0, [], {ambiguous: true});
          if (attempt >= config.maxRetries) throw new ApiError(service, response?.status || 0, []);
          logger.warn(service + ' query transport failure; retrying (' + (attempt + 1) + ').');
          await sleep(Math.min(30000, 1000 * 2 ** attempt));
          continue;
        } finally {
          if (isMutation) lastMutationFinishedAt = now();
        }
        const errors = Array.isArray(payload?.errors) ? payload.errors : [];
        const codes = errors.map(error => error.extensions?.code || error.type || '').filter(Boolean);
        const rateLimited = response.status === 429 || codes.some(code => /RATE.?LIMIT/i.test(code))
          || response.status === 403 && (response.headers.get('retry-after') !== null
            || response.headers.get('x-ratelimit-remaining') === '0');
        const failed = !response.ok || errors.length || !payload?.data
          || payload.errors !== undefined && !Array.isArray(payload.errors);
        if (!failed) return payload.data;
        // Draft creation is not an idempotent API operation. No mutation is
        // blindly replayed, even after a timeout, 5xx or partial GraphQL result.
        if (!isMutation && (rateLimited || response.status >= 500) && attempt < config.maxRetries) {
          const wait = retryDelay(response.headers, attempt, now());
          if (!Number.isFinite(wait) || wait > 60000) {
            throw new ApiError(service, response.status, codes);
          }
          logger.warn(service + ' query temporarily unavailable; retrying in ' + Math.ceil(wait / 1000) + 's.');
          await sleep(wait);
          continue;
        }
        throw new ApiError(service, response.status, codes, {ambiguous: isMutation});
      }
    },
  };
}

export async function paginate(fetchPage, {name, maxPages = 1000} = {}) {
  const nodes = [], cursors = new Set(), ids = new Set();
  let after = null, totalCount;
  for (let page = 0; page < maxPages; page++) {
    const connection = await fetchPage(after);
    if (!connection || !Array.isArray(connection.nodes)
        || typeof connection.pageInfo?.hasNextPage !== 'boolean'
        || connection.nodes.some(node => !node || typeof node.id !== 'string')) {
      throw Error('Incomplete ' + name + ' response; no synchronization is safe.');
    }
    if (connection.totalCount !== undefined) {
      if (!Number.isInteger(connection.totalCount) || connection.totalCount < 0
          || totalCount !== undefined && totalCount !== connection.totalCount) {
        throw Error(name + ' changed during pagination; rerun.');
      }
      totalCount = connection.totalCount;
    }
    for (const node of connection.nodes) {
      if (ids.has(node.id)) throw Error('Duplicate result during ' + name + ' pagination; rerun.');
      ids.add(node.id); nodes.push(node);
    }
    if (!connection.pageInfo.hasNextPage) {
      if (totalCount !== undefined && nodes.length !== totalCount) {
        throw Error('Truncated ' + name + ' response; rerun.');
      }
      return nodes;
    }
    const cursor = connection.pageInfo.endCursor;
    if (!connection.nodes.length || typeof cursor !== 'string' || !cursor || cursors.has(cursor)) {
      throw Error('Invalid cursor during ' + name + ' pagination; rerun.');
    }
    cursors.add(cursor); after = cursor;
  }
  throw Error(name + ' exceeded SYNC_MAX_PAGES; no synchronization is safe.');
}
