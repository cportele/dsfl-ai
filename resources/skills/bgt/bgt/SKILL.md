---
name: bgt
description: >-
  Lees dit voor vragen over de topografie in de BGT (Basisregistratie Grootschalige Topografie):
  welke tool bij welke vraag, hoe de objecten zijn ingedeeld, oppervlakten en aandelen (groen,
  verharding, water, bebouwing), wegen, inrichtingselementen en bomen, wat er op een adres ligt,
  wijzigingen, en de valkuilen; met de betekenis van alle waarden per collectie. English: read
  before answering questions about the large-scale topography of the Netherlands (BGT): choosing a
  tool, classification, areas and shares of land cover, roads, street furniture and trees, what is
  at an address, changes, pitfalls; value definitions per collection.
---

# De BGT bevragen

De BGT is de kaart van Nederland op het niveau van straten en panden. Deze API bevat het
BGT-extract van PDOK voor de omgeving van Amersfoort (stand 30 oktober 2026), met historie. Een
vraag over een plaats daarbuiten: zeg dat de gegevens daar ontbreken, niet dat er niets is.

De referentiebestanden met de betekenis van de waarden heten `references/waarden-<collectie>.md`,
bijvoorbeeld `references/waarden-wegdeel.md`; met de tool `skill_bgt` en het argument `file`.

## Welke tool voor welke vraag

| Vraag | Tool |
|---|---|
| Hoeveel, hoeveel m², hoeveel meter, per soort of per gebied | `aggregate-features` (telt en somt zonder de objecten te leveren) |
| Verdeling van een gebied: groen, verharding, water, bebouwing | `aggregate-features` met bron `topografie-in-gebied`, of die zoekopdracht zelf voor de objecten |
| Wegen, fietspaden, voetpaden, parkeervlakken, spoor in een gebied | `wegen-in-gebied` (functie, fysiekVoorkomen) |
| Bomen, banken, lichtmasten, putten, borden, speeltoestellen | `inrichtingselementen-in-gebied` (soort) |
| Parken, speeltuinen, sportterreinen, begraafplaatsen, dijken, straatnaamlabels | `overige-objecten-in-gebied` |
| Wat ligt er op of bij een adres of punt | `wat-ligt-hier` (punt uit de BAG, zie onder) |
| Wat is er veranderd in een gebied, nieuw, gewijzigd, verdwenen | `wijzigingen-in-gebied` (sinds, tot) |
| Objecten van één collectie met een eigenschap of in een bbox | `collection_pand`, `collection_wegdeel`, `collection_begroeidterreindeel`, `collection_onbegroeidterreindeel`, `collection_waterdeel` |

De andere collecties hebben geen eigen tool; men bereikt ze via de zoekopdrachten en via
`aggregate-features` (`source.collection` met hun id). Om te tellen of op te tellen nooit alle
objecten ophalen: een grote uitvoer past niet in het antwoord (de tool meldt dan een fout met de
link naar het resultaat), en `aggregate-features` geeft het getal direct.

## Gebieden

- Een gebied is een CBS-code: gemeente `0307`, wijk `WK030701`, buurt `BU03070100`. De
  zoekopdrachten nemen één code in `gebied`; collecties en `source.parameters` filteren op
  `gemeentecode`, `wijkcode` of `buurtcode`.
- De code bij een naam staat in de API Wijken en buurten (`collection_wijk`, `collection_buurt`
  met `gemeente=<gemeentecode>` en `naam`). Buurt- en wijknamen zijn alleen binnen een gemeente
  uniek. De buurtcode bevat de gemeente- en de wijkcode.
- Een object hoort bij het gebied waarin een punt op zijn geometrie ligt, dus bij precies één
  buurt. Een groot object (een weg langs de grens, een vijver) telt helemaal in die buurt. Voor de
  oppervlakte precies binnen een gebied: `aggregate-features` met `clip`.
- Rond een punt (bijvoorbeeld 250 m om een adres): `aggregate-features` met
  `clip: {"point": [lon, lat], "distance": 250}`.

## Indeling van de objecten

| Collectie | Classificatie (BGT; fijner in IMGeo-plus) |
|---|---|
| wegdeel, ondersteunendwegdeel | bgtFunctie, bgtFysiekVoorkomen; plusFunctie, plusFysiekVoorkomen |
| spoor | bgtFunctie; plusFunctie |
| begroeidterreindeel, onbegroeidterreindeel | bgtFysiekVoorkomen; plusFysiekVoorkomen |
| waterdeel, ondersteunendwaterdeel, overigbouwwerk, kunstwerkdeel, scheiding, functioneelgebied | bgtType; plusType |
| overbruggingsdeel | typeOverbruggingsdeel, hoortBijTypeOverbrugging |
| openbareruimtelabel | openbareRuimteType, openbareRuimteNaam |
| inrichtingselementen (bak, bord, installatie, kast, mast, paal, put, sensor, straatmeubilair, waterinrichtingselement, weginrichtingselement, vegetatieobject), gebouwinstallatie, overigescheiding | plusType |
| pand | geen; identificatieBAGPND verwijst naar de BAG |

- Waarden worden precies zo opgegeven als in de referentiebestanden, met spaties en hoofdletters
  (`bgtFunctie=rijbaan lokale weg`). Een zoekbare eigenschap als parameter heeft één waarde; voor
  meer waarden een filter: `filter=bgtFunctie IN ('fietspad','voetpad')`.
- Een waarde met een dubbele punt verfijnt de waarde ervoor: `'recreatie: speeltuin'` is een soort
  `'recreatie'`. Alle soorten samen: `filter=plusType LIKE 'recreatie%'`.
- IMGeo-plus (plusFunctie, plusFysiekVoorkomen, plusType en alle inrichtingselementen) is
  optioneel: alleen gevuld waar de bronhouder het bijhoudt. Ontbreekt de waarde, dan staat er een
  reden: `waardeOnbekend` (de bronhouder kent de waarde niet) of `geenWaarde` (er is in
  werkelijkheid geen waarde).
- De waarde `transitie` komt voor bij bgtFunctie en bgtType, maar staat in geen waardelijst; er is
  geen definitie.
- Onduidelijk welke waarde bij een begrip hoort (is een grasveld 'grasland overig' of
  'groenvoorziening'?): lees het referentiebestand van de collectie.

## Oppervlakte, lengte en aandelen

- Op maaiveldniveau (relatieveHoogteligging 0) bedekken de vlakken het gebied zonder gaten en
  overlap; de som van de oppervlakten per soort is de verdeling van het gebied. Bruggen,
  overkappingen (1 en hoger) en tunnels (-1 en lager) tellen daar niet mee. Functionele gebieden
  (parken, speeltuinen) overlappen de vlakken en tellen ook niet mee.
- `oppervlakte` (m²) en `lengte` (m) staan standaard niet in de uitvoer van de collecties; in
  `aggregate-features` zijn `$area` en `$length` de oppervlakte en lengte van de geometrie (met
  `clip` van het deel binnen het gebied).
- `onbegroeidterreindeel` met bgtFysiekVoorkomen 'erf' is de grond bij een pand: tuinen,
  binnenplaatsen, opritten, niet verder ingedeeld. Een aandeel groen bevat dus geen tuinen; het
  werkelijke groen is groter, vooral in woonbuurten. Zeg dat bij elk aandeel groen of verharding.
- Panden hebben geen bgtFysiekVoorkomen; in een groepering op die eigenschap staan ze in de groep
  zonder die sleutel.

## Combineren met de andere API's

- **Adres → punt**: de BAG (`query_adres-op-postcode`) levert de geometrie van het verblijfsobject
  als lengte/breedtegraad; daarmee `wat-ligt-hier` (`punt`, eventueel `afstand` tot 100 m) of
  `aggregate-features` met `clip`.
- **Pand**: `identificatieBAGPND` is de identificatie van het pand in de BAG (bouwjaar, status,
  verblijfsobjecten in `/bag`). **Straat**: `identificatieBAGOPR` van een openbareruimtelabel is de
  openbare ruimte in de BAG.
- **Statistiek per gebied** (inwoners, woningen): niet in de BGT; de BAG telt verblijfsobjecten, de
  API Postcodegebieden heeft CBS-cijfers per postcode.

## Tijd en versies

- Zonder `datetime` levert de API wat nu in de registratie staat, dus alleen bestaande objecten.
  Met `datetime=2020-01-01T00:00:00Z` de toestand op dat moment.
- `wijzigingen-in-gebied`: een versie zonder link 'predecessor-version' is een nieuw object; een
  objectEindTijd is een beëindigd object. Een nieuwe versie kan een wijziging in de werkelijkheid of
  een correctie zijn; de BGT maakt dat onderscheid niet. Begin met een buurt of een korte periode.

## Resultaten klein houden

- `weglaten` in de zoekopdrachten: **een eigen lijst vervangt de standaardlijst**. Om de buurtcode
  erbij te krijgen: de standaardlijst zonder `buurtcode`; een lege lijst levert alles.
- Collecties: `properties` met alleen wat nodig is.
- Geen geometrie ophalen, tenzij voor een kaart of een afstand.
- Meer pagina's: is er `nextOffset`, dan dezelfde aanroep met `offset` = die waarde.

## Voorbeelden

**Hoe groen is buurt Hof in Amersfoort?**
1. `collection_buurt` met `gemeente=0307`, `naam=Hof`, `properties=["naam"]` → id `BU03070100`.
2. `aggregate-features` met `source: {"query": "topografie-in-gebied", "parameters": {"gebied":
   "BU03070100"}}`, `groupBy: ["$collection", "bgtFysiekVoorkomen"]`, `aggregates: ["count",
   {"function": "sum", "property": "$area"}]`.
3. Aandeel = som van begroeidterreindeel / totaal. Hof (november 2026): 557 m² groenvoorziening op
   76.325 m², maar 11.789 m² erf; zeg dat tuinen in erf zitten.

**Hoeveel bomen staan er per buurt in Amersfoort?**
`aggregate-features` met `source: {"query": "inrichtingselementen-in-gebied", "parameters":
{"gebied": "0307", "soort": ["boom"]}}`, `groupBy: ["buurtcode"]`. De gemeente houdt bomen maar
gedeeltelijk bij (november 2026: 1.687 voor heel Amersfoort, veel minder dan er staan): presenteer
het als "geregistreerd in de BGT", niet als het aantal bomen. Levert een soort voor de gemeente
niets of weinig op, dan zegt de BGT er niets over.

**Hoeveel m² fietspad heeft wijk Stadskern?**
`aggregate-features` met `source: {"collection": "wegdeel", "parameters": {"wijkcode": "WK030701",
"bgtFunctie": "fietspad"}}`, `aggregates: [{"function": "sum", "property": "$area"}]`.

**Wat ligt er bij Stadhuisplein 1, Amersfoort?**
`query_adres-op-postcode` (BAG, postcode 3811LM, huisnummer 1) → punt van het verblijfsobject →
`wat-ligt-hier` met dat punt en `afstand` 20 voor ook de straat en het groen ervoor.
