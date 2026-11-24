---
name: dsfl-ai
description: >-
  Use before the first call of the MCP servers for Dutch geospatial data: BAG, BGT, Wijken en buurten
  (CBS areas), Postcodegebieden, DSO (Omgevingswet), subsurface-models, groundwater-monitoring and
  virtual-groundwater-heads. For questions on addresses, buildings, homes, roads, green space, water,
  trees, neighbourhoods and CBS figures per postcode; what is allowed or needs a permit at an address;
  and soil, subsurface (REGIS II, GeoTOP), clay or peat, monitoring wells and groundwater levels for an
  area or a building, also combined. Gives the order of analysis, the right tool per step and the
  pitfalls that make counts, areas, depths and provenance (measured vs derived) come out right.
  Users often ask in Dutch (adressen, woningen, buurten, grondwaterstand, vergunning).
---

# Solving spatial questions with the dsfl-ai MCP servers

Each server's own instructions describe its model, parameters and API pitfalls; read them. This skill
gives the route from question to answer and the mistakes that produced wrong answers in trials.
Keep Dutch data values (statuses, field names, codes) verbatim; answer in the user's language.

## 1. Servers and what they answer

| Server | For | Main tools |
|---|---|---|
| **BAG** | addresses, buildings (pand), units (verblijfsobject: homes, shops), moorings/pitches, history | `process_aggregate-features`, `query_adres-op-postcode`, `query_adres-op-straat`, `process_pand-bij-adres`, `query_panden-in-gebied`, `query_verblijfsobjecten-in-gebied`, `process_nearest-features`, `collection_<type>` |
| **BGT** | topography: roads, green, water, buildings, street furniture, history | `process_aggregate-features` (with `clip`), `query_wegen-in-gebied`, `query_inrichtingselementen-in-gebied`, `query_wat-ligt-hier`, `query_wijzigingen-in-gebied`, `collection_<type>` |
| **Wijken en buurten** | names, codes, boundaries of municipality/district/neighbourhood (CBS 2026), **no figures** | `collection_gemeente`, `collection_wijk`, `collection_buurt` |
| **Postcodegebieden** | CBS figures per PC6 (1 Jan 2024): inhabitants, households, dwellings | `collection_postcode6`, `process_aggregate-features` |
| **DSO** | Omgevingswet rules at an address, live | workflows `regels-over-wonen`, `dakkapel-hier`, `wat-verandert-hier`, `verzoek-voorbereiden`, `documenten-op-peildatum`, `regels-op-peildatum`, `ow-tekst-ophalen`, `regeling-detail`, `versiehistorie` |
| **subsurface-models** | REGIS II layers, GeoTOP voxels | `subsurface-models.` `trace`, `section`, `layers`, `area-summary`, `band-confinement`, `trace-plot`, `section-plot` |
| **groundwater-monitoring** | BRO GMW/GLD/GMN: wells, tubes, level series | `groundwater-monitoring.` `tubes.search`, `wells.get`, `series.daily`, `series.get`, `series.assess`, `series.plot`, `networks.get` |
| **virtual-groundwater-heads** | derived levels where no usable tube exists | `virtual-groundwater-heads.` `tubes.select`, `tubes.subsurface`, `tubes.geotop-confinement`, `meteo.stresses`, `series.tfn`, `estimate.series`, `estimate.plot` |

- The same tool name exists on several servers (`process_aggregate-features`, `collection_pand`): pick the server holding the data you mean.
- Each server holds an extract (area, reference date; see its instructions). If the question lies outside it, say the data is missing there, not that nothing exists or that an address does not exist.
- Unknown term or code on the subsurface/groundwater servers: `model.search` first, then `model.describe` or `concepts.lookup`; never guess lithoclass codes. `methods.describe` says how a result was made.

## 2. General route (cheap, register-based steps first)

1. **Pin the definitions.** Write down every term and threshold in the question (status, period, probability cut-off, depth, distance, years, assumed level). They are parameters you pass on, never server defaults. Unclear or inconsistent (wijk or buurt? 5 % or 10 %?): confirm with the user.
2. **Area → code.** All servers filter on CBS codes: municipality `0307`, wijk `WK030701`, buurt `BU03070100`. Look up with `collection_wijk`/`collection_buurt` using `gemeente` and `naam`. Names are case-sensitive and unique only within a municipality; no hit → `naam` with `*` (`*Hof*`) or `filter: "CASEI(naam) = CASEI('hof')"`. A city district often consists of several wijken: name all hits.
3. **Select and rank units** in BAG/BGT/CBS (state the count before and after) so the expensive subsurface and groundwater steps run on as few units as possible. Geometry is GeoJSON WGS84 `[longitude, latitude]`.
4. **Count, sum, distribute** with `process_aggregate-features` of the right server; never fetch objects to count them. One call reads at most 100,000 objects (otherwise split per collection or wijk). Keep results small: `properties`/`weglaten` with only what is needed, no geometry unless for a map, distance or `clip`. In search tools **a custom `weglaten` list replaces the default list**. Result too large: pass on the link from the tool.
5. **Subsurface** (if asked): share of an area → one `area-summary` per unit (never `trace` per cell); point/object → one `trace` with depth range; lateral continuity → `section`/`band-confinement`; an interval at a place → `layers`.
6. **Groundwater** (if levels asked): `tubes.search` within the stated distance → judge each tube for target and filter depth (`wells.get`, `tubes.select`, `tubes.subsurface`) → check coverage (`series.assess`). A tube qualifies: **measured** (`series.daily`, max 90 days per call, so page; `series.get` for raw observations). Otherwise **modelled** (`series.tfn`, `estimate.series`, labelled proof of concept).
7. **Derive indicators** (time below a level, longest run, number of runs, maximum depth): no server tool does this; compute from the series yourself, treating a gap longer than the stated length as a break.
8. **Combine/score** only with a formula from the question or agreed with the user; otherwise show components side by side.
9. **Present** (see §6). Plots: `trace-plot`, `section-plot`, `series.plot`, `estimate.plot`.

Outlines: *rank areas on a subsurface share* = 1 → 2 → 3 → 5 (`area-summary` per unit) → 8 → 9. *Screen objects against a groundwater level* = 1 → 2 → 3 → 5 (`trace`) → 6 → 7 → 9. *Is this allowed at this address* = `query_adres-op-postcode` (does the address exist?) → DSO workflow.

## 3. Built environment: what changes an answer

**BAG**
- A home is a verblijfsobject with gebruiksdoel woonfunctie. Collections and `process_aggregate-features` return **all statuses** (also under construction, withdrawn, wrongly registered); search tools only existing objects in use. Choose statuses deliberately and state them. Default for "woningen": `status IN ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing verblijfsobject')`; mention homes under construction separately when relevant. "In use" means the number comes from that filter.
- A sub-question ("of which built since 2015") uses the same filter plus `bouwjaarPand`. Construction year 9999 = unknown (exclude); old years are estimates. `grondoppervlakteMin` 50 excludes sheds and garages. Floor area 999999 is not a value. Gebruiksdoel is the permitted function, not a kind of facility.
- Buildings, units and area give different pictures (a block of flats is one pand with many homes). Houseboats (`ligplaats`) and caravans (`standplaats`) are not verblijfsobjecten: count separately if the question may mean them. The BAG has no residents, company names, owners, prices or energy labels.
- Addresses: `query_adres-op-straat` needs the full street name and the **woonplaats**, not the municipality. No result: look up the spelling via `collection_openbareruimte` with `*`. '(ingetrokken)' in a title: say so; current addresses next to it are no replacement. Do not count withdrawn secondary addresses as extra homes.
- Area filters: `gemeentecode`, `wijkcode`, `buurtcode`; more codes via `filter: "wijkcode IN (...)"`; per area `groupBy: ["wijkcode","wijknaam"]`.

**Changes = compare two states.** "Added since 2015" = now minus the state on 1 Jan 2015: two calls, same area and definition, one with `"datetime": "2015-01-01"` in `source.parameters`. Counting on `bouwjaarPand` ≥ 2015 misses conversions and splits and ignores what disappeared (a factor of four is possible). Give the net difference, new construction at most as a part of it. `query_*` has no `datetime`; collections and `process_aggregate-features` do. The state just before a change: `collection_<type>` with `datetime` = the day before `beginGeldigheid`.

**A registered event is not always what happened.**
- 'Pand gesloopt' also covers a merge with a neighbouring pand and never built (large buildings ≥ 50 m²: sometimes only 1 in 8 really demolished). Report "registered as demolished", split by size and offer a check: status the day before `beginGeldigheid` ('Bouwvergunning verleend' = never built); the units of that day now in use in another pand = merge, 'ingetrokken' = real demolition; `query_pand-met-inhoud` without units for such a pand is the sign.
- `beginGeldigheid` is the registration date, sometimes years after the event. A 'Bouwvergunning verleend' can be old: combine with `sinds`.
- If an answer hinges on one value or a value looks implausible: aggregate on collection `kenmerkinonderzoek` (`object IN ('<id>') AND inOnderzoek = true`, `groupBy: ["kenmerk"]`).

**BGT**
- Give values exactly as in the value lists (spaces, lowercase: `bgtFunctie=rijbaan lokale weg`); several values via `filter=bgtFunctie IN ('fietspad','voetpad')`. `'recreatie: speeltuin'` refines `'recreatie'`; all kinds: `LIKE 'recreatie%'`. Unsure which value fits a concept: read the value list of the collection.
- **Area in a region: `clip`.** An object belongs to the area containing a point of its geometry; along borders this can differ by tens of percent. Method: (1) boundary with full geometry via `collection_buurt`/`collection_wijk` (no `zoom-level`); (2) `process_aggregate-features` with `clip: {"geometry": <boundary>}` (or `{"point":[lon,lat],"distance":250}`) and `aggregates: [{"function":"sum","property":"$area"}]` (`$length` for length); (3) in `source.parameters` **`gemeentecode`, not `buurtcode`**. Report the clipped figure.
- Distribution of an area (share green/paved/water): surfaces at ground level (`relatieveHoogteligging = 0`) cover the area without overlap; total = sum of those surfaces with the same `clip`. Collections: wegdeel, ondersteunendwegdeel, begroeidterreindeel, onbegroeidterreindeel, waterdeel, ondersteunendwaterdeel, pand, overigbouwwerk, kunstwerkdeel, spoor. Green = `begroeidterreindeel`; `onbegroeidterreindeel` with `erf` is gardens and driveways: mention that share too. Bridges, tunnels and functional areas do not count.
- **Street furniture and IMGeo-plus** (trees, benches, lamp posts, wells) are optional and often come from the province (P…), water board (W…) or national government (L…): group on `["plusType","bronhouder"]` first and say "registered in the BGT" and by whom; little registered ≠ little present. `plusFysiekVoorkomen` 'waardeOnbekend' can be a fifth of road area; `bgtFysiekVoorkomen` is complete.
- History starts per data holder at first delivery (mostly end of 2016); an increase can be finer data capture. Number of changes: `process_aggregate-features` with `source: {"query":"wijzigingen-in-gebied","parameters":{gebied,sinds,tot}}`, `aggregates:["count"]`, `groupBy ["$collection"]`; do not count via `objectBeginTijd` (misses terminated objects). Many versions of one data holder with the same `tijdstipRegistratie` = bulk operation, not a change on the ground. Start with a neighbourhood or short period (100,000 limit).
- Links: address → point via BAG (`query_adres-op-postcode`) → `query_wat-ligt-hier` (`afstand` ≤ 100 m); `identificatieBAGPND` points to the BAG pand.

**CBS**
- Wijken en buurten has no residents or other figures; figures per neighbourhood (WOZ, income) are in neither server. BAG numbers are object counts, not CBS statistics.
- Postcodegebieden: counts rounded to fives, percentages to tens. **A missing value is 0–4 or confidential, not zero.** Sums are lower bounds (say "at least"; sums of subgroups even lower); `count` with a property next to `count` without shows how many postcodes contribute. Do not add percentages or averages; owner/renter percentages are missing too often for a share per wijk. Sorting: filter on `... IS NOT NULL` first. Count per wijk/buurt with `process_aggregate-features` `groupBy: ["wijkcode"]`; names from Wijken en buurten. RD coordinates for DSO: argument `crs=http://www.opengis.net/def/crs/EPSG/0/28992` on the BAG tool.

**DSO (Omgevingswet)**
- Address: postcode without space (`3811LM`) and house number as **text**, without letter or suffix; the workflow finds exactly one BAG address. 422 on step 'adres': check with `query_adres-op-postcode`; if it exists, say the workflow cannot handle this address (not that it does not exist) and offer an address without letter. Dates: `datum` is `dd-MM-jjjj`, `peildatum` is `jjjj-MM-dd`. `uriIdentificatie` with underscores as delivered.
- Errors: 502/503/504 or unreadable DSO document → DSO unreachable; do not retry with other input and never conclude "no rules apply". 429 → run workflows one after another, not in parallel. A 404 'tijdreis' on `regels-op-peildatum` is an answer (the regulation did not apply then).
- Output consists of **parallel lists** (same position belongs together); `null` = no value. Rule texts are STOP XML (`<Al>`, `<Li>`): give plain sentences. Besides the omgevingsplan, old bestemmingsplannen (Wro) apply: name both. An empty `wroBestemmingen` in `regels-over-wonen` does not mean housing is not allowed.
- `dakkapel-hier`: first round without `antwoorden`, short `activiteit` (`dakkapel`); ask the questions to the user, **never answer them yourself**; next round with all answers `{id, antwoord}` (id as number, yes/no as `"true"`/`"false"`); done when every `conclusie[i]` has a value ('Vergunningplicht', 'Toestemmingsvrij', 'Neem contact op met', 'Niet van toepassing' = no judgement).
- `verzoek-voorbereiden`: `toestemming` required, `zoekterm` specific; check that the chosen activity fits the question, otherwise do not use the output. It never submits anything.
- `wat-verandert-hier`: a draft is not yet law; name what the municipality changes first, not programmes of province or national government.
- Reference date: `documenten-op-peildatum` (rdX, rdY, peildatum; drop documents whose year in the `uriIdentificatie` is after the reference date; before 2024 the bestemmingsplan applied) → `regels-op-peildatum` → `ow-tekst-ophalen` with a `wId` exactly as delivered and the **same** `peildatum`.

## 4. Subsurface and groundwater: what changes an answer

- **Evidence, not a verdict.** Report lithoclass or probability as the model gives it; "weak soil" or "confining" is the caller's definition, which you pass on (e.g. confining codes for `band-confinement`).
- **Depth reference.** `trace` depths (`minDepth`/`maxDepth`) are m below the model's surface; `section`/`layers` use m NAP. If the question measures from AHN ground level or NAP: convert explicitly and report mismatches.
- **Never mix measured and modelled silently**; label every series and figure with source, method and version. Virtual levels are derived and a proof of concept.
- **Proximity is not relevance**: a tube within the distance is a candidate; filter depth and unit (phreatic or not) must still fit; `tubes.select` is conservative and does not decide this.
- **The question's coverage rule ≠ the server's quality ruleset** (`series.assess` uses 8 years); say which decided. A missing position is reported missing, never inferred.
- **Paging.** `window` (`total`, `returned`, `truncated`) means incomplete: collect all windows before computing, or say you did not. `area-summary` has follow-up pages; `series.get` max 500 values.
- Only GeoTOP gives probabilities (`area-summary`); REGIS II gives units.

## 5. Errors and limits

- Connection error or timeout: retry once. A failed call is never "no result".
- A call takes 1–5 s, a municipality-wide BAG count up to a minute, DSO 1–4 s (up to 30 s on retries).
- What no server provides (open points): point-wise subsurface summary for many objects in one call, below-level indicators, a map, a reference line in plots, a combined score without a given formula. Compute it yourself, ask, or report it as open.

## 6. The answer

- Answer first, with the number and what it counts: object type, statuses, area (name, not just code), data vintage; per unit values with units, source (measured/derived), method and version, data coverage.
- Then only the caveats relevant to this question. If there is a check you did not do (demolition, data holder, sizes), say what it would yield and offer it.
- A DSO answer is information, not a decision: the official source is the Omgevingsloket or the municipality. Repeat a disclaimer from the question.
- If the user wants to verify or extend: give the calls with their arguments, or the link from the result.
