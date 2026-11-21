# dsfl-ai skills

Skills that guide an LLM in answering questions with the dsfl-ai MCP servers (BAG, BGT, Wijken en buurten,
Postcodegebieden, DSO, subsurface-models, groundwater-monitoring, virtual-groundwater-heads).

## Layout

| Path | What it is |
|---|---|
| `SKILL.md` | Combined skill, Dutch. Self-contained: no links to other files. |
| `SKILL-EN.md` | English version of `SKILL.md`, same structure and content. Not picked up by a skill loader under this name; rename it to use it as a skill. |
| `dsfl-ai-gebouwde-omgeving/` | Original skill for BAG, BGT, CBS and DSO, with `references/` per server. Kept as source for later re-analysis. |
| `dsfl-ai-bodem-ondergrond-grondwater/` | Original skill for the subsurface and groundwater servers, with `references/` per server. Kept as source for later re-analysis. |

## What the combined skill contains

1. **Server table**: all eight servers with their main tools.
2. **General route in nine steps**: pin the definitions, area to code, select and rank, aggregate, subsurface, groundwater (measured or modelled), derive indicators, combine, present.
3. **What changes an answer, per domain**: BAG, BGT, CBS, DSO, subsurface and groundwater.
4. **Errors, limits and answer format.**

The aim is a skill that costs few tokens to load but still gives an LLM as much generic direction as possible for a solution path, using the tools.

## What was left out

Long value lists and most worked examples: the full BAG status list, the BGT value lists (`bgt-waarden/`), the RD coordinate
formula and the per-collection property descriptions. They remain in the `references/` of the original skills.

## Duplicate skills

The two folder skills each still have their own `SKILL.md`. A tool that loads every `SKILL.md` sees three skills with overlap. Use
either the combined skill or the two folder skills, not both.

## Why an English version

Models are generally strongest in English, and Dutch text typically takes more tokens than the same content in English (roughly
1.3 to 1.6 times, a rule of thumb that has not been measured here for these files). An English skill therefore loads cheaper and is
followed at least as reliably. Dutch data values (statuses, field names, codes such as `Verblijfsobject in gebruik`, `bgtFunctie`)
stay Dutch in the English file because they must match the data exactly. The English description keeps a few Dutch trigger words so
the skill still activates on Dutch questions.

Whether the English version actually answers better has not been tested; compare both on the same set of questions before choosing one.
