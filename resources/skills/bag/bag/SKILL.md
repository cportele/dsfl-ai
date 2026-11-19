---
name: bag
description: >-
  Lees dit voor vragen over adressen en gebouwen in de BAG (Basisregistratie Adressen en Gebouwen):
  welke tool bij welke vraag, het model (adres, verblijfsobject, pand), tellen en optellen per
  gebied, statussen, bouwjaren, gebruiksdoelen, oppervlakten, historie, en de valkuilen die een
  antwoord veranderen. English: read before answering questions about Dutch addresses and buildings
  (BAG): choosing a tool, the data model, counting per area, status, construction year, use and
  floor area, history, pitfalls.
---

# De BAG bevragen

De BAG bevat alle adressen en gebouwen met hun historie. Welke woonplaatsen deze server bevat,
geeft `collection_woonplaats`. Wordt een adres niet gevonden, controleer dan eerst of de woonplaats
erin staat, en zeg anders dat de gegevens daar ontbreken, niet dat het adres niet bestaat.

Wat de BAG niet heeft: namen van bedrijven of voorzieningen, bewoners, eigenaren, prijzen,
energielabels. Zeg wat de BAG wel biedt (bijvoorbeeld verblijfsobjecten met sportfunctie als
kandidaten voor sporthallen).

## Het model

Een **adres** is een `nummeraanduiding` (postcode, huisnummer, huisletter, huisnummertoevoeging) die
`ligtAan` een `openbareruimte` (straat), die `ligtIn` een `woonplaats`. Adressen horen bij een
`verblijfsobject` (woning, winkel, kantoor; een punt), een `ligplaats` of een `standplaats`. Een
verblijfsobject `maaktDeelUitVan` een of meer **panden** (gebouwen; een vlak).

| Verwijzing | Omgekeerd zoeken |
|---|---|
| verblijfsobject.heeftAlsHoofdadres → nummeraanduiding | `collection_verblijfsobject` met `heeftAlsHoofdadres=<id>` |
| verblijfsobject.maaktDeelUitVan → pand | `collection_verblijfsobject` met `maaktDeelUitVan=<id>`, of `query_pand-met-inhoud` |
| nummeraanduiding.ligtAan → openbareruimte | `collection_nummeraanduiding` met `ligtAan=<id>` |

Identificaties hebben 16 cijfers; cijfer 5-6 geven het type (01 verblijfsobject, 10 pand,
20 nummeraanduiding, 30 openbare ruimte); een woonplaats heeft 4 cijfers. In een MCP-resultaat is
een verwijzing `{"id": ..., "title": ...}`; de titel van een adres is bijvoorbeeld
'Stadhuisplein 1, 3811LM Amersfoort'.

## Welke tool voor welke vraag

| Vraag | Tool |
|---|---|
| Hoeveel, hoeveel m², gemiddeld, per gebied, per bouwperiode, per gebruiksdoel | `process_aggregate-features` |
| Adres op postcode en huisnummer | `query_adres-op-postcode` |
| Adres op straat, huisnummer en woonplaats | `query_adres-op-straat` |
| Het pand bij een adres, met bouwjaar en de BGT op die plek | `process_pand-bij-adres` |
| Wat zit er in een pand (ook een gesloopt pand) | `query_pand-met-inhoud` |
| Panden in een gebied op bouwjaar, status, sloopdatum, grondoppervlakte | `query_panden-in-gebied` |
| Verblijfsobjecten in een gebied op gebruiksdoel, status, oppervlakte; de grootste eerst | `query_verblijfsobjecten-in-gebied` |
| Verblijfsobjecten in panden met een status of bouwjaar (woningen in aanbouw, gesloopte woningen, scholen in oude panden) | `query_verblijfsobjecten-in-panden` |
| Wat ligt het dichtst bij een punt, met afstand | `process_nearest-features` |
| Verblijfsobjecten met een gebruiksdoel binnen een afstand | `query_verblijfsobjecten-in-de-buurt` |
| De toestand op een datum, andere eigenschappen | `collection_<type>` met `datetime`, eigenschappen of `filter` |

Welke objecttypen een zoekopdracht levert en wat hun eigenschappen betekenen:
`references/eigenschappen.md` (met de tool `skill_bag` en het argument `file`). Lees het voor de
eerste aanroep van een zoekopdracht.

Om te tellen nooit alle objecten ophalen: `process_aggregate-features` geeft het getal direct, ook
met kenmerken van het pand bij het verblijfsobject (`statusPand`, `bouwjaarPand`), zodat vragen over
woningen in oude of gesloopte panden één aanroep op `verblijfsobject` zijn. Er worden per aanroep
hoogstens 100.000 objecten gelezen; beperk de selectie anders tot een gemeente of wijk.

## Gebieden

- Een gebied is een CBS-code: gemeente `0307`, wijk `WK030701`, buurt `BU03070100`. Zoekopdrachten
  nemen één code in `gebied`; panden, verblijfsobjecten, ligplaatsen en standplaatsen filteren op
  `gemeentecode`, `wijkcode` of `buurtcode`.
- De code bij een naam staat in de API Wijken en buurten (`collection_wijk`, `collection_buurt` met
  `gemeente=<gemeentecode>` en `naam`). De code is de id van het object. Namen zijn alleen binnen een
  gemeente uniek.
- Per gebied groeperen: `groupBy: ["wijkcode", "wijknaam"]` (of buurtcode en buurtnaam samen). Een
  stadsdeel of nieuwbouwwijk kan uit meer CBS-wijken bestaan met hetzelfde begin van de naam.
- Gebiedscodes en -namen, `grondoppervlakte`, `aantalVerblijfsobjecten`, `bouwjaarPand`,
  `statusPand` en `objecttype` staan standaard niet in de uitvoer: collecties met `properties`,
  zoekopdrachten met `weglaten` zonder die eigenschap.

## Wat een antwoord verandert

- **Status**: de zoekopdrachten leveren standaard alleen bestaande objecten in gebruik; de
  collecties leveren alle statussen, ook gesloopt en ingetrokken: geef daar een status op. Als
  parameter één waarde; meer met een filter, bijvoorbeeld
  `filter=status IN ('Pand in gebruik','Pand in gebruik (niet ingemeten)')`.
  Pand: Bouwvergunning verleend, Bouw gestart, Pand in gebruik (niet ingemeten), Pand in gebruik,
  Verbouwing pand, Sloopvergunning verleend, Pand gesloopt, Pand buiten gebruik, Niet gerealiseerd
  pand, Pand ten onrechte opgevoerd. Verblijfsobject: Verblijfsobject gevormd (in aanbouw),
  Verblijfsobject in gebruik (niet ingemeten), Verblijfsobject in gebruik, Verbouwing
  verblijfsobject, Verblijfsobject buiten gebruik, Verblijfsobject ingetrokken, Niet gerealiseerd
  verblijfsobject, Verblijfsobject ten onrechte opgevoerd.
- **Bouwjaar** `oorspronkelijkBouwjaar`: 9999 is onbekend (uitsluiten met `bouwjaarTot` 9998 of een
  filter). Oude panden hebben vaak een geschat rond jaar (1600, 1700, 1800); aantallen per jaar
  vóór ongeveer 1900 zijn grof. `bouwjaarPand` bij een verblijfsobject is het oudste bouwjaar van
  zijn panden.
- **Oppervlakte** van een verblijfsobject is de gebruiksoppervlakte; 999999 is geen werkelijke
  oppervlakte. `grondoppervlakte` van een pand is berekend uit de geometrie; `grondoppervlakteMin`
  50 sluit schuren en garages uit.
- **Gebruiksdoel** is de vergunde gebruiksfunctie (Bouwbesluit 2012), een lijst: woonfunctie,
  bijeenkomstfunctie, celfunctie, gezondheidszorgfunctie, industriefunctie, kantoorfunctie,
  logiesfunctie, onderwijsfunctie, sportfunctie, winkelfunctie, overige gebruiksfunctie. Geen
  soort voorziening: sportfunctie omvat sporthallen, sportscholen en kantines. Een verblijfsobject
  met meer gebruiksdoelen telt in een groepering in elke groep mee, in het totaal één keer.
- **Wat geteld is**: panden, verblijfsobjecten of oppervlakte geven verschillende beelden (een
  flatgebouw is één pand met veel woningen; de meeste gesloopte panden zijn schuren). Zeg wat er
  geteld is.
- **Data**: `beginGeldigheid` is het begin van de huidige versie; bij een gesloopt pand de datum
  van de registratie van de sloop, soms later dan de sloop. `sinds` en `tot` filteren daarop. Een
  'Bouwvergunning verleend' kan jaren oud zijn als er nooit gebouwd is: combineer met `sinds`.
- **Ingetrokken adressen**: een titel die eindigt op '(ingetrokken)' verwijst naar een ingetrokken
  adres, straat of woonplaats. Adreszoekopdrachten leveren alleen uitgegeven adressen, tenzij
  `status` ook 'Naamgeving ingetrokken' bevat.
- **Gemengde resultaten** (adreszoekopdrachten, pand-met-inhoud, verblijfsobjecten-in-panden):
  splits op `objecttype`, niet op de volgorde.
- **Historie**: zonder `datetime` de versie van vandaag; met `datetime=2015-01-01` (collecties) de
  versie die toen gold.

## Combineren met de andere API's

- **BGT** (`/bgt`): de topografie rond een adres (`process_pand-bij-adres` levert de BGT-objecten op
  de plek; de BGT-zoekopdracht `wat-ligt-hier` met het punt van het verblijfsobject). Een BGT-pand
  verwijst met `identificatieBAGPND` naar het pand in de BAG.
- **Postcodegebieden** (`/postcode6`): CBS-cijfers per postcode; de postcode van een
  nummeraanduiding verwijst ernaar.
- **DSO** (`/dso`): de regels van de Omgevingswet op een adres (postcode en huisnummer). Een punt
  in het Rijksdriehoeksstelsel (voor de DSO-werkstromen op een peildatum): het argument `crs` =
  `http://www.opengis.net/def/crs/EPSG/0/28992` bij de collecties en zoekopdrachten.

## Resultaten klein houden

- Collecties: `properties` met alleen wat nodig is; de id komt altijd mee.
- Zoekopdrachten: **een eigen lijst in `weglaten` vervangt de standaardlijst**; neem de
  standaardwaarden op die weg moeten blijven. Een lege lijst levert alles.
- Geen geometrie ophalen, tenzij voor een kaart of een afstand. `limit` is hoogstens 5000; meer
  pagina's met `offset` = `nextOffset`.

## Voorbeelden

**Hoeveel woningen heeft elke wijk van Amersfoort?**
`process_aggregate-features` met `source: {"collection": "verblijfsobject", "parameters":
{"gemeentecode": "0307", "gebruiksdoel": "woonfunctie", "filter": "status IN ('Verblijfsobject in
gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing verblijfsobject')"}}`,
`groupBy: ["wijkcode", "wijknaam"]`. November 2026: 73.065 woningen, de meeste in Soesterkwartier
(5.971). Zeg dat verblijfsobjecten met woonfunctie geteld zijn, inclusief gemengde functies.

**Hoeveel woningen staan er per bouwperiode in wijk Stadskern?**
Dezelfde bron met `wijkcode: "WK030701"`, `groupBy: [{"property": "bouwjaarPand", "bucket": 50}]`,
`aggregates: ["count", {"function": "avg", "property": "oppervlakte"}]`.

**Welke panden zijn sinds 2020 gesloopt in buurt Hof, en wat zat erin?**
`query_panden-in-gebied` met `gebied: "BU03070100"`, `status: ["Pand gesloopt"]`, `sinds:
"2020-01-01"`; per pand `query_pand-met-inhoud` voor de ingetrokken verblijfsobjecten.

**Wat is de dichtstbijzijnde winkel bij Stadhuisplein 1?**
`query_adres-op-postcode` (3811LM, 1) → punt van het verblijfsobject → `process_nearest-features`
met `source: {"collection": "verblijfsobject", "parameters": {"gebruiksdoel": "winkelfunctie",
"status": "Verblijfsobject in gebruik", "properties": "heeftAlsHoofdadres,gebruiksdoel,oppervlakte"}}`,
`point`, `distance: 500`. Zonder status komen ook ingetrokken winkels mee.
