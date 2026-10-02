export const meta = {
  name: 'audit-consistency',
  description: 'Fan out over every web endpoint: verify ACL injection and metadata consistency, then adversarially verify each finding',
  phases: [{ title: 'Inventory' }, { title: 'Audit' }, { title: 'Verify' }],
}

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' }, file: { type: 'string' }, line: { type: 'number' },
          kind: { type: 'string', enum: ['acl-bypass', 'metadata-inconsistency', 'unvalidated-identifier', 'other'] },
          evidence: { type: 'string' },
        },
        required: ['title', 'file', 'kind', 'evidence'],
      },
    },
  },
  required: ['findings'],
}
const VERDICT = {
  type: 'object',
  properties: { isReal: { type: 'boolean' }, reproduction: { type: 'string' }, severity: { type: 'string', enum: ['blocking', 'major', 'minor'] } },
  required: ['isReal', 'reproduction', 'severity'],
}

const inventory = await agent(
  'List every HTTP endpoint (controller class, method, path) under **/internal/web/** in this repository. Return JSON {"endpoints":[{"file":"","method":"","path":""}]}.',
  { label: 'inventory', phase: 'Inventory', schema: { type: 'object', properties: { endpoints: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, method: { type: 'string' }, path: { type: 'string' } }, required: ['file', 'method', 'path'] } } }, required: ['endpoints'] } },
)
if (!inventory) {
  return { error: 'The inventory agent returned nothing, so no endpoint was audited. Run the workflow again.' }
}

const results = await pipeline(
  inventory.endpoints,
  (e) => agent(
    `Audit endpoint ${e.method} ${e.path} in ${e.file}. Check: (1) every query it triggers goes through the query module so ACL conditions are injected; (2) table/field names come from TableName/FieldName value objects; (3) metadata reads and writes happen in one transaction. Report findings with file:line and evidence. No style comments.`,
    { label: `audit:${e.path}`, phase: 'Audit', schema: FINDINGS },
  ),
  (audit) => parallel(((audit && audit.findings) || []).map((f) => () =>
    agent(
      `Adversarially verify this finding by reading the code and, if possible, writing a throwaway test: ${JSON.stringify(f)}. Do not trust the auditor. Return isReal, a reproduction, and severity.`,
      { label: `verify:${f.title}`, phase: 'Verify', schema: VERDICT },
    ).then((v) => ({ ...f, verdict: v })),
  )),
)

const confirmed = results.flat().filter(Boolean).filter((f) => f.verdict?.isReal)
return { endpoints: inventory.endpoints.length, confirmed }
