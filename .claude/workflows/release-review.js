export const meta = {
  name: 'release-review',
  description: 'Before a release tag: one reviewer per changed file since the last tag, findings ranked and merged',
  phases: [{ title: 'Review' }, { title: 'Rank' }],
}

const FILE_FINDINGS = {
  type: 'object',
  properties: { findings: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, line: { type: 'number' }, severity: { type: 'string', enum: ['blocking', 'major', 'minor'] }, summary: { type: 'string' } }, required: ['file', 'severity', 'summary'] } } },
  required: ['findings'],
}

const files = (args && args.files) || []
if (files.length === 0) {
  return { error: 'Pass args.files: output of `git diff --name-only $(git describe --tags --abbrev=0)..HEAD -- "*.kt" "*.sql"`' }
}

const perFile = await parallel(files.map((file) => () =>
  agent(
    `Review ${file} against REVIEW.md and CLAUDE.md. Only correctness, requirement, security, boundary and migration findings. Cite line numbers.`,
    { label: `review:${file}`, phase: 'Review', schema: FILE_FINDINGS },
  ),
))
const findings = perFile.filter(Boolean).flatMap((r) => r.findings)

const ranked = await agent(
  `Merge and rank these findings; drop duplicates; keep blocking first. Findings: ${JSON.stringify(findings)}. Return the same schema.`,
  { label: 'rank', phase: 'Rank', schema: FILE_FINDINGS },
)
if (!ranked) {
  return { files: files.length, error: 'The rank agent returned nothing; the findings below are unranked.', findings }
}
return { files: files.length, findings: ranked.findings }
