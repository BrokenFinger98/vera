export const meta = {
  name: 'deep-research',
  description: 'Design-decision research: three independent researchers, one synthesiser, evidence with dates and URLs',
  phases: [{ title: 'Research' }, { title: 'Synthesise' }],
}

const question = (args && args.question) || null
if (!question) return { error: 'Pass args.question' }

const REPORT = { type: 'object', properties: { summary: { type: 'string' }, sources: { type: 'array', items: { type: 'string' } } }, required: ['summary', 'sources'] }

const angles = ['official documentation and vendor release notes', 'independent benchmarks, papers and post-mortems', 'production experience reports and known traps']
const reports = await parallel(angles.map((angle) => () =>
  agent(`Research: "${question}". Angle: ${angle}. Today is the current date; prefer sources from the last 12 months and date every claim. Return a summary and source URLs.`,
    { label: `research:${angle}`, phase: 'Research', schema: REPORT }),
))
const delivered = reports.filter(Boolean)
if (delivered.length === 0) return { error: 'All three researchers returned nothing, so there is nothing to synthesise. Run the workflow again.' }

const synthesis = await agent(
  `Synthesise these reports into a decision memo with Options / Evidence / Recommendation / Accepted costs, in English, suitable as an ADR draft: ${JSON.stringify(delivered)}`,
  { label: 'synthesise', phase: 'Synthesise', schema: REPORT },
)
return synthesis || { error: 'The synthesiser returned nothing; the research reports follow.', reports: delivered }
