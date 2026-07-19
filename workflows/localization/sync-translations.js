export const meta = {
  name: 'loc-sync',
  description: 'Fill missing translations and refresh stale ones in an .xcstrings catalog, review every change with an internet-enabled Opus pass, then report back',
  whenToUse: 'After adding new user-facing strings, or when Xcode marks translations stale / needs_review. Translates only what is outstanding — approved strings are never touched.',
  phases: [
    { title: 'Scan', detail: 'inventory outstanding units per language' },
    { title: 'Translate', detail: 'one Sonnet pass per language, with the approved corpus as style reference' },
    { title: 'Review', detail: 'Opus reviewer with web access; researches anything below 80% confidence and revises' },
    { title: 'Apply', detail: 'single writer applies all patches to the catalog' },
    { title: 'Report', detail: 'changes and open questions, returned inline — never written to disk' },
  ],
}

// ---------------------------------------------------------------------------
// Inputs. Pass via the Workflow tool's `args`, e.g.
//   { file: 'Rewind/Localizable.xcstrings', languages: ['de', 'fr'] }
// ---------------------------------------------------------------------------

const CATALOG = (args && args.file) || 'Rewind/Localizable.xcstrings'
const HELPER = (args && args.helper) || 'workflows/localization/xcstrings.py'
const SCRATCH = (args && args.scratch) || '.loc-workflow'
const ONLY = (args && args.languages) || null

// The reviewer revises anything it is not comfortable with; this is the bar
// below which it must actually go and research rather than trust its instinct.
const CONFIDENCE_FLOOR = 0.8

const HOUSE_RULES = `
House rules for this catalog (they matter more than literal fidelity):

- These are iOS UI strings. Match what a native speaker sees in Apple's own
  apps on that locale, not a dictionary rendering of the English. The English
  source is a description of intent, not a sentence to be transformed.
- Read the "comment" field. It says where the string appears (button, section
  header, menu picker item, onboarding body). The right register follows from
  that, and a picker item often is not a noun phrase at all.
- Keep the register consistent across the whole language: if buttons use the
  infinitive, every button uses the infinitive; if onboarding body copy is
  imperative, all of it is.
- Preserve every placeholder (%@, %lld, %1$@, {name}) exactly — same set, same
  order-independence. The apply step rejects mismatches outright.
- Preserve leading/trailing whitespace and lone punctuation/emoji strings
  verbatim. A string that is "• " stays "• ".
- Brand names follow the existing corpus. Do not invent a new convention for
  "Google Street View" or "Apple Maps" — look at how the approved strings in
  this language already handle them and match that, even where it looks
  inconsistent in isolation.
- Stay close to the English length. These are buttons, indicators and section
  headers; a translation 1.5x longer than the source breaks layout. Prefer the
  shorter of two equally correct options.
`.trim()

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const SCAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['languages', 'total'],
  properties: {
    total: { type: 'integer' },
    sourceLanguage: { type: 'string' },
    languages: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['code', 'count'],
        properties: {
          code: { type: 'string' },
          count: { type: 'integer' },
        },
      },
    },
  },
}

const DRAFT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['language', 'drafted', 'draftFile'],
  properties: {
    language: { type: 'string' },
    drafted: { type: 'integer' },
    draftFile: { type: 'string' },
    conventions: {
      type: 'string',
      description: 'Register/terminology decisions taken, so the reviewer can check consistency against them',
    },
    lowConfidence: {
      type: 'array',
      description: 'Keys the translator was unsure about, for the reviewer to prioritise',
      items: { type: 'string' },
    },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['language', 'patchFile', 'decisions'],
  properties: {
    language: { type: 'string' },
    patchFile: { type: 'string' },
    decisions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['key', 'english', 'finalValue', 'action'],
        properties: {
          key: { type: 'string' },
          english: { type: 'string' },
          variationPath: { type: 'string' },
          draftValue: { type: 'string' },
          finalValue: { type: 'string' },
          action: {
            type: 'string',
            enum: ['kept', 'revised', 'flagged'],
            description: 'kept = draft accepted as-is; revised = reviewer changed it; flagged = applied but needs a human look',
          },
          confidence: { type: 'number' },
          researched: { type: 'boolean' },
          rationale: { type: 'string' },
          sources: { type: 'array', items: { type: 'string' } },
          openQuestion: { type: 'string' },
        },
      },
    },
  },
}

const APPLY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['applied', 'skipped', 'roundTripsExactly'],
  properties: {
    applied: { type: 'integer' },
    skipped: { type: 'array', items: { type: 'string' } },
    roundTripsExactly: { type: 'boolean' },
    remainingOutstanding: { type: 'string' },
    diffStat: { type: 'string' },
  },
}

// ---------------------------------------------------------------------------
// Phase 1 — Scan
// ---------------------------------------------------------------------------

phase('Scan')

const langFlag = ONLY ? ` --languages ${ONLY.join(',')}` : ''

const scan = await agent(
  `Inventory outstanding translation work in the string catalog.

Run exactly this and read the JSON it prints:

    python3 ${HELPER} inventory ${CATALOG}${langFlag}

The output has a "counts" object mapping each language to how many string units
need work (missing translation, or state stale/needs_review), plus "sourceLanguage".

Also run \`mkdir -p ${SCRATCH}\` so later stages have somewhere to write.

Report every language present in "counts", including ones whose count is 0.
Do not modify any file.`,
  { schema: SCAN_SCHEMA, effort: 'low', label: 'scan' },
)

if (!scan || scan.total === 0) {
  log('Nothing outstanding — every language is fully translated and approved.')
  return { status: 'up-to-date', catalog: CATALOG, scanned: scan }
}

const pending = scan.languages.filter((l) => l.count > 0)
log(`${scan.total} unit(s) outstanding across ${pending.length} language(s): ` +
    pending.map((l) => `${l.code}(${l.count})`).join(', '))

// ---------------------------------------------------------------------------
// Phases 2+3 — Translate, then Review. Pipelined: each language moves to review
// as soon as its own draft is done, rather than waiting on the slowest language.
// ---------------------------------------------------------------------------

const reviews = await pipeline(
  pending,

  // -- Translate -----------------------------------------------------------
  (lang) => agent(
    `You are translating iOS UI strings from ${scan.sourceLanguage || 'en'} into ${lang.code}.

Step 1 — gather context. Run:

    python3 ${HELPER} inventory ${CATALOG} --languages ${lang.code} --reference ${lang.code}

  * \`work.${lang.code}\` is your task list (${lang.count} unit(s)). Each item has
    the English text, the developer "comment", why it needs work ("reason"), any
    existing value, and any placeholders that must be preserved.
  * \`reference\` is the already-approved ${lang.code} corpus. This is your style
    guide and it outranks your own instincts. Mine it for register, brand-name
    handling, and terminology before you translate anything.

Step 2 — translate every item in the task list.

${HOUSE_RULES}

Items with reason "stale" or "needs_review" already have an \`existing\` value:
the English changed underneath it, or a human doubted it. Re-translate from the
current English rather than lightly editing the old value, then sanity-check
your result against the old one.

Step 3 — write your drafts to \`${SCRATCH}/${lang.code}.draft.json\`:

    {"language": "${lang.code}", "updates": [
      {"key": "<exact catalog key>", "value": "<translation>",
       "variationPath": "<only if the task item had one>",
       "confidence": 0.0-1.0, "note": "<why, if non-obvious>"}
    ]}

The "key" must be the catalog key verbatim — for symbolic keys like
\`comparison_title\` that is the key, NOT the English text. Write the file with
a script rather than by hand so quoting and unicode survive intact.

Be honest with "confidence". It routes the reviewer's research effort: below
${CONFIDENCE_FLOOR} means "I guessed at the context or the idiom". Do NOT touch
${CATALOG} — you are producing a draft, not editing the catalog.`,
    { model: 'sonnet', schema: DRAFT_SCHEMA, phase: 'Translate', label: `draft:${lang.code}` },
  ),

  // -- Review --------------------------------------------------------------
  (draft, lang) => {
    if (!draft) return null
    return agent(
      `You are the final reviewer for ${lang.code} translations of an iOS app's UI strings.
You have web access and you are expected to use it.

First: load the web tools. Call ToolSearch with the query
\`select:WebSearch,WebFetch\` before anything else — their schemas are not loaded
by default and you cannot call them until you do.

Inputs:
  * \`${SCRATCH}/${lang.code}.draft.json\` — proposed translations from a first pass.
  * \`python3 ${HELPER} inventory ${CATALOG} --languages ${lang.code} --reference ${lang.code}\`
    — the task list (English, comment, placeholders, prior value) and the
    approved ${lang.code} corpus.
  * Conventions the drafter says it followed: ${draft.conventions || '(none reported)'}
  * Drafter's own low-confidence keys: ${(draft.lowConfidence || []).join(', ') || '(none)'}

For every proposed translation, judge how confident you are that it is what a
native ${lang.code} speaker would expect to see in this exact UI position.

**If your confidence is below ${CONFIDENCE_FLOOR}, go and research it.** Do not
guess and do not wave it through. Useful things to check on the web:
  * how Apple's own ${lang.code} localization renders the same UI concept
    (sort orders, "Get started", map types, permission prompts);
  * what the app or feature being named actually is, when the English is
    ambiguous — e.g. a brand name, a map layer, a photo-library concept;
  * whether a brand name is localized at all in ${lang.code} (Google Maps,
    Apple Maps, Street View all differ by locale);
  * grammar you are unsure of — case, gender agreement, aspect, verb mood.

${HOUSE_RULES}

Check specifically for:
  * register drift against the approved corpus (an imperative button among
    infinitive buttons, formal vs informal address);
  * literal calques where the corpus uses a platform idiom;
  * brand-name handling that contradicts existing approved strings;
  * translations materially longer than the English on buttons and indicators;
  * placeholder set changes, and lost leading/trailing whitespace.

You may and should revise. Then write the FINAL values to
\`${SCRATCH}/${lang.code}.patch.json\`:

    {"language": "${lang.code}", "updates": [
      {"key": "...", "value": "<final>", "variationPath": "<if any>"}
    ]}

Every unit from the task list must appear exactly once. Write the file with a
script, not by hand. Do NOT edit ${CATALOG} — a later stage applies the patch.

Then report a decision per unit. Set \`action\` to "kept" if you accepted the
draft unchanged, "revised" if you changed it, "flagged" if you are applying it
but a human should look. Set \`researched: true\` and list \`sources\` (URLs)
wherever you actually went to the web. Put anything you could not resolve into
\`openQuestion\` — that is what reaches the human, so phrase it as a real
question, not a note to yourself.`,
      { model: 'opus', schema: REVIEW_SCHEMA, effort: 'high', phase: 'Review', label: `review:${lang.code}` },
    )
  },
)

const approved = reviews.filter(Boolean)
if (approved.length === 0) {
  log('Every language failed before producing a patch — nothing to apply.')
  return { status: 'failed', catalog: CATALOG }
}
if (approved.length < pending.length) {
  const done = new Set(approved.map((r) => r.language))
  log(`WARNING: no patch produced for ${pending.filter((l) => !done.has(l.code)).map((l) => l.code).join(', ')} — those languages are unchanged.`)
}

// ---------------------------------------------------------------------------
// Phase 4 — Apply. Deliberately a single serial agent: the catalog is one file
// and parallel writers would clobber each other.
// ---------------------------------------------------------------------------

phase('Apply')

const patchList = approved.map((r) => `${SCRATCH}/${r.language}.patch.json`).join(' ')

const applied = await agent(
  `Apply the reviewed translation patches to the string catalog.

1. Dry run first and read the output:

       python3 ${HELPER} apply ${CATALOG} ${patchList} --dry-run

   A non-empty "skipped" list means malformed updates (unknown key, empty
   value, placeholder mismatch). Report those verbatim — do NOT try to repair
   the patch files by inventing values.

2. If nothing is skipped, apply for real (drop --dry-run).

3. Verify:

       python3 ${HELPER} verify ${CATALOG}
       git -C . diff --stat -- ${CATALOG}

   "roundTripsExactly" must be true — it means the file still matches Xcode's
   own serialization and the diff contains only real content changes. The diff
   stat should be roughly two changed lines per applied string; if it shows the
   whole file rewritten, something reformatted it — say so loudly.

Report the counts, any skipped entries, and the remaining outstanding counts
from verify. Do not attempt to fix problems you find; just report them.`,
  { schema: APPLY_SCHEMA, effort: 'low', label: 'apply' },
)

// ---------------------------------------------------------------------------
// Phase 5 — Report
// ---------------------------------------------------------------------------

phase('Report')

const report = await agent(
  `Write the run report for this localization pass.

**Return the report as your reply text. Do NOT write it to a file.** No Write
tool, no \`>\` redirect, no \`mkdir\`. The report is read once in the terminal and
then thrown away — it must never end up in the working tree, because it would
land in a commit. Your entire return value is the markdown itself, starting at
the \`#\` heading.

Catalog: ${CATALOG}
Apply result: ${JSON.stringify(applied)}

Per-language review decisions:
${JSON.stringify(approved)}

Structure the report as:

# Localization sync — <date>

## Summary
Languages touched, how many strings each, how many the reviewer revised vs
accepted, and whether anything was skipped by the apply step.

## Changes
One subsection per language. A table of every string that changed, with
columns: key, English source, final translation, and what happened
("accepted", or the reason it was revised). **Always identify a string by its
catalog key AND its English source text** — the reader does not read
${scan.sourceLanguage || 'en'}-into-every-language and needs both to find it.
Group "accepted unchanged" rows together and keep them terse; spend the space
on revisions.

## Researched
Only the strings where the reviewer actually went to the web. What was
uncertain, what it found, and the source URLs. Skip this section if empty.

## Open questions
Every \`openQuestion\` and every \`flagged\` decision, as a checklist the
developer can act on. Each item: the key + English text, what is uncertain, and
what a decision would need. This is the most important section — if a reviewer
was unsure about brand-name handling or register, that is a project-wide
convention question and it belongs here, phrased so it can be answered without
re-reading the whole catalog. If there are genuinely none, say so explicitly.

Write in the same language the developer works in — the repo's existing docs and
commit messages are the guide. Be concrete and skip filler; this gets read once,
right after the run, by someone deciding what to double-check.`,
  { effort: 'medium', label: 'report' },
)

return {
  status: 'done',
  catalog: CATALOG,
  outstandingBefore: scan.total,
  languages: approved.map((r) => ({
    code: r.language,
    changed: r.decisions.length,
    revised: r.decisions.filter((d) => d.action === 'revised').length,
    flagged: r.decisions.filter((d) => d.action === 'flagged').length,
    researched: r.decisions.filter((d) => d.researched).length,
  })),
  apply: applied,
  report,
  scratch: SCRATCH,
}
