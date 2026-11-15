import {paginate} from './api.mjs';

const fields = 'id number url title body state stateReason repository { nameWithOwner }';
export const sameIssueState = (issue, card) => issue.state === card.state
  && (card.state === 'OPEN' || issue.stateReason === card.stateReason);

export class GithubRepository {
  constructor(client, config) { this.client = client; this.config = config; }

  async fetchRepository() {
    const [owner, name] = this.config.repository.split('/');
    const data = await this.client.request(
      'query SyncRepository($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { id nameWithOwner hasIssuesEnabled isArchived } }',
      {owner, name});
    const repository = data.repository;
    if (!repository?.id || repository.nameWithOwner?.toLowerCase() !== this.config.repository.toLowerCase()) {
      throw Error('Configured issue repository is unavailable.');
    }
    if (!repository.hasIssuesEnabled || repository.isArchived) throw Error('Issue repository must have Issues enabled and be writable.');
    return repository;
  }

  async fetchIssues(repository) {
    const issues = await paginate(async after => {
      const data = await this.client.request(
        'query SyncRepositoryIssues($id: ID!, $first: Int!, $after: String) { node(id: $id) { ... on Repository { issues(first: $first, after: $after, states: [OPEN, CLOSED], orderBy: {field: CREATED_AT, direction: ASC}) { totalCount nodes { ' + fields + ' } pageInfo { hasNextPage endCursor } } } } }',
        {id: repository.id, first: this.config.pageSize, after});
      return data.node?.issues;
    }, {name: 'GitHub repository issues', maxPages: this.config.maxPages});
    if (issues.some(issue => typeof issue.title !== 'string'
        || typeof issue.body !== 'string' && issue.body !== null
        || !Number.isInteger(issue.number) || !['OPEN', 'CLOSED'].includes(issue.state)
        || issue.repository?.nameWithOwner?.toLowerCase() !== repository.nameWithOwner.toLowerCase())) {
      throw Error('Incomplete GitHub repository issue inventory; importing is unsafe.');
    }
    return issues;
  }

  async create(repository, card) {
    const data = await this.client.request(
      'mutation SyncCreateIssue($input: CreateIssueInput!) { createIssue(input: $input) { issue { ' + fields + ' } } }',
      {input: {repositoryId: repository.id, title: card.title, body: card.body}}, {mutation: true});
    const issue = data.createIssue?.issue;
    if (!issue?.id || !issue.number || issue.repository?.nameWithOwner?.toLowerCase() !== repository.nameWithOwner.toLowerCase()) {
      throw Error('Repository issue creation was not confirmed; reconcile before retrying.');
    }
    return issue;
  }

  async update(issue, card) {
    const data = await this.client.request(
      'mutation SyncUpdateIssue($input: UpdateIssueInput!) { updateIssue(input: $input) { issue { id } } }',
      {input: {id: issue.id, title: card.title, body: card.body}}, {mutation: true});
    if (data.updateIssue?.issue?.id !== issue.id) throw Error('Repository issue update was not confirmed.');
  }

  async setState(issue, card) {
    const change = async open => {
      const field = open ? 'reopenIssue' : 'closeIssue';
      const type = open ? 'ReopenIssueInput' : 'CloseIssueInput';
      const input = {issueId: issue.id, ...(!open && {stateReason: card.stateReason})};
      const data = await this.client.request(
        'mutation SyncIssueState($input: ' + type + '!) { ' + field + '(input: $input) { issue { id state stateReason } } }',
        {input}, {mutation: true});
      const result = data[field]?.issue;
      if (result?.id !== issue.id) throw Error('Repository issue state change was not confirmed.');
      return result;
    };
    let result = await change(card.state === 'OPEN');
    // Some API versions leave the reason unchanged on an already closed issue.
    // Only this explicit reason transition needs a reopen/close pair.
    if (card.state === 'CLOSED' && result.state === 'CLOSED' && result.stateReason !== card.stateReason) {
      const reopened = await change(true);
      if (reopened.state !== 'OPEN') throw Error('Repository issue reopen was not confirmed.');
      result = await change(false);
    }
    if (!sameIssueState(result, card)) throw Error('Repository issue state/reason was not confirmed.');
  }
}
