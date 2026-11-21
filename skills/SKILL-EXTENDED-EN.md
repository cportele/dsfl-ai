---
name: dsfl-ai-extended
description: >-
  Extended skill for the MCP servers for Dutch spatial data: BAG, BGT, Wijken en buurten (districts and
  neighbourhoods), Postcodegebieden (postcode areas), DSO (Omgevingswet, the Environment and Planning Act),
  subsurface-models (REGIS II, GeoTOP), groundwater-monitoring (BRO GMW, GLD, GMN) and
  virtual-groundwater-heads. Use before the first call for questions about addresses, buildings, homes,
  roads, greenery, water, trees, neighbourhoods, CBS figures per postcode, what is allowed or requires a
  permit at an address, and soil, subsurface, clay or peat, monitoring tubes and groundwater levels for an
  area or building, including combinations. Contains, per server, the model, the tool choice, the pitfalls
  and examples, in one fixed structure. Users often ask in Dutch (adressen, woningen, buurten,
  grondwaterstand, vergunning).
---

# Solving spatial questions with the dsfl-ai MCP servers (extended)

The instructions of each server describe the model, the parameters and the pitfalls per API; read those.
This skill complements them: how to answer a question using the servers together, and what led to wrong
answers in trials with real questions. All domains follow the same structure: **scope, model, which tool
for which question, pitfalls, examples**. Keep Dutch data values (statuses, field names, codes) verbatim;
answer in the language of the user.

## Contents

1. Servers and core agreements
2. General approach
3. Shared techniques: area → code, `clip`, changes, size, errors
4. BAG
5. BGT
6. CBS: Wijken en buurten, Postcodegebieden
7. DSO (Omgevingswet)
8. Subsurface: subsurface-models
9. Groundwater: groundwater-monitoring
10. Virtual groundwater levels: virtual-groundwater-heads
11. Soil + groundwater combined
12. The answer

---

## 1. Servers and core agreements

| Server | Contents |
|---|---|
| BAG | addresses, panden (buildings), verblijfsobjecten (address units: homes, shops, ...), berth and pitch locations (lig- en standplaatsen), with history |
| BGT | the map at the level of streets and buildings: roads, greenery, water, buildings, street furniture, with history |
| Wijken en buurten | names, codes and boundaries of municipalities, districts (wijken) and neighbourhoods (buurten) (CBS 2026), **no figures** |
| Postcodegebieden | CBS figures per postcode (PC6) on 1 January 2024: inhabitants, households, homes |
| DSO | workflows on the rules of the Omgevingswet at an address, live from the DSO |
| subsurface-models | REGIS II (layers) and GeoTOP (voxels): column, cross-section, share of lithoclass |
| groundwater-monitoring | BRO GMW (wells), GLD (level series), GMN (monitoring networks); daily levels, quality assessment |
| virtual-groundwater-heads | derived levels: tube selection, KNMI stresses, TFN models, virtual level series |

- **The same tool name on several servers**: `process_aggregate-features` (BAG, BGT, Postcodegebieden) and
  `collection_pand` (BAG and BGT). Choose the server whose data you mean; a BAG collection in the BGT tool
  gives an error.
- Each server contains an extract; the instructions say which one. If a question falls outside it, say that
  the data is missing there, not that there is nothing or that an address does not exist.
- Subsurface and groundwater servers: tool names start with the server name (`subsurface-models.trace`).
  Geometry is GeoJSON, WGS84, `[longitude, latitude]`; levels are in m NAP; results are evidence with
  method, version and input, never a judgement; a bounded result has a `window` (`total`, `returned`,
  `truncated`) and is paginated, not trusted as complete.

## 2. General approach

Do the cheap register steps first, so that the expensive subsurface and groundwater steps run on as few
units as possible.

| # | Step | What you do | Tools |
|---|---|---|---|
| 0 | **Fix the definitions** | Write down every threshold and term from the question (status, period, probability cut-off, depth, distance, years, gap length, assumed level). They are parameters you pass on, never server defaults. Look up unclear subsurface terms and lithoclass codes (clay, peat, sandy clay) in the model catalogue; do not guess codes. Unclear or inconsistent (wijk or buurt? 5 % or 10 %?): confirm with the user. | `subsurface-models.model.search`, `.model.describe`, `.concepts.lookup` |
| 1 | **Units and geometry** | Area → code (§3.1); fetch buurt or pand geometry and attributes (year of construction, paved area, ground level) from the registers; convert to GeoJSON WGS84. | BAG, BGT, Wijken en buurten; AHN outside these servers |
| 2 | **Filter and rank** | Apply criteria that do not need the subsurface and keep only the units needed (top N, before a year). State the number before and after. | BAG, BGT, CBS |
| 3 | **Characterise the subsurface** | Area question: one call per unit. Point or object question: one column per unit. Lateral continuity: a cross-section. Pass the depth range and the thresholds from step 0. | `subsurface-models.area-summary`, `.trace`, `.layers`, `.section`, `.band-confinement` |
| 4 | **Determine the groundwater source** (only if levels are asked for) | Find tubes within the stated distance, assess each on purpose and depth, check the data coverage against the stated rule. Measured if a tube qualifies, otherwise modelled; record which one and why. | `groundwater-monitoring.tubes.search`, `.wells.get`, `virtual-groundwater-heads.tubes.select`, `.tubes.subsurface`, `groundwater-monitoring.series.assess` |
| 5 | **Fetch the level series** | Measured: daily series per tube, paginated per period. Modelled: virtual level estimate, labelled as proof of concept. | `groundwater-monitoring.series.daily` (or `.series.get`), `virtual-groundwater-heads.series.tfn`, `.estimate.series` |
| 6 | **Derive indicators** | Compute what is asked from the series and the stated level (duration, longest run, number of runs, maximum depth, affected years); a gap longer than the stated length is an interruption. No server tool does this at present. | on the agent side |
| 7 | **Combine and score** | Only with a formula from the question or agreed with the user; otherwise show the components side by side. | none |
| 8 | **Present** | §12. Plots and map as requested. | `subsurface-models.trace-plot`, `.section-plot`, `groundwater-monitoring.series.plot`, `virtual-groundwater-heads.estimate.plot` |

Suggested sequences: *rank areas on a subsurface share* = 0 → 1 → 2 → 3 (`area-summary` per unit,
paginate) → 7 → 8. *Test objects against a groundwater level* = 0 → 1 → 2 → 3 (`trace` with depth range
per object) → 4 → 5 → 6 → 8. *Is this allowed at this address* = BAG address check → DSO workflow.

## 3. Shared techniques

### 3.1 Area → code

All servers filter on CBS codes: municipality `0307`, wijk `WK030701`, buurt `BU03070100`. Find the code
with `collection_wijk` or `collection_buurt` (Wijken en buurten) with `gemeente` and `naam`. Names are
case-sensitive and only unique within a municipality; no hit → `naam` with `*` (`*Hof*`) or
`filter: "CASEI(naam) = CASEI('hof')"`. A city district or new-build neighbourhood often consists of
several CBS wijken: search `*Naam*`, name all hits and add up what belongs to it (a business park with the
same name is usually not a residential neighbourhood; a prefix can also hit another village: Hoogland*
also finds Hooglanderveen).

### 3.2 Counting, summing, distributing

`process_aggregate-features` of the server with the data, never fetch the objects. One call reads at most
100,000 objects; otherwise split per collection or per wijk. A call takes 1 to 5 seconds, a
municipality-wide count in the BAG up to a minute. Group per area: `groupBy:
["wijkcode","wijknaam"]` (or buurtcode and buurtnaam together).

### 3.3 Keeping results small

- Collections: `properties` with only what is needed; the id is always included. No geometry unless for a
  map, a distance or `clip`.
- Searches: **a custom list in `weglaten` (omit) replaces the default list**; include the default values
  that must stay omitted. An empty list returns everything.
- `limit` is at most 5000; more pages with `offset` = `nextOffset`.
- If a result is too large, the tool reports an error with the link to the full result: pass on the link
  (for a map or a download), not the data.
- Many names at once (all buurten with their wijk): one call `collection_buurt` with `gemeente=<code>`,
  `properties: ["naam","wijk"]`, `limit` 500.

### 3.4 The number matches the definition you state

Choose statuses and filters deliberately and state them (see BAG §4.4). A sub-question uses the same
filter.

### 3.5 Changes: compare two states

"How many homes have been added since 2015?" is the state now minus the state on 1 January 2015: two calls
with the same area and the same definition, one with `"datetime": "2015-01-01"` in `source.parameters`.
Counting on `bouwjaarPand` ≥ 2015 is not an answer to that: it misses homes created in older buildings
(offices and shops converted, homes split) and ignores what disappeared. In old city districts that is the
largest part; the difference can be a factor of four. Give the net difference and state the number in new
construction at most as a part of it. The searches (`query_*`) have no `datetime`; the collections and
`process_aggregate-features` do. BGT: start of the history and bulk operations, see §5.7.

### 3.6 A registered event is not always what happened

- **'Pand gesloopt'** (building demolished) also marks a building that has been merged with a neighbouring
  building and a building that was never built. Of the larger buildings (`grondoppervlakte` ≥ 50 m²) in a
  city centre sometimes only one in eight has really been demolished; the small ones are mostly sheds. Give
  the number "registered as demolished", split by size, and check the large buildings or offer that check
  (method: §4.7).
- `beginGeldigheid` is the date of the registration, sometimes years after the event.
- **BGT**: many versions from one bronhouder (source holder) with the same `tijdstipRegistratie` are a
  bulk operation (correction, re-survey), not a change on the street.

### 3.7 Area within a region: `clip`

An object belongs to the area in which a point on its geometry lies. A pond or road along the boundary
then counts entirely in one buurt and not in the other; for water and large roads that can differ by tens
of percent. For every area or share of a buurt or wijk, and around a point:

1. the boundary: `collection_buurt` (or `collection_wijk`) with the code, with the full geometry, without
   `zoom-level`: a simplified boundary shifts the area;
2. `process_aggregate-features` with `clip: {"geometry": <that geometry>}` (or `{"point": [lon, lat],
   "distance": 250}`), `aggregates` with `{"function": "sum", "property": "$area"}` (`$length` for length);
3. in `source.parameters` **`gemeentecode`, not `buurtcode`**: the buurt filter leaves out exactly the
   objects that protrude from the neighbouring buurt into the buurt. `clip` takes only the objects that
   intersect the area; the limit of 100,000 then applies.

The result with `clip` is the area within the region; state that number, not the sum of whole objects. A
call with `clip` takes one to two seconds.

### 3.8 Registered is not present

- **BGT street furniture (inrichtingselementen) and IMGeo-plus**: see §5.5.
- **CBS per postcode**: a missing value is 0 to 4 or confidential, not zero (§6.3).
- **What the BAG does not have**: residents, company names, owners, prices, energy labels. Houseboats
  (`ligplaats`) and mobile homes (`standplaats`) are not verblijfsobjecten and are missing from every count
  of homes; count them separately if the question may mean them.

### 3.9 Errors

Retry a connection error or time-out once. An error 502/503/504 or a message that a document from
`service.omgevingswet.overheid.nl` cannot be read: the DSO is unreachable, the input is not wrong; do not
try other input and tell the user. A failed call is never "no result".

---

## 4. BAG: addresses and buildings

### 4.1 Scope

All addresses and buildings with their history. Which woonplaatsen (places) the server contains is given
by `collection_woonplaats`. If an address is not found, first check whether the woonplaats is in it, and
otherwise say that the data is missing there, not that the address does not exist.

### 4.2 Model

An **address** is a `nummeraanduiding` (postcode, huisnummer, huisletter, huisnummertoevoeging) that
`ligtAan` an `openbareruimte` (street), which `ligtIn` a `woonplaats`. Addresses belong to a
`verblijfsobject` (home, shop, office; a point), a `ligplaats` (houseboat) or a `standplaats` (mobile
home). A verblijfsobject `maaktDeelUitVan` one or more **panden** (buildings; a polygon).

| Reference | Reverse lookup |
|---|---|
| verblijfsobject.heeftAlsHoofdadres → nummeraanduiding | `collection_verblijfsobject` with `heeftAlsHoofdadres=<id>` |
| verblijfsobject.maaktDeelUitVan → pand | `collection_verblijfsobject` with `maaktDeelUitVan=<id>`, or `query_pand-met-inhoud` |
| nummeraanduiding.ligtAan → openbareruimte | `collection_nummeraanduiding` with `ligtAan=<id>` |

Identifiers have 16 digits; digits 5-6 give the type (01 verblijfsobject, 10 pand, 20 nummeraanduiding, 30
openbare ruimte); a woonplaats has 4 digits. In an MCP result a reference is `{"id": ..., "title": ...}`;
the title of an address is for example 'Stadhuisplein 1, 3811LM Amersfoort'.

Properties per object type in search results (unless omitted via `weglaten`; split a mixed result on
`objecttype`, not on the order):
- **pand**: oorspronkelijkBouwjaar (original year of construction; 9999 = unknown; old buildings often an
  estimated round year), status, beginGeldigheid (start of the current version), geometry (top view), on
  request grondoppervlakte (footprint, m²).
- **verblijfsobject**: gebruiksdoel (all; purpose of use), oppervlakte (usable floor area in m²; 999999 is
  not an actual area), status, beginGeldigheid, heeftAlsHoofdadres and heeftAlsNevenadres,
  maaktDeelUitVan (the panden), geometry (point), bouwjaarPand (oldest year of construction of those
  panden).
- **nummeraanduiding**: huisnummer, huisletter, huisnummertoevoeging, postcode (refers to the postcode
  area in `postcode6`), typeAdresseerbaarObject, status, ligtAan (title: street name), ligtIn (only if the
  woonplaats differs from that of the street).
- **openbareruimte**: naam, type (Weg, Water, ...), status, ligtIn (woonplaats). **woonplaats**: naam,
  status. **ligplaats and standplaats**: heeftAlsHoofdadres, status, geometry (polygon).

Object types per search: `panden-in-gebied` pand; `verblijfsobjecten-in-panden` pand, verblijfsobject;
`verblijfsobjecten-in-gebied` and `verblijfsobjecten-in-de-buurt` verblijfsobject; `adres-op-postcode`
nummeraanduiding, openbareruimte, woonplaats, verblijfsobject, ligplaats, standplaats, pand;
`adres-op-straat` idem in a different order; `pand-met-inhoud` pand, verblijfsobject, nummeraanduiding,
openbareruimte.

### 4.3 Which tool for which question

| Question | Tool |
|---|---|
| How many, how many m², average, per area, per construction period, per gebruiksdoel, on a date | `process_aggregate-features` |
| Address by postcode and house number | `query_adres-op-postcode` |
| Address by street, house number and woonplaats | `query_adres-op-straat` |
| The pand at an address, with year of construction and the BGT at that spot | `process_pand-bij-adres` |
| What is in a pand | `query_pand-met-inhoud` |
| Panden in an area by year of construction, status, demolition date, grondoppervlakte | `query_panden-in-gebied` |
| Verblijfsobjecten in an area by gebruiksdoel, status, oppervlakte; the largest first | `query_verblijfsobjecten-in-gebied` |
| Verblijfsobjecten in panden with a status or year of construction (homes under construction, schools in old buildings) | `query_verblijfsobjecten-in-panden` |
| What is closest to a point, with distance | `process_nearest-features` |
| Verblijfsobjecten with a gebruiksdoel within a distance | `query_verblijfsobjecten-in-de-buurt` |
| The state on a date, other properties | `collection_<type>` with `datetime`, properties or `filter` |

To count, never fetch all objects: `process_aggregate-features` gives the number directly, also with
characteristics of the pand of the verblijfsobject (`statusPand`, `bouwjaarPand`), so that questions about
homes in old or demolished panden are one call on `verblijfsobject`.

### 4.4 Pitfalls

- **Statuses.** The searches by default return only existing objects in use; the collections and
  `process_aggregate-features` return all statuses, including demolished, withdrawn and under
  construction: specify a status there (parameter one value; more with a filter). Pand: Bouwvergunning
  verleend, Bouw gestart, Pand in gebruik (niet ingemeten), Pand in gebruik, Verbouwing pand,
  Sloopvergunning verleend, Pand gesloopt, Pand buiten gebruik, Niet gerealiseerd pand, Pand ten onrechte
  opgevoerd. Verblijfsobject: Verblijfsobject gevormd (under construction), Verblijfsobject in gebruik
  (niet ingemeten), Verblijfsobject in gebruik, Verbouwing verblijfsobject, Verblijfsobject buiten
  gebruik, Verblijfsobject ingetrokken, Niet gerealiseerd verblijfsobject, Verblijfsobject ten onrechte
  opgevoerd.
- **Home (woning)** = verblijfsobject with gebruiksdoel woonfunctie. Default for "homes": `filter: "status
  IN ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing
  verblijfsobject')"`; mention homes under construction separately if they matter (in a new-build
  neighbourhood hundreds). If you say "in use", the number must come from that filter; a count without a
  status filter is never "in use". A sub-question ("of which built since 2015") uses the same filter, plus
  `bouwjaarPand`.
- **Year of construction** `oorspronkelijkBouwjaar`: 9999 is unknown (exclude with `bouwjaarTot` 9998 or a
  filter). Old panden often have an estimated round year (1600, 1700, 1800); numbers per year before about
  1900 are coarse. `bouwjaarPand` of a verblijfsobject is the oldest year of construction of its panden.
  Homes "built since" a year miss homes that were later created in an older pand; for "added" see §3.5.
- **Area (oppervlakte)** of a verblijfsobject is the usable floor area; 999999 is not an actual area.
  `grondoppervlakte` of a pand is calculated from the geometry; `grondoppervlakteMin` 50 excludes sheds and
  garages.
- **Gebruiksdoel** is the permitted use function (Bouwbesluit 2012), a list: woonfunctie,
  bijeenkomstfunctie, celfunctie, gezondheidszorgfunctie, industriefunctie, kantoorfunctie, logiesfunctie,
  onderwijsfunctie, sportfunctie, winkelfunctie, overige gebruiksfunctie. Not a type of facility:
  sportfunctie includes sports halls, gyms and canteens. A verblijfsobject with several gebruiksdoelen
  counts in a grouping in every group, in the total once.
- **What is counted**: panden, verblijfsobjecten or area give different pictures (an apartment block is
  one pand with many homes; most demolished panden are sheds). Houseboats and mobile homes have no
  gebruiksdoel: `process_aggregate-features` on `ligplaats` and `standplaats` (with status 'Plaats
  aangewezen') counts them separately.
- **Dates**: `beginGeldigheid` is the start of the current version; for a demolished pand the date of the
  registration of the demolition, sometimes later than the demolition. `sinds` and `tot` (since and until)
  filter on that. A 'Bouwvergunning verleend' can be years old if it was never built: combine with
  `sinds`.
- **Finding addresses**: `query_adres-op-straat` asks for the full official street name (Burgemeester, not
  Burg.; Stadhuisplein, not Stadhuispl.) and the **woonplaats**, not the municipality: a municipality often
  has several woonplaatsen. No result: look up the spelling with `collection_openbareruimte` and `naam`
  with `*` (`*Smittweg`) and read the woonplaats from `ligtIn`, or ask for the postcode.
- A title ending in '(ingetrokken)' (withdrawn) refers to a withdrawn address, street or woonplaats.
  Address searches return only issued addresses, unless `status` also contains 'Naamgeving ingetrokken'.
  If the requested address is withdrawn, say so; the current addresses next to it are not a replacement,
  name them as such. A verblijfsobject can keep withdrawn secondary addresses whose numbers are now the
  main address of other verblijfsobjecten; do not count those as extra homes or addresses.
- **Areas**: searches take one code in `gebied`; panden, verblijfsobjecten, ligplaatsen and standplaatsen
  filter on `gemeentecode`, `wijkcode` or `buurtcode`. More codes: `filter: "wijkcode IN
  ('WK030701','WK030702')"`. Area codes and names, `grondoppervlakte`, `aantalVerblijfsobjecten`,
  `bouwjaarPand`, `statusPand` and `objecttype` are not in the output by default: collections with
  `properties`, searches with `weglaten` without that property.

### 4.5 History

- Without `datetime` the version of today; with `datetime: "2015-01-01"` (collections, `source.parameters`
  of `process_aggregate-features`) the version that applied then, also of objects that are now demolished
  or withdrawn. The searches have no `datetime`.
- The state just before a change (the status before a demolition, the verblijfsobjecten of then):
  `collection_<type>` with `ids` or `maaktDeelUitVan` and `datetime` = the day before `beginGeldigheid`.

### 4.6 Characteristics under investigation (kenmerken in onderzoek)

If an answer depends on one value of one object, or a value seems improbable: `process_aggregate-features`
with `source: {"collection": "kenmerkinonderzoek", "parameters": {"datetime": "now", "filter": "object IN
('<id>') AND inOnderzoek = true"}}`, `groupBy: ["kenmerk"]`; no groups = nothing under investigation. One
object per call; not by default with every question.

### 4.7 Checking demolition

'Pand gesloopt' also ends a merger with a neighbouring pand (which becomes larger on the same date and
takes over the verblijfsobjecten with their addresses) and a pand that was never built. Per pand, only
for the larger ones (`grondoppervlakte` ≥ 50 m²) and only if the question requires it (a few calls per
pand):

1. The status the day before `beginGeldigheid`: `collection_pand` with `ids` and `datetime`. If that was
   'Bouwvergunning verleend', the pand was never built.
2. The verblijfsobjecten of that day: `collection_verblijfsobject` with `maaktDeelUitVan` and `datetime`.
   If they are now (`ids`, without `datetime`) in use in another pand, it is a merger; if they are
   'Verblijfsobject ingetrokken', a real demolition.
3. For a merged pand `query_pand-met-inhoud` returns only the pand, without verblijfsobjecten: that is the
   sign, not an empty pand.

State the result per kind (really demolished, merged, never built).

### 4.8 Combining with other APIs

- **BGT**: the topography around an address (`process_pand-bij-adres` returns the BGT objects at the spot;
  `query_wat-ligt-hier` with the point of the verblijfsobject). A BGT pand refers with
  `identificatieBAGPND` to the BAG pand.
- **Wijken en buurten** provides only names, codes and boundaries, no inhabitants; BAG numbers are counts
  of objects, not CBS statistics. **Postcodegebieden**: the postcode of a nummeraanduiding refers to it.
- **DSO**: the rules at an address (postcode and house number). A point in the Rijksdriehoeksstelsel (Dutch
  national grid): the argument `crs` = `http://www.opengis.net/def/crs/EPSG/0/28992` for the collections
  and searches.

### 4.9 Examples

**How many homes does each wijk of Amersfoort have?** `process_aggregate-features` with `source:
{"collection": "verblijfsobject", "parameters": {"gemeentecode": "0307", "gebruiksdoel": "woonfunctie",
"filter": "status IN ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing
verblijfsobject')"}}`, `groupBy: ["wijkcode", "wijknaam"]`. Say that verblijfsobjecten with woonfunctie
were counted, including mixed functions, with these statuses.

**How many homes are there per construction period in wijk Stadskern?** The same source with `wijkcode:
"WK030701"`, `groupBy: [{"property": "bouwjaarPand", "bucket": 50}]`, `aggregates: ["count", {"function":
"avg", "property": "oppervlakte"}]`.

**Which panden have been registered as demolished since 2020 in buurt Hof?** `query_panden-in-gebied` with
`gebied: "BU03070100"`, `status: ["Pand gesloopt"]`, `sinds: "2020-01-01"`, `weglaten` without
`grondoppervlakte`. Split by size; for the large panden §4.7.

**What is the nearest shop to Stadhuisplein 1?** `query_adres-op-postcode` (3811LM, 1) → point of the
verblijfsobject → `process_nearest-features` with `source: {"collection": "verblijfsobject",
"parameters": {"gebruiksdoel": "winkelfunctie", "status": "Verblijfsobject in gebruik", "properties":
"heeftAlsHoofdadres,gebruiksdoel,oppervlakte"}}`, `point`, `distance: 500`. Without a status, withdrawn
shops are included as well.

---

## 5. BGT: the topography

### 5.1 Scope

The map of the Netherlands at the level of streets and buildings, with history. Which area the server
contains is stated in the instructions of the server. A question about a place outside it: say that the
data is missing there, not that there is nothing.

### 5.2 Which tool for which question

| Question | Tool |
|---|---|
| How many, how many m², how many metres, per kind or per area | `process_aggregate-features` (of the BGT server) |
| Distribution of an area: greenery, paving, water, buildings | `process_aggregate-features` with `clip` (§3.7), or `query_topografie-in-gebied` for the objects |
| Roads, cycle paths, footpaths, parking areas, railway in an area | `query_wegen-in-gebied` (functie, fysiekVoorkomen) |
| Trees, benches, lampposts, manholes, signs, playground equipment | `query_inrichtingselementen-in-gebied` (soort) |
| Parks, playgrounds, sports fields, cemeteries, canopies, street name labels | `query_overige-objecten-in-gebied` |
| What is at or near an address or point | `query_wat-ligt-hier` (point from the BAG) |
| What has changed in an area, new, modified, disappeared | `query_wijzigingen-in-gebied` (sinds, tot) |
| Objects of one collection with a property or in a bbox | `collection_pand`, `collection_wegdeel`, `collection_begroeidterreindeel`, `collection_onbegroeidterreindeel`, `collection_waterdeel` |

The other collections have no tool of their own; they are reachable via the searches and via
`process_aggregate-features` (`source.collection` with their id, also a list of ids). The meaning of the
values per collection is in separate value lists (not in this skill); read those if it is unclear which
value belongs to a concept (is a lawn 'grasland overig' or 'groenvoorziening'?).

### 5.3 Areas and size

- The searches take one code in `gebied`; collections and `source.parameters` filter on `gemeentecode`,
  `wijkcode` or `buurtcode`. The buurtcode contains the gemeente and wijk code.
- An object belongs to exactly one buurt (point on the geometry). For areas within a region: `clip`, with
  `gemeentecode` in the source (§3.7).
- A municipality of 150,000 inhabitants has around 250,000 polygons (wegdeel and begroeidterreindeel each
  around 50,000, pand around 90,000). `process_aggregate-features` reads at most 100,000 objects: over a
  whole municipality one collection per call. With `clip` the limit only applies after clipping.
- `query_topografie-in-gebied` for a buurt returns hundreds of objects (around 450 bytes per object
  without geometry); for a wijk thousands. Fetch only for a list or a map, not to count.

### 5.4 Classification of the objects

| Collection | Classification (BGT; finer in IMGeo-plus) |
|---|---|
| wegdeel, ondersteunendwegdeel | bgtFunctie, bgtFysiekVoorkomen; plusFunctie, plusFysiekVoorkomen |
| spoor | bgtFunctie; plusFunctie |
| begroeidterreindeel, onbegroeidterreindeel | bgtFysiekVoorkomen; plusFysiekVoorkomen |
| waterdeel, ondersteunendwaterdeel, overigbouwwerk, kunstwerkdeel, scheiding, functioneelgebied | bgtType; plusType |
| overbruggingsdeel | typeOverbruggingsdeel, hoortBijTypeOverbrugging |
| openbareruimtelabel | openbareRuimteType, openbareRuimteNaam |
| inrichtingselementen (bak, bord, installatie, kast, mast, paal, put, sensor, straatmeubilair, waterinrichtingselement, weginrichtingselement, vegetatieobject), gebouwinstallatie, overigescheiding | plusType |
| pand | none; identificatieBAGPND refers to the BAG |

- Specify values exactly as in the value lists, with spaces and lower case (`bgtFunctie=rijbaan lokale
  weg`). A searchable property as a parameter has one value; more with a filter:
  `filter=bgtFunctie IN ('fietspad','voetpad')`.
- A value with a colon refines the value before it: `'recreatie: speeltuin'` is a kind of `'recreatie'`.
  All kinds together: `filter=plusType LIKE 'recreatie%'`.
- The value `transitie` occurs for bgtFunctie and bgtType, but is in no value list; there is no
  definition.

### 5.5 IMGeo-plus and bronhouders

- IMGeo-plus (plusFunctie, plusFysiekVoorkomen, plusType and all inrichtingselementen) is optional: only
  filled where the bronhouder (source holder) maintains it. If the value is missing, there is a reason:
  `waardeOnbekend` or `geenWaarde`; some objects (poles) have no plusType at all.
- The bronhouder is not always the municipality: in a municipality there are also objects of neighbouring
  municipalities (G...), the province (P...), the water board (W...) and the national government (L...:
  Rijkswaterstaat, ProRail). The names are in the code list `/bgt/codelists/bronhouder`.
- Counting inrichtingselementen: first group on `["plusType", "bronhouder"]`. Example from a trial: of 420
  lampposts, 364 came from the province and 16 from the municipality; of 1,687 trees 12 from the
  municipality. A handful of benches or no playground equipment for a city means that the municipality does
  not maintain them in the BGT, not that they are not there. Say "registered in the BGT" and who maintains
  them.
- For shares per fysiek voorkomen: `plusFysiekVoorkomen` 'waardeOnbekend' can be a fifth of the road area
  (the large roads of other bronhouders); the BGT value (`bgtFysiekVoorkomen`) is complete.

### 5.6 Area, length and shares

- At ground level (relatieveHoogteligging 0) the polygons cover the area without gaps and overlap; the sum
  per kind is the distribution of the area. Bridges, canopies (1 and higher) and tunnels (-1 and lower) do
  not count. Functional areas (parks, playgrounds) overlap the polygons and do not count either.
- Greenery for a share: `begroeidterreindeel` (all kinds), optionally per `bgtFysiekVoorkomen`.
  `onbegroeidterreindeel` with bgtFysiekVoorkomen 'erf' is the land at a pand: gardens, courtyards,
  driveways. A share of greenery therefore contains no gardens; state the share of erf as well, especially
  in residential neighbourhoods.
- The total for a share: the sum of the polygons at ground level with the same `clip`, not the area from
  another source.
- `oppervlakte` (m²) and `lengte` (m) are not in the output of the collections by default; in
  `process_aggregate-features` `$area` and `$length` are the area and length of the geometry (with `clip`
  of the part within the region).
- Panden have no bgtFysiekVoorkomen; in a grouping on that property they are in the group without that
  key. BGT pand and BAG pand differ in area by at most one percent.

### 5.7 Time and versions

- Without `datetime` the API returns what is now in the registration, so only existing objects. With
  `datetime=2020-01-01T00:00:00Z` the state at that moment.
- **The history starts per bronhouder at the first delivery** (for most municipalities end of 2016). Do not
  compare with a date before that; an increase between two dates can also be finer data collection.
- `query_wijzigingen-in-gebied`: a version without a 'predecessor-version' link is a new object; an
  objectEindTijd is a terminated object. An object that ended in the period is returned with its last
  version, even if that is from before the period. A new version can be a change in reality or a
  correction; the BGT does not make that distinction.
- **How much has changed**: `process_aggregate-features` with `source: {"query": "wijzigingen-in-gebied",
  "parameters": {"gebied": ..., "sinds": ..., "tot": ...}}` and `aggregates: ["count"]`, grouped on
  `$collection`; the total is the number of objects that are new, modified or terminated in the period (an
  object with several versions counts once). Do not count with collections and a filter on
  `objectBeginTijd` or `tijdstipRegistratie`: that misses the objects that were terminated in the period.
  Do not fetch the versions to count.
- Finding bulk operations: `process_aggregate-features` with the search as source, `groupBy:
  ["$collection", {"property": "tijdstipRegistratie", "bucket": "month"}]`; a peak then per exact
  `tijdstipRegistratie` and `bronhouder`. Hundreds of objects from one bronhouder with the same time are
  an administrative entry or re-survey. `bucket` for a time is `year`, `month` or a number.
- Start with a buurt or a short period: a municipality over more than a year hits the limit of 100,000.

### 5.8 Combining with other APIs

- **Address → point**: the BAG (`query_adres-op-postcode`) returns the geometry of the verblijfsobject as
  longitude/latitude; use it with `query_wat-ligt-hier` (`punt`, optionally `afstand` up to 100 m) or
  `process_aggregate-features` with `clip`.
- **Pand**: `identificatieBAGPND` is the identification of the pand in the BAG. **Street**:
  `identificatieBAGOPR` of an openbareruimtelabel is the openbare ruimte in the BAG.
- **Homes or inhabitants in an area**: not in the BGT; the BAG counts verblijfsobjecten, the
  Postcodegebieden have CBS figures.

### 5.9 Examples

**What percentage of wijk Stadskern is green?** (1) `collection_wijk` with `gemeente=0307`,
`naam=Stadskern` → id `WK030701` and the geometry. (2) `process_aggregate-features` with `source:
{"collection": ["wegdeel", "ondersteunendwegdeel", "begroeidterreindeel", "onbegroeidterreindeel",
"waterdeel", "ondersteunendwaterdeel", "pand", "overigbouwwerk", "kunstwerkdeel", "spoor"], "parameters":
{"gemeentecode": "0307", "filter": "relatieveHoogteligging = 0"}}`, `clip: {"geometry": <geometry of the
wijk>}`, `groupBy: ["$collection", "bgtFysiekVoorkomen"]`, `aggregates: [{"function": "sum", "property":
"$area"}]` (around 4 seconds). (3) Share = begroeidterreindeel / total; state the share of erf as well.

**How many trees are there per buurt in Amersfoort?** `process_aggregate-features` with `source: {"query":
"inrichtingselementen-in-gebied", "parameters": {"gebied": "0307", "soort": ["boom"]}}`, `groupBy:
["bronhouder", "buurtcode"]`. Present as "registered in the BGT", with who maintains them.

**How many m² of cycle path is there in wijk Stadskern?** `process_aggregate-features` with `source:
{"collection": "wegdeel", "parameters": {"gemeentecode": "0307", "bgtFunctie": "fietspad"}}`, `clip` with
the geometry of the wijk, `aggregates: [{"function": "sum", "property": "$area"}]`.

**What is at Stadhuisplein 1, Amersfoort?** `query_adres-op-postcode` (3811LM, 1) → point of the
verblijfsobject → `query_wat-ligt-hier` with that point and `afstand` 20 to include the street and the
greenery in front of it.

---

## 6. CBS: Wijken en buurten, Postcodegebieden

### 6.1 Scope

- **Wijken en buurten**: municipalities, wijken and buurten according to the Wijk- en Buurtkaart 2026 with
  name, code and boundary. **No inhabitants or other figures.**
- **Postcodegebieden**: statistics per postcode (PC6) on 1 January 2024: inhabitants by gender, age and
  origin, households, homes by year of construction and ownership, benefits.
- Figures per buurt or wijk (inhabitants, WOZ value (property tax valuation), income) from the CBS Kerncijfers
  wijken en buurten are in neither.

### 6.2 Wijken en buurten

- Tools: `collection_gemeente`, `collection_wijk`, `collection_buurt`. The code is the id of the object;
  `wijk` and `gemeente` of a buurt are references with the name as title.
- Names are case-sensitive (`Hof` finds the buurt, `hof` nothing); see §3.1 for searching. Many buurten are
  named after a street with 'e.o.' (`Kersenbaan e.o.`): search with `*`.
- A buurt or wijk by municipality name: `filter: "gemeentenaam = 'Amersfoort'"` (only as a filter; the name
  is not in the output).
- **Size**: without `properties` the full geometry is included (around 2 to 4 kB per buurt, a municipality
  around 80 kB). For names and codes `properties: ["naam", "wijk"]` and `limit` 500. For `clip` the full
  geometry of one buurt or wijk. For a map `zoom-level` 12 (a municipality around 3 kB), or the link from
  the result.

### 6.3 Postcodegebieden

- `collection_postcode6` with `postcode`, `gemeentecode`, `wijkcode` or `buurtcode`; other properties with
  `filter` (`filter: "postcode LIKE '3811%'"`, `filter: "aantal_inwoners >= 500"`). Without `properties`
  the geometry is included (around 1.4 kB per postcode).
- `process_aggregate-features` of this server counts and sums per municipality, wijk or buurt without
  fetching the postcodes: `source: {"collection": "postcode6", "parameters": {"gemeentecode": "0307"}}`,
  `groupBy: ["wijkcode"]`, `aggregates: [{"function": "sum", "property": "aantal_inwoners"}, {"function":
  "count", "property": "aantal_inwoners"}, "count"]`. `count` with a property counts the postcodes with a
  value; put it next to `count` without a property to say how many postcodes are included. The groups have
  the code as key; the names come from Wijken en buurten.
- A postcode area belongs to the buurt in which a point within the area lies; a few postcodes of addresses
  in the municipality lie in a neighbouring municipality according to the CBS. In the BAG the postcode of a
  nummeraanduiding refers to the postcode area.

### 6.4 Pitfalls: what a missing value means

- Numbers are rounded to multiples of five, percentages to tens. The CBS publishes a value only for at
  least five inhabitants, households or homes (percentages for at least ten). **A missing value is 0 to 4
  or confidential**, not zero and not an unknown number. Some postcodes have no properties at all.
- How often values are missing (one municipality, over 3,600 postcodes): number of inhabitants 8 %, age
  classes 22 to 55 %, construction year classes 81 to 94 %, single-parent households 93 %, percentage of
  owner-occupied homes 42 %, rental homes 73 %.
- **Sums are lower bounds**, sums of subgroups even more so: the sum of the age classes was 8 % below the
  sum of the inhabitants, the sum of the four household types 20 % below the sum of the households. Say
  "at least" or "about" and that postcodes with few inhabitants are missing.
- **Percentages** and the average household size cannot be added up. A weighted average (`{"function":
  "avg", "property": "percentage_koopwoningen", "weight": "aantal_woningen"}`) counts only the postcodes
  with a value; because owner-occupied and rental often have only one of the two, the weighted averages
  together add up to far above 100 %. A share of owner-occupied homes per wijk does not follow from it:
  give the spread or say that the CBS publishes it per wijk in the Kerncijfers.
- **Sorting**: `sortby: "-aantal_inwoners"` puts the postcodes without a value first; filter on
  `aantal_inwoners IS NOT NULL`. A comparison (`< 5`) never hits a missing value.
- **Size**: a postcode with two properties without geometry is around 200 bytes; a buurt of 25 to 50
  postcodes fits easily. A whole municipality (3,600 postcodes) with one property is 300 kB and does not
  fit in the answer: count with `process_aggregate-features`, or fetch per wijk. The geometry of all
  postcodes of a municipality is more than a megabyte: only as a link for a map.

### 6.5 Examples

**How many households do the postcodes that start with 3817 have?** `process_aggregate-features`
(Postcodegebieden) with `source: {"collection": "postcode6", "parameters": {"filter": "postcode LIKE
'3817%'"}}`, `aggregates: [{"function": "sum", "property": "aantal_part_huishoudens"}, {"function": "count",
"property": "aantal_part_huishoudens"}, "count"]`. Answer: "at least ..., in ... of the ... postcodes;
postcodes with fewer than five households are missing".

**Which postcode in a municipality has the most children under 15?** `collection_postcode6` with
`gemeentecode`, `filter: "aantal_inwoners_0_tot_15_jaar IS NOT NULL"`, `sortby:
"-aantal_inwoners_0_tot_15_jaar"`, `properties: ["postcode", "aantal_inwoners_0_tot_15_jaar", "buurtcode"]`,
`limit` 5.

---

## 7. DSO: rules of the Omgevingswet at an address

### 7.1 Scope

The workflows call the APIs of the Digitaal Stelsel Omgevingswet (DSO) live, with the BAG of this server
for the address. They are adapted, unofficial copies of workflows of the DSO team. An answer is
information, not legal advice or a decision: refer to the Omgevingsloket (omgevingswet.overheid.nl) or the
municipality for certainty. A call takes 1 to 4 seconds, with errors of the DSO itself up to half a minute
(the workflow then retries a step a few times); do not call a workflow again unnecessarily.

### 7.2 Which workflow for which question

| Question | Workflow |
|---|---|
| What may I do here regarding housing, which housing rules apply | `regels-over-wonen` |
| May I build a dormer (or something else) here, do I need a permit | `dakkapel-hier` (permit check in rounds) |
| Is something in the pipeline, what is changing, draft designs in progress | `wat-verandert-hier` |
| Prepare an application or notification: activity, competent authority, questions, can it be submitted? | `verzoek-voorbereiden` (submits nothing) |
| Which documents applied here on a date | `documenten-op-peildatum` |
| The versions of a regulation | `versiehistorie` |
| The details of a regulation | `regeling-detail` |
| Which rules applied here on a date, and their text | `regels-op-peildatum`, then `ow-tekst-ophalen` |

### 7.3 Input

- **Address**: postcode without a space (`3811LM`) and house number as text (`"1"`, not a number), without
  house letter or addition. The first step looks in the BAG of this server for **exactly one** address with
  that postcode and house number, with a verblijfsobject. That fails for addresses with a house letter or
  addition (one in five), for a bare number next to numbers with a letter (12 next to 12A), for berth and
  pitch locations and outside the area of the BAG. The error is then 422 "The step 'adres' of the workflow
  ... failed", without a reason. Check the address with `query_adres-op-postcode` (BAG): if it exists, say
  that the workflow cannot handle this address (not that it does not exist), and offer an address without a
  letter in the same pand if the question is about the pand. If in doubt, do the same check beforehand.
- **Two date notations**: `datum` is `dd-MM-jjjj` (applicable rules, usually today), `peildatum` is
  `jjjj-MM-dd`. `verzoek-voorbereiden` asks for the same day in both notations.
- **Regulation**: `uriIdentificatie` with underscores, as the workflows return it, for example
  `_akn_nl_act_gm0307_2020_omgevingsplan`; the form with slashes is rejected.
- **Point in RD** (`rdX`, `rdY` for the peildatum workflows): the BAG returns it with the argument `crs` =
  `http://www.opengis.net/def/crs/EPSG/0/28992`, for example `query_adres-op-postcode` (postcode,
  huisnummer, crs): the geometry of the verblijfsobject is then `[rdX, rdY]`. Only if the BAG tools are not
  available: convert longitude/latitude with the approximation formula (accurate to about 1 m):
  ```
  dp = 0.36 * (lat - 52.15517440);  dl = 0.36 * (lon - 5.38720621)
  rdX = 155000 + 190094.945*dl - 11832.228*dp*dl - 114.221*dp^2*dl - 32.391*dl^3 - 0.705*dp
        - 2.340*dp^3*dl - 0.608*dp*dl^3 - 0.008*dl^2 + 0.148*dp^2*dl^3
  rdY = 463000 + 309056.544*dp + 3638.893*dl^2 + 73.077*dp^2 - 157.984*dp*dl^2 + 59.788*dp^3
        + 0.433*dl - 6.439*dp^2*dl^2 - 0.032*dp*dl + 0.092*dl^4 - 0.054*dp*dl^4
  ```
  Check: lon 5.38416472, lat 52.15671963 → rdX 154792, rdY 463172. Always take the point of the address
  from the question.

### 7.4 Errors

- 422 about the step 'adres': see Input. 502, 503 or 504, or a message that an OpenAPI document from
  `service.omgevingswet.overheid.nl` cannot be read: the DSO is unreachable. Do not retry with other
  input; tell the user that the DSO is not answering now. A failed workflow never means "no rules apply".
- 429 "workflows are already running": at most three workflows at the same time. Call them one after the
  other, not in parallel, and try again after a few seconds.
- 422 with a 404 from the DSO "kan niet gevonden worden voor tijdreis" (cannot be found for time travel)
  (`regels-op-peildatum`): the regulation did not yet apply or no longer applied on that peildatum
  (reference date); that is an answer, not a malfunction.

### 7.5 Reading the output

- **Parallel lists**: elements at the same position belong together (`activiteiten[i]`, `conclusie[i]`,
  `vraagIds[i]`). Do not add up and do not sort separately. `null` at a position: no value for this
  element.
- **Rule texts** (`owTeksten`, output of `ow-tekst-ophalen`) are XML according to STOP: the text is in
  `<Al>` (paragraphs) and `<Li>` (list items with `<LiNummer>`); ignore the attributes. The article number
  is in the identification, for example `..._art_22.31` → article 22.31. Give the text in ordinary
  sentences or as a list, not as XML.
- **Omgevingsplan and bestemmingsplannen** (zoning plans): until a municipality has fully renewed its
  omgevingsplan, the rules of the old bestemmingsplannen (Wro) apply as part of the omgevingsplan. The
  workflows return both: `omgevingsplan`, `owArtikelen`, `owTeksten` (new) and `wroPlannen`,
  `wroBestemmingen`, `wroMaatvoeringen` (old). Mention both.

### 7.6 Per workflow

**regels-over-wonen**: searches the bestemmingsplannen only for the main group 'wonen'. In city centres
housing often falls under 'centrum' or 'gemengd'; an empty `wroBestemmingen` therefore does not mean that
housing is not allowed there. Say so.

**dakkapel-hier** (permit check):
1. First round without `antwoorden`, `activiteit` as a short term (`dakkapel`), `datum` today. The output
   has per activity found (usually a municipal one and one from the national government) the questions
   `vragenVergunningcheck[i]` with ids `vraagIds[i]`, and `conclusie[i]`.
2. Ask the questions to the user; never answer them yourself or with assumptions. The first round returns
   all questions that may apply (for a dormer 10 yes/no questions: roof covering all around, above the
   ridge, monument, front, roof plane towards public area, flat roof, height, distances to eaves, ridge and
   roof edge); ask them together or in a few groups. Answered questions are not marked: keep track yourself
   of what has already been asked and do not ask a question twice.
3. Next round with all answers so far in one list `{id, antwoord}`: `id` as a number, yes/no as
   `"true"`/`"false"`, a choice as the text of the option. New questions may follow.
4. Done when every `conclusie[i]` has a value: 'Vergunningplicht', 'Toestemmingsvrij', 'Neem contact op
   met' (the municipality must assess it) or 'Niet van toepassing' (that check does not apply here; no
   judgement on the question). Usually after two rounds. The form of `vraagIds` can differ per round (a
   list per activity or one list). `aanvragenVoor[i]` is the activity for which one then applies or
   notifies.

The articles from the omgevingsplan (`owArtikelen`, `owTeksten`) belong to the municipal activity; they
can be more general than the question. The national rules from the Besluit bouwwerken leefomgeving are not
in them; the national permit check is.

**wat-verandert-hier**: `ontwerpen`, `typen`, `eindeInzage`, `wijzigingenArtikelen` and `wijzigingenTekst`
are parallel. A draft is not yet law; until and including `eindeInzage` anyone can submit a zienswijze
(view/objection). The changes only name the operation per part (`toevoegen`, `verwijderen`), not the text:
count them at most. Programmes and visions of the province or national government (for example the Nota
Ruimte) apply to large areas and say little about this spot; first state what the municipality changes.
`toekomstigGeldend` and `wroInProcedure` are pairs of title and date or kind.

**verzoek-voorbereiden**: `toestemming` is mandatory: `Vergunning`, `Melding`, `Informatie`,
`InformatieOngewoonVoorval` or `AanvraagMaatwerkvoorschrift`. In `antwoorden` the `id` here is text, not a
number as with `dakkapel-hier`. `zoekterm` must be specific (for example `boom kappen`). A broad term
(`bouwen`) returns many `kandidaten` and stops: choose one with the user and search more specifically.
**Check whether the chosen `activiteit` fits the question**: 'bed and breakfast' returned an excavation
activity (ontgrondingsactiviteit) of the national government. If it does not fit, do not use the output
and say that the system found no activity for the term. A term that the system does not know for the
municipality returns nothing; try a synonym, or for building activities `dakkapel-hier`. `indienbaar`
false with `verplichteVragen`: complete the answers (`antwoordenAlgemeneSet`, `antwoordenActiviteit`) and
try again. The workflow never submits anything.

**Peildatum** (the state on an earlier date):
1. `documenten-op-peildatum` with `rdX`, `rdY`, `peildatum` → `typen`, `titels`, `uriIdentificaties`
   (parallel). For every date in the past the DSO also returns a fixed series of later documents under the
   Omgevingswet. A document whose year in the `uriIdentificatie` (`_akn_nl_act_<organisatie>_<jaar>_...`)
   is after the peildatum did not apply then: leave it out. Before 1 January 2024 the bestemmingsplannen
   (`NL.IMRO...`) applied; the Omgevingswet was not yet in force.
2. `regeling-detail` and `versiehistorie` with a `uriIdentificatie`, only for documents under the
   Omgevingswet (not for bestemmingsplannen or structuurvisies).
3. `regels-op-peildatum` with `uriIdentificatie`, `rdX`, `rdY`, `peildatum` → the activities at the point
   and the `regeltekstWIds`. For an omgevingsplan those are hundreds of rules: choose the wIds that belong
   to the question.
4. `ow-tekst-ophalen` with the same `uriIdentificatie`, a `wId` exactly as returned and **the same**
   `peildatum`; without a peildatum a wId of an older version does not exist.

### 7.7 Presenting the answer

First the answer, then the source: document (title), article and date. For a permit check: the conclusion
per activity and the answers on which it rests. Say that it is information from the DSO on the day of the
call, not a decision, and that the Omgevingsloket and the municipality are the official source.

Not yet verified: the chain `regels-op-peildatum` → `ow-tekst-ophalen` for an omgevingsplan (number of
wIds) and activities other than a dormer in the permit check.

---

## 8. Subsurface: subsurface-models

### 8.1 Scope

REGIS II (layers) and GeoTOP (voxels). Tool names start with `subsurface-models.`. Results are model
evidence, never a judgement. The data are voxel and raster models, not feature types: there is no tool for
raw data; every data tool is a stored query or processing.

### 8.2 Model: categories

| Category | Meaning |
|---|---|
| Raw data | One feature type of one dataset; filter and limit the response. |
| Stored query | A frequently asked question with simpler parameters; still feature data. |
| Processing | *Aggregation* (feature data plus count, sum) or *workflow* (linked steps under a versioned method). |
| Plot | Returns an image, not data. |
| Information model | What a model element means and how elements relate; no model data. |
| Methods and provenance | What the server computes and how, and which models it contains. |

### 8.3 Which tool for which question

| Tool | Category | Explanation |
|---|---|---|
| `trace` | Stored query | Vertical column at a point (REGIS II units, GeoTOP voxels). Optional `minDepth`/`maxDepth` (m below the ground level of the model); reports what was omitted. |
| `section` | Stored query | Vertical cross-section along a line. Optional `elevationTop`/`elevationBottom` (m NAP). Bounded, with a `window`. |
| `layers` | Stored query | Layers that overlap an elevation interval (m NAP) at a point. |
| `area-summary` | Processing (aggregation) | Share of an area (arbitrary polygon) that is occupied by a GeoTOP lithoclass, over a depth range, in one call, from the 2D cell raster. Probabilities, GeoTOP only; follow-up pages for large areas. |
| `band-confinement` | Processing (workflow) | Whether lithoclass codes specified by the caller as confining span every sampled bin of a cross-section. The codes are the caller's; the server applies no rules of its own. |
| `trace-plot`, `section-plot` | Plot | The trace or cross-section as PNG. |
| `concepts.schemes` | Information model | Catalogues behind the server (GTM, HGM, SM). |
| `concepts.lookup` | Information model | Meaning of a GeoTOP or REGIS II term. |
| `model.search` | Information model | Find an element when the name is unknown. Use first. |
| `model.describe` | Information model | Element with attributes, relations and identifications. |
| `model.gaps` | Information model | What the semantic layer does not express. |
| `methods.list`, `methods.describe` | Methods and provenance | Methods with version, input, assumptions and limits; read `methods.describe` before relying on a result. |
| `bundle.list` | Methods and provenance | Models in the configured bundle (not the catalogues). |

Choosing: unknown term → `model.search`, then `model.describe` or `concepts.lookup`. One place → `trace`;
a line → `section`; one depth interval at a place → `layers`. How much of an area is a lithoclass →
`area-summary`. A picture → `trace-plot` or `section-plot`. How a result was made → `methods.describe`.

### 8.4 Pitfalls

- **Evidence, not a judgement.** Report lithoclass or probability as the model gives it; "soft soil" or
  "confining" is the caller's definition, which you pass on.
- **Aggregate in one call, never with a loop.** For a share over an area `area-summary`, not `trace` per
  cell.
- **Depth reference.** `trace` depths are m below the ground level of the model; `section` and `layers`
  use m NAP. If the question measures from AHN ground level or NAP: convert explicitly and report
  differences, do not hide them.
- **Paginate and say so.** `window` (`total`, `returned`, `truncated`): collect all windows before you
  compute, or report that you did not. Only GeoTOP gives probabilities; REGIS II returns units.

---

## 9. Groundwater: groundwater-monitoring

### 9.1 Scope

Tool names start with `groundwater-monitoring.`. Source: BRO GMW (wells), GLD (level series), GMN
(monitoring networks).

### 9.2 Model: categories

Raw data (one feature type, no interpretation), Stored query, Processing, **Data preparation and quality**
(turns raw observations into an analysis-ready series or assesses one, under a named, versioned rule set),
Plot, Information model.

### 9.3 Which tool for which question

| Tool | Category | Explanation |
|---|---|---|
| `wells.get` | Raw data (GMW) | One well by BRO id: all tubes, construction and filter interval where reported. A missing position is reported as missing, never derived. |
| `networks.get` | Raw data (GMN) | One monitoring network by BRO id, current registered situation. |
| `networks.list` | Raw data (GMN) | BRO ids of the monitoring networks for which a bronhouder (source holder) is responsible. |
| `series.get` | Raw data (GLD) | Observations of one GLD investigation id, every observation type, not merged. Bounded: at most 500 values, `from`/`to` select the period, `window` reports the cut-off. |
| `tubes.search` | Stored query | Wells within a radius of a GeoJSON WGS84 point, worked out into tubes (GMW) with distance, filter depth and registered GLD series. Proximity is not relevance. |
| `series.daily` | Data preparation (workflow) | Representative daily level of one tube across all its GLDs, rule `noon-closest-priority-v1`. NAP, at most 90 days, `window` reports the cut-off. |
| `series.assess` | Data preparation (workflow) | Merges the series of a tube and assesses them against `series-quality-v3`. `full=true` adds the calibration values for server-to-server callers. |
| `series.plot` | Plot | The `series.daily` series as an image. |
| `concepts.schemes`, `concepts.lookup` | Information model | BRO domain tables; meaning of a BRO code or status value. |
| `model.search`, `model.describe`, `model.gaps` | Information model | Find an entity (first), describe it, what the semantic layer does not express. |

No tool here is an aggregation tool yet. Choosing: unknown term or code → `model.search`; wells near a
place → `tubes.search`; one well in full → `wells.get`; levels of one tube → `series.daily` for the
analysis-ready series, `series.get` for the raw observations, `series.assess` for suitability; a picture →
`series.plot`.

### 9.4 Pitfalls

- **Proximity is not relevance.** A tube within the stated distance is a candidate; filter depth and unit
  (phreatic or not) must still fit the question.
- **The coverage rule in the question** (years, share of days, gap length) is not the quality rule set of
  the server (`series.assess` uses 8 years); say which one was decisive.
- **`series.daily` is bounded to 90 days per call**; five years means paginating and collecting all
  windows before you compute.
- **Never mix measured and modelled silently**; label every series with its source.

---

## 10. Virtual groundwater levels: virtual-groundwater-heads

### 10.1 Scope

Tool names start with `virtual-groundwater-heads.`. Everything produced here is **derived**, never
measured, and carries its method, version and input. The source data come from groundwater-monitoring and
subsurface-models. Documentation is also available as resources (`groundwater://rules/...`,
`groundwater://methods/...`, `groundwater://apis/knmi`, `groundwater://project/information-model`), to be
read via `resources/read`.

### 10.2 Which tool for which question

| Tool | Category | Explanation |
|---|---|---|
| `meteo.stresses` | Stored query | KNMI daily precipitation (`RH`) and Makkink evaporation (`EV24`) for a location and period; chosen and skipped stations are reported. |
| `tubes.subsurface` | Processing (workflow) | The filter of a tube placed in REGIS II units and GeoTOP voxels (well metadata plus `subsurface-models.trace`). Evidence, not a judgement. |
| `tubes.select` | Processing (workflow) | Whether a tube is relevant evidence for a target and a depth given by the caller, under `tube-selection-v1`. |
| `tubes.geotop-confinement` | Processing (workflow) | Lateral GeoTOP clay/peat continuity between a target and the filter of a tube (`geotop-lateral-confinement-v1`). |
| `series.tfn` | Processing (workflow) | Transfer function noise model of one tube via pastas, assessed against `tfn-acceptance-v1`. Requires the Python runner. |
| `analysis.residual-dynamics` | Processing (workflow) | METRAN over the TFN residuals of three or more tubes; the scientific route. |
| `analysis.common-dynamics` | Processing (workflow) | Only as a baseline: METRAN over supplied measured series. |
| `estimate.series` | Processing (workflow) | Virtual daily level series at a location (`estimation-v2`), with spatial baseline and approximate band. |
| `estimate.plot` | Plot | An existing `estimate.series` result as SVG. |
| `concepts.schemes`, `concepts.lookup`, `model.search`, `model.describe`, `model.gaps` | Information model | The VGH catalogue and derived concepts (self-written, provisional; no MIM model behind it). |

No tool here is raw data or aggregation. Choosing: meaning of a derived value → `model.search`,
`model.describe`, then the method resource; which tubes count for a place and depth → `tubes.select` with
`tubes.subsurface` and `tubes.geotop-confinement` as evidence; stresses → `meteo.stresses`; the response of
one tube → `series.tfn`; shared dynamics of several tubes → `analysis.residual-dynamics`; a level series at
a location → `estimate.series`, then `estimate.plot`.

### 10.3 Pitfalls

Virtual levels are derived and a proof of concept: label them as such and never mix them silently with
measured levels. `tubes.select` is cautious and does not decide whether a filter is phreatic.

---

## 11. Soil + groundwater combined

**What use cases have in common**

| Element | Use case 1 (buurten) | Use case 2 (panden) |
|---|---|---|
| Unit of analysis | CBS buurt (polygon) | BAG pand (polygon, point) |
| Selection and ranking from a register | Paved share from BGT, rank, top 3 | Year of construction before 1970 from BAG |
| Subsurface indicator | Share of GeoTOP voxels above a clay probability, top 5 m | Clay or peat probability per voxel, top 5 m, per pand |
| Groundwater evidence | none | Measured phreatic series within 50 m, otherwise modelled |
| Derived indicator | Combined score of two shares | Time below an assumed level (five measures) |
| Output | Ranked JSON | Map, table per pand, time series plot, disclaimer |

**Rules that keep the order honest:** subsurface tools are evidence, not a judgement; aggregate in one
call; mind the depth reference; never mix measured and modelled silently; proximity is not relevance; the
coverage rule of the question is not that of the server; paginate and say so.

**Open points** (answered by no tool; compute yourself, ask, or report as open):

| Point | Where it plays |
|---|---|
| Register data (BAG, BGT, CBS, AHN) | Step 1 and 2; AHN outside these servers |
| Point-wise subsurface summary for many objects in one call | Use case 2 requires one `trace` per pand |
| Indicators below a level on a series (five measures) | Step 6 |
| Phreatic suitability of a filter beyond matching on depth and unit | Step 4; `tubes.select` does not decide this |
| Coverage rule from the question (3 to 5 hydrological years, 90 % of the days, gaps > 7 days) | Step 4; `series.assess` uses 8 years |
| `series.daily` is bounded to 90 days per call | Step 5 |
| Reference line and marking below the level in the plot; a map | Step 8 |
| Definition of the combined score | Step 7; not defined in use case 1 |
| Inconsistent threshold: use case 1 says P(clay) > 5 %, other material 10 % | Step 0; confirm with the user |
| Use case 1 says "wijk" where it ranks buurten | Step 0; confirm the unit |

---

## 12. The answer

- First the answer with the number and what it counts: object type, statuses, area (with name, not only the
  code), the state of the data (from the instructions of the server). Per unit values with units, source
  (measured or derived), method and version, data coverage.
- Then only the caveats that belong to this question. If there is a check you did not do (demolition,
  bronhouder, sizes), state what it would yield and offer it.
- An answer from the DSO is information, not a decision; the official source is the Omgevingsloket or the
  municipality. Repeat a disclaimer from the question.
- If the user wants to verify or extend it: the calls with their arguments, or the link from the result.
