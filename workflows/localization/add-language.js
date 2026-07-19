export const meta = {
  name: 'loc-add-language',
  description: 'Add a brand-new language to an .xcstrings catalog: research the locale conventions, translate the whole catalog in chunks, review every string with an internet-enabled Opus pass, harmonise across chunks, then report back',
  whenToUse: 'When shipping a locale the catalog does not have yet. Pass the BCP-47 code as args, e.g. "pl" or { language: "pt-BR" }.',
  phases: [
    { title: 'Prepare', detail: 'inventory the full catalog and split it into chunks' },
    { title: 'Research', detail: 'Opus + web: build a locale style guide and domain glossary' },
    { title: 'Translate', detail: 'Sonnet per chunk, against the style guide' },
    { title: 'Review', detail: 'Opus + web per chunk; researches anything below 80% confidence' },
    { title: 'Harmonise', detail: 'one Opus pass over the whole language for cross-chunk consistency' },
    { title: 'Apply', detail: 'single writer applies the patch to the catalog' },
    { title: 'Report', detail: 'decisions and open questions, returned inline — never written to disk' },
  ],
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

const LANG = typeof args === 'string' ? args : args && (args.language || args.lang)
if (!LANG) {
  throw new Error('add-language needs a language code — pass args: "pl" or { language: "pt-BR" }')
}

const CATALOG = (args && args.file) || 'Rewind/Localizable.xcstrings'
const HELPER = (args && args.helper) || 'workflows/localization/xcstrings.py'
const SCRATCH = `${(args && args.scratch) || '.loc-workflow'}/${LANG}`
const CHUNK_SIZE = (args && args.chunkSize) || 25
const CONFIDENCE_FLOOR = 0.8

const HOUSE_RULES = `
House rules for this catalog:

- These are iOS UI strings. Match what a native speaker sees in Apple's own
  apps on this locale, not a dictionary rendering of the English. The English
  source describes intent; it is not a sentence to be transformed word by word.
- Read the "comment" field. It says where the string appears (button, section
  header, menu picker item, onboarding body, error alert). Register follows
  from that, and a picker item is often not a noun phrase at all.
- Preserve every placeholder (%@, %lld, %1$@, {name}) exactly. The apply step
  rejects mismatches outright.
- Preserve leading/trailing whitespace and lone punctuation/emoji strings
  verbatim. A string that is "• " stays "• ". A string that is "👀" stays "👀".
- Stay close to the English length. These are buttons, indicators and section
  headers; a translation much longer than the source breaks layout. Prefer the
  shorter of two equally correct options.
`.trim()

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const PREPARE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['alreadyPresent', 'unitCount', 'chunkFiles'],
  properties: {
    alreadyPresent: {
      type: 'boolean',
      description: `true if ${LANG} already has translations in the catalog`,
    },
    existingCoverage: { type: 'string' },
    sourceLanguage: { type: 'string' },
    unitCount: { type: 'integer' },
    chunkFiles: { type: 'array', items: { type: 'string' } },
    referenceLanguages: { type: 'array', items: { type: 'string' } },
    contextFile: { type: 'string' },
  },
}

const GUIDE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['guideFile', 'summary'],
  properties: {
    guideFile: { type: 'string' },
    summary: {
      type: 'string',
      description: 'The style guide condensed to something a translator can hold in mind: address form, button mood, brand policy, typography',
    },
    glossary: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['term', 'translation'],
        properties: {
          term: { type: 'string' },
          translation: { type: 'string' },
          rationale: { type: 'string' },
          source: { type: 'string' },
        },
      },
    },
    openQuestions: { type: 'array', items: { type: 'string' } },
  },
}

const DRAFT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['chunk', 'drafted', 'draftFile'],
  properties: {
    chunk: { type: 'string' },
    drafted: { type: 'integer' },
    draftFile: { type: 'string' },
    lowConfidence: { type: 'array', items: { type: 'string' } },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['chunk', 'patchFile', 'decisions'],
  properties: {
    chunk: { type: 'string' },
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
          action: { type: 'string', enum: ['kept', 'revised', 'flagged'] },
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

const HARMONISE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['patchFile', 'unitCount', 'adjustments'],
  properties: {
    patchFile: { type: 'string' },
    unitCount: { type: 'integer' },
    adjustments: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['key', 'english', 'before', 'after', 'reason'],
        properties: {
          key: { type: 'string' },
          english: { type: 'string' },
          before: { type: 'string' },
          after: { type: 'string' },
          reason: { type: 'string' },
        },
      },
    },
    conventionsLocked: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
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
// Phase 1 — Prepare
// ---------------------------------------------------------------------------

phase('Prepare')

const prep = await agent(
  `Prepare a full-catalog translation job for the new language "${LANG}".

1. \`mkdir -p ${SCRATCH}\`

2. Check whether ${LANG} is genuinely new:

       python3 ${HELPER} verify ${CATALOG}

   If ${LANG} already appears in "languages", say so via \`alreadyPresent\` and
   report its outstanding count — the developer probably wants the loc-sync
   workflow instead. Continue preparing anyway; the reviewer will only fill
   what is actually missing.

3. Inventory the work. Because ${LANG} has no localizations yet, every unit in
   the catalog comes back as missing:

       python3 ${HELPER} inventory ${CATALOG} --languages ${LANG}

4. Split \`work.${LANG}\` into chunk files of at most ${CHUNK_SIZE} items each,
   written as \`${SCRATCH}/chunk-01.json\`, \`chunk-02.json\`, … Each file is the
   raw JSON array of work items, unmodified. Keep the catalog's original order
   so related strings (onboarding, map types, sort options) stay together in a
   chunk — do not sort or shuffle. Use a script, not hand-editing.

5. Build a convention sample from the two best-covered existing languages, so
   later stages can see how this project already resolves recurring decisions
   (brand names, register, symbolic keys). For each, run:

       python3 ${HELPER} inventory ${CATALOG} --languages <lang> --reference <lang>

   and write the \`reference\` arrays into \`${SCRATCH}/context.json\` as
   \`{"<lang>": [...], "<lang>": [...]}\`. Pick the two with the fewest
   outstanding units; prefer languages typologically closest to ${LANG} when
   coverage ties.

Do not modify ${CATALOG}. Report the chunk file paths in order.`,
  { schema: PREPARE_SCHEMA, effort: 'low', label: 'prepare' },
)

if (!prep || !prep.chunkFiles.length) {
  log('Preparation produced no chunks — aborting.')
  return { status: 'failed', language: LANG }
}
if (prep.alreadyPresent) {
  log(`NOTE: ${LANG} already exists in the catalog (${prep.existingCoverage || 'partial coverage'}). Only missing/stale units will be filled.`)
}
log(`${prep.unitCount} unit(s) to translate into ${LANG}, split into ${prep.chunkFiles.length} chunk(s).`)

// ---------------------------------------------------------------------------
// Phase 2 — Research. Runs once; every translator works from its output, which
// is what keeps a fresh language internally consistent.
// ---------------------------------------------------------------------------

phase('Research')

const guide = await agent(
  `Build the localization style guide for "${LANG}" for an iOS app, before any
translation happens. You have web access and you are expected to use it.

First: call ToolSearch with \`select:WebSearch,WebFetch\` — those tools are not
loaded by default and you cannot call them until you do.

Read the strings you will be governing:
  * the chunk files in ${SCRATCH}/ (English text + developer comments)
  * ${SCRATCH}/context.json — how two existing languages in this project
    already resolved the recurring decisions

The app: a map-based time-travel app. It shows historical photos and paintings
pinned to their locations, lets you compare a place then vs now through the
camera or Google Street View, and clusters images on the map by date with a
colour gradient. Concepts that recur: photos vs paintings, map types
(scheme/satellite/hybrid), clusters and groups of pins, favorites, onboarding.

Research and decide, for ${LANG} specifically:

1. **Address form and formality.** Does this locale's Apple/iOS convention use
   formal or informal address? Does UI copy address the user at all? Get this
   from how Apple actually localizes iOS into ${LANG}, not from general
   language-teaching advice.
2. **Button and action mood.** Infinitive, imperative, or noun phrase? Check
   what iOS system buttons look like in ${LANG}.
3. **Brand names.** For each of: Apple Maps, Google Maps, Google Street View —
   is the name localized, partly localized, or left in English in ${LANG}? Check
   Apple's and Google's own ${LANG} product pages, not a dictionary. Note that
   this project sometimes localizes only the generic half ("Apple Карты"), so
   report what the vendors themselves do and let the reviewer reconcile.
4. **Typography.** Quotation marks, dash conventions, decimal separator,
   capitalization rules for titles and buttons (many locales use sentence case
   where English uses title case — this is a very common mistranslation).
5. **Domain glossary.** For the recurring concepts above, the term a native
   ${LANG} speaker expects in a photo/maps app. Check Apple Photos and Apple
   Maps terminology in ${LANG} where it applies.
6. **Grammatical hazards.** Anything a translator will trip on: cases, gender
   agreement on adjectives in short labels, verb aspect, agglutination and
   suffix harmony, plural categories beyond one/other.

Write the guide to \`${SCRATCH}/style-guide.md\`. Make it prescriptive and
concrete — decisions with examples, not a survey of options. Every non-obvious
decision cites the source you took it from.

Put anything you genuinely could not resolve into \`openQuestions\` rather than
picking arbitrarily and hiding it — an unresolved convention that gets silently
guessed here propagates into all ${prep.unitCount} strings.`,
  { model: 'opus', schema: GUIDE_SCHEMA, effort: 'high', label: `research:${LANG}` },
)

const guideSummary = guide
  ? guide.summary
  : '(style guide unavailable — fall back to the conventions visible in context.json)'

if (guide && guide.openQuestions && guide.openQuestions.length) {
  log(`Style guide left ${guide.openQuestions.length} convention question(s) open — they will surface in the report.`)
}

const glossaryText = guide && guide.glossary && guide.glossary.length
  ? guide.glossary.map((g) => `  - ${g.term} → ${g.translation}${g.rationale ? ` (${g.rationale})` : ''}`).join('\n')
  : '  (none)'

// ---------------------------------------------------------------------------
// Phases 3+4 — Translate then Review, pipelined per chunk.
// ---------------------------------------------------------------------------

const chunks = prep.chunkFiles.map((file, index) => ({ file, index }))

const reviews = await pipeline(
  chunks,

  // -- Translate -----------------------------------------------------------
  (chunk) => agent(
    `Translate a chunk of iOS UI strings from ${prep.sourceLanguage || 'en'} into ${LANG}.

Your task list: \`${chunk.file}\` — a JSON array of work items, each with the
English text, the developer "comment" (where the string appears), the catalog
key, and any placeholders.

Binding style guide — read it in full before translating:
\`${SCRATCH}/style-guide.md\`

Its summary: ${guideSummary}

Locked glossary (use these exact terms):
${glossaryText}

Cross-project conventions: \`${SCRATCH}/context.json\` shows how two other
languages in this project handled the same strings. Use it to see which
decisions are project-wide (brand names, symbolic keys, register) — but the
${LANG} style guide wins where they conflict.

${HOUSE_RULES}

Write your drafts to \`${SCRATCH}/chunk-${String(chunk.index + 1).padStart(2, '0')}.draft.json\`:

    {"language": "${LANG}", "updates": [
      {"key": "<exact catalog key>", "value": "<translation>",
       "variationPath": "<only if the work item had one>",
       "confidence": 0.0-1.0, "note": "<why, if non-obvious>"}
    ]}

The "key" must be the catalog key verbatim — for symbolic keys like
\`comparison_title\` that is the key, NOT the English text. Every item in your
task list gets exactly one entry. Write the file with a script so quoting and
unicode survive.

Be honest with "confidence": it routes the reviewer's research budget. Below
${CONFIDENCE_FLOOR} means "I guessed at the context or the idiom". Do NOT touch
${CATALOG}.`,
    { model: 'sonnet', schema: DRAFT_SCHEMA, phase: 'Translate', label: `draft:${chunk.index + 1}` },
  ),

  // -- Review --------------------------------------------------------------
  (draft, chunk) => {
    if (!draft) return null
    const stem = `chunk-${String(chunk.index + 1).padStart(2, '0')}`
    return agent(
      `Review a chunk of proposed ${LANG} translations for an iOS app.
You have web access and you are expected to use it.

First: call ToolSearch with \`select:WebSearch,WebFetch\` — those tools are not
loaded by default and you cannot call them until you do.

Inputs:
  * \`${SCRATCH}/${stem}.draft.json\` — the proposed translations
  * \`${chunk.file}\` — the task list they answer (English, comment, placeholders)
  * \`${SCRATCH}/style-guide.md\` — the binding ${LANG} conventions
  * \`${SCRATCH}/context.json\` — how other languages in this project decided
  * Drafter's own low-confidence keys: ${(draft.lowConfidence || []).join(', ') || '(none)'}

For every proposed translation, judge how confident you are that it is what a
native ${LANG} speaker would expect in this exact UI position.

**If your confidence is below ${CONFIDENCE_FLOOR}, go and research it.** Do not
guess and do not wave it through. Worth checking on the web:
  * how Apple's own ${LANG} localization renders the same UI concept
    (sort orders, "Get started", map types, permission prompts);
  * what a feature actually is when the English is ambiguous — note that this
    app's "Satellite" is really a hybrid map type, and its comment says so;
  * whether a brand name is localized in ${LANG};
  * grammar you are unsure of — case, gender agreement, aspect, mood, suffix
    harmony.

${HOUSE_RULES}

Check specifically for:
  * violations of the style guide's address form, button mood, and capitalization;
  * glossary terms rendered inconsistently with the guide;
  * literal calques where the locale has a platform idiom;
  * translations materially longer than the English on buttons and indicators;
  * placeholder set changes, and lost leading/trailing whitespace.

Revise where needed, then write FINAL values to \`${SCRATCH}/${stem}.patch.json\`:

    {"language": "${LANG}", "updates": [{"key": "...", "value": "<final>", "variationPath": "<if any>"}]}

Every unit from the task list appears exactly once. Write it with a script. Do
NOT edit ${CATALOG}.

Then report a decision per unit: \`action\` is "kept" (draft accepted), "revised"
(you changed it), or "flagged" (applied, but a human should look). Set
\`researched: true\` and list \`sources\` (URLs) wherever you went to the web.
Put anything unresolved into \`openQuestion\`, phrased as a real question — that
is what reaches the developer.`,
      { model: 'opus', schema: REVIEW_SCHEMA, effort: 'high', phase: 'Review', label: `review:${chunk.index + 1}` },
    )
  },
)

const reviewed = reviews.filter(Boolean)
if (reviewed.length === 0) {
  log('No chunk produced a patch — aborting before apply.')
  return { status: 'failed', language: LANG }
}
if (reviewed.length < chunks.length) {
  log(`WARNING: ${chunks.length - reviewed.length} chunk(s) failed. Harmonising and applying only what survived — the language will be incomplete.`)
}

// ---------------------------------------------------------------------------
// Phase 5 — Harmonise. A barrier is correct here: consistency is a property of
// the whole language, and this agent needs every chunk's output at once.
// ---------------------------------------------------------------------------

phase('Harmonise')

const patchFiles = reviewed.map((r) => r.patchFile).join(' ')

const harmonised = await agent(
  `Do the final consistency pass over the complete ${LANG} translation.

Each chunk was translated and reviewed in isolation, so each is locally
defensible while the language as a whole can still be incoherent. That is the
one thing only you can see, and it is the only thing you are looking for.

Read every chunk patch: ${patchFiles}
Against: \`${SCRATCH}/style-guide.md\` and the task lists in ${SCRATCH}/chunk-*.json

Look for:
  * **Register drift** — an imperative button among infinitive buttons, formal
    address in one chunk and informal in another.
  * **Terminology drift** — the same English concept rendered two ways across
    chunks ("image", "photo", "picture"; "map"/"scheme"; cluster vs group).
    Pick one and apply it everywhere, unless the English genuinely distinguishes
    them — this app deliberately separates "cluster" from "group", and
    "photos" from "paintings".
  * **Brand-name drift** — Google Street View / Google Maps / Apple Maps handled
    one way in one chunk and another way elsewhere.
  * **Capitalization drift** across section headers and buttons.
  * **Paired strings that no longer read as a pair** — sort options
    (ascending/descending), map type switchers, onboarding title/description
    pairs. Check each family reads as a set, not as independent strings.

Where two renderings are both fine, pick the one that matches the style guide
and the majority of the language, and change the minority. You may consult the
web if a consistency call needs a fact you do not have — call ToolSearch with
\`select:WebSearch,WebFetch\` first if so.

Write the merged, harmonised result to \`${SCRATCH}/${LANG}.patch.json\`:

    {"language": "${LANG}", "updates": [{"key": "...", "value": "...", "variationPath": "<if any>"}]}

It must contain every unit from every chunk patch, exactly once, with your final
values. Use a script to merge — do not retype the strings, you will corrupt
them. Verify the count matches the sum of the chunk patches before finishing.

Report every value you changed relative to the chunk patches, with the reason.
Report the conventions you locked in \`conventionsLocked\` — those are what a
future translator must follow. Anything you had to choose arbitrarily goes in
\`openQuestions\`.`,
  { model: 'opus', schema: HARMONISE_SCHEMA, effort: 'high', label: `harmonise:${LANG}` },
)

if (!harmonised) {
  log('Harmonise pass failed — not applying. The per-chunk patches are still in ' + SCRATCH)
  return { status: 'failed-at-harmonise', language: LANG, scratch: SCRATCH }
}
log(`Harmonised ${harmonised.unitCount} unit(s); ${harmonised.adjustments.length} changed for cross-chunk consistency.`)

// ---------------------------------------------------------------------------
// Phase 6 — Apply
// ---------------------------------------------------------------------------

phase('Apply')

const applied = await agent(
  `Apply the harmonised ${LANG} translation to the string catalog.

1. Dry run and read the output:

       python3 ${HELPER} apply ${CATALOG} ${harmonised.patchFile} --dry-run

   A non-empty "skipped" list means malformed updates (unknown key, empty
   value, placeholder mismatch). Report those verbatim — do NOT invent
   replacement values.

2. If nothing is skipped, apply for real (drop --dry-run).

3. Verify:

       python3 ${HELPER} verify ${CATALOG}
       git -C . diff --stat -- ${CATALOG}

   "roundTripsExactly" must be true — it means the file still matches Xcode's
   own serialization. ${LANG} must now appear in "languages" with 0 outstanding.
   The diff should be an insertion of one localization block per key; if it
   shows the whole file rewritten, something reformatted it — say so loudly.

Report the counts, any skipped entries, and the outstanding counts from verify.
Do not fix problems you find; report them.`,
  { schema: APPLY_SCHEMA, effort: 'low', label: 'apply' },
)

// ---------------------------------------------------------------------------
// Phase 7 — Report
// ---------------------------------------------------------------------------

phase('Report')

const report = await agent(
  `Write the run report for adding ${LANG} to the string catalog.

**Return the report as your reply text. Do NOT write it to a file.** No Write
tool, no \`>\` redirect, no \`mkdir\`. The report is read once in the terminal and
then thrown away — it must never end up in the working tree, because it would
land in a commit. Your entire return value is the markdown itself, starting at
the \`#\` heading.

Catalog: ${CATALOG}
Style guide: ${SCRATCH}/style-guide.md
Apply result: ${JSON.stringify(applied)}
Harmonisation: ${JSON.stringify(harmonised)}
Style-guide research: ${JSON.stringify(guide)}

Per-chunk review decisions:
${JSON.stringify(reviewed)}

Structure the report as:

# Added ${LANG} — <date>

## Summary
How many strings, how many the reviewer revised vs accepted, how many the
harmonisation pass changed, and whether apply skipped anything.

## Conventions locked in
The decisions that now define ${LANG} for this project — address form, button
mood, capitalization, brand-name handling, glossary terms — each with the
source it came from. Make it usable on its own — this is the part worth keeping,
and the developer may paste it somewhere permanent.

## Notable translation decisions
Strings where the obvious rendering was wrong and why. Identify every string by
its catalog key AND its English source text — the reader does not read ${LANG}
and needs both to find it. Skip the strings that were routine; spend the space
on the ones a reviewer would question.

## Researched
Only strings where the reviewer actually went to the web. What was uncertain,
what it found, and the source URLs.

## Open questions
Every unresolved item — from the style-guide research, the per-string reviews,
and the harmonisation pass — as a checklist the developer can act on. Each
item: what is uncertain, which strings it affects (key + English), and what a
decision would need. This is the most important section. Convention-level
questions go first, since they affect every string. If there are genuinely
none, say so explicitly.

Write in the same language the developer works in — the repo's existing docs and
commit messages are the guide. Be concrete and skip filler.`,
  { effort: 'medium', label: 'report' },
)

return {
  status: 'done',
  language: LANG,
  catalog: CATALOG,
  translated: harmonised.unitCount,
  revisedByReviewer: reviewed.reduce((n, r) => n + r.decisions.filter((d) => d.action === 'revised').length, 0),
  flagged: reviewed.reduce((n, r) => n + r.decisions.filter((d) => d.action === 'flagged').length, 0),
  harmonisationChanges: harmonised.adjustments.length,
  apply: applied,
  report,
  scratch: SCRATCH,
}
