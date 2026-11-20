# BGT: de topografie

De BGT is de kaart van Nederland op het niveau van straten en panden, met historie. Welk gebied deze
server bevat, staat in de instructies van de server. Een vraag over een plaats daarbuiten: zeg dat
de gegevens daar ontbreken, niet dat er niets is.

De betekenis van de waarden per collectie: `bgt-waarden/waarden-<collectie>.md`, bijvoorbeeld
[bgt-waarden/waarden-wegdeel.md](bgt-waarden/waarden-wegdeel.md).

## Welke tool voor welke vraag

| Vraag | Tool |
|---|---|
| Hoeveel, hoeveel m², hoeveel meter, per soort of per gebied | `process_aggregate-features` (van de BGT-server) |
| Verdeling van een gebied: groen, verharding, water, bebouwing | `process_aggregate-features` met `clip` (zie SKILL.md), of `query_topografie-in-gebied` voor de objecten |
| Wegen, fietspaden, voetpaden, parkeervlakken, spoor in een gebied | `query_wegen-in-gebied` (functie, fysiekVoorkomen) |
| Bomen, banken, lichtmasten, putten, borden, speeltoestellen | `query_inrichtingselementen-in-gebied` (soort) |
| Parken, speeltuinen, sportterreinen, begraafplaatsen, overkappingen, straatnaamlabels | `query_overige-objecten-in-gebied` |
| Wat ligt er op of bij een adres of punt | `query_wat-ligt-hier` (punt uit de BAG) |
| Wat is er veranderd in een gebied, nieuw, gewijzigd, verdwenen | `query_wijzigingen-in-gebied` (sinds, tot) |
| Objecten van één collectie met een eigenschap of in een bbox | `collection_pand`, `collection_wegdeel`, `collection_begroeidterreindeel`, `collection_onbegroeidterreindeel`, `collection_waterdeel` |

De andere collecties hebben geen eigen tool; men bereikt ze via de zoekopdrachten en via
`process_aggregate-features` (`source.collection` met hun id, ook een lijst van ids).

## Gebieden en grootte

- De zoekopdrachten nemen één code in `gebied`; collecties en `source.parameters` filteren op
  `gemeentecode`, `wijkcode` of `buurtcode`. De buurtcode bevat de gemeente- en de wijkcode.
- Een object hoort bij het gebied waarin een punt op zijn geometrie ligt, dus bij precies één
  buurt. Voor oppervlakten in een gebied: `clip`, met `gemeentecode` in de bron (SKILL.md).
- Een gemeente van 150.000 inwoners heeft rond 250.000 vlakken (wegdeel en begroeidterreindeel elk
  rond 50.000, pand rond 90.000). `process_aggregate-features` leest hoogstens 100.000 objecten:
  over een hele gemeente één collectie per aanroep. Met `clip` telt de grens pas na het knippen.
- `query_topografie-in-gebied` voor een buurt levert honderden objecten (rond 450 bytes per object
  zonder geometrie, vooral links naar vorige versies); voor een wijk duizenden. Ophalen alleen voor
  een lijst of een kaart, niet om te tellen.

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

- Waarden precies zo opgeven als in de waardenbestanden, met spaties en hoofdletters
  (`bgtFunctie=rijbaan lokale weg`). Een zoekbare eigenschap als parameter heeft één waarde; meer
  met een filter: `filter=bgtFunctie IN ('fietspad','voetpad')`.
- Een waarde met een dubbele punt verfijnt de waarde ervoor: `'recreatie: speeltuin'` is een soort
  `'recreatie'`. Alle soorten samen: `filter=plusType LIKE 'recreatie%'`.
- De waarde `transitie` komt voor bij bgtFunctie en bgtType, maar staat in geen waardelijst; er is
  geen definitie.
- Onduidelijk welke waarde bij een begrip hoort (is een grasveld 'grasland overig' of
  'groenvoorziening'?): lees het waardenbestand van de collectie.

## IMGeo-plus en bronhouders

- IMGeo-plus (plusFunctie, plusFysiekVoorkomen, plusType en alle inrichtingselementen) is optioneel:
  alleen gevuld waar de bronhouder het bijhoudt. Ontbreekt de waarde, dan staat er een reden:
  `waardeOnbekend` of `geenWaarde`; sommige objecten (palen) hebben helemaal geen plusType.
- De bronhouder is niet altijd de gemeente: in een gemeente liggen ook objecten van buurgemeenten
  (G...), de provincie (P...), het waterschap (W...) en het Rijk (L...: Rijkswaterstaat, ProRail).
  De namen staan in de codelijst `/bgt/codelists/bronhouder`.
- Tellen van inrichtingselementen: groepeer eerst op `["plusType", "bronhouder"]`. Voorbeeld uit een
  proef in een gemeente: van 420 lichtmasten kwamen er 364 van de provincie (langs haar wegen) en 16
  van de gemeente; van 1.687 bomen 12 van de gemeente, de rest van provincie, waterschap en
  buurgemeenten. Een handvol banken of geen speeltoestellen voor een stad betekent dat de gemeente
  ze niet in de BGT bijhoudt, niet dat ze er niet zijn.
- Bij aandelen per fysiek voorkomen: `plusFysiekVoorkomen` 'waardeOnbekend' kan een vijfde van de
  wegoppervlakte zijn (de grote wegen van andere bronhouders); de BGT-waarde (`bgtFysiekVoorkomen`)
  is volledig.

## Oppervlakte, lengte en aandelen

- Op maaiveldniveau (relatieveHoogteligging 0) bedekken de vlakken het gebied zonder gaten en
  overlap; de som per soort is de verdeling van het gebied. Bruggen, overkappingen (1 en hoger) en
  tunnels (-1 en lager) tellen niet mee. Functionele gebieden (parken, speeltuinen) overlappen de
  vlakken en tellen ook niet mee.
- Groen voor een aandeel: `begroeidterreindeel` (alle soorten), eventueel per
  `bgtFysiekVoorkomen`. `onbegroeidterreindeel` met bgtFysiekVoorkomen 'erf' is de grond bij een
  pand: tuinen, binnenplaatsen, opritten. Een aandeel groen bevat dus geen tuinen; noem het aandeel
  erf erbij, vooral in woonbuurten.
- Het totaal voor een aandeel: de som van de vlakken op maaiveld met dezelfde `clip`, niet de
  oppervlakte uit een andere bron.
- `oppervlakte` (m²) en `lengte` (m) staan standaard niet in de uitvoer van de collecties; in
  `process_aggregate-features` zijn `$area` en `$length` de oppervlakte en lengte van de geometrie
  (met `clip` van het deel binnen het gebied).
- Panden hebben geen bgtFysiekVoorkomen; in een groepering op die eigenschap staan ze in de groep
  zonder die sleutel. BGT-pand en BAG-pand verschillen in oppervlakte hooguit een procent.

## Tijd en versies

- Zonder `datetime` levert de API wat nu in de registratie staat, dus alleen bestaande objecten.
  Met `datetime=2020-01-01T00:00:00Z` de toestand op dat moment.
- **De historie begint per bronhouder bij de eerste levering** (voor de meeste gemeenten eind 2016,
  toen de BGT compleet werd). Vergelijk niet met een datum daarvoor; een toename tussen twee datums
  kan ook fijnere inwinning zijn.
- `query_wijzigingen-in-gebied`: een versie zonder link 'predecessor-version' is een nieuw object;
  een objectEindTijd is een beëindigd object. Een object dat in de periode eindigde, komt met zijn
  laatste versie, ook als die van vóór de periode is. Een nieuwe versie kan een wijziging in de
  werkelijkheid of een correctie zijn; de BGT maakt dat onderscheid niet.
- **Hoeveel er veranderd is**: `process_aggregate-features` met `source: {"query":
  "wijzigingen-in-gebied", "parameters": {"gebied": ..., "sinds": ..., "tot": ...}}` en `aggregates:
  ["count"]`, gegroepeerd op `$collection`; het totaal is het aantal objecten dat in de periode nieuw,
  gewijzigd of beëindigd is (een object met meer versies in de periode telt één keer). Tel niet met collecties en een filter op `objectBeginTijd` of `tijdstipRegistratie`:
  dat mist de objecten die in de periode zijn beëindigd. Haal de versies niet op om te tellen.
- Bulkbewerkingen vinden: `process_aggregate-features` met de zoekopdracht als bron, `groupBy:
  ["$collection", {"property": "tijdstipRegistratie", "bucket": "month"}]`; een piek daarna per
  exact `tijdstipRegistratie` en `bronhouder`. Honderden objecten van één bronhouder met hetzelfde
  tijdstip zijn een administratieve invoer of herinwinning. `bucket` voor een tijdstip is `year`,
  `month` of een getal.
- Begin met een buurt of een korte periode: een gemeente over meer dan een jaar haalt de grens van
  100.000.

## Combineren met de andere API's

- **Adres → punt**: de BAG (`query_adres-op-postcode`) levert de geometrie van het verblijfsobject
  als lengte/breedtegraad; daarmee `query_wat-ligt-hier` (`punt`, eventueel `afstand` tot 100 m) of
  `process_aggregate-features` met `clip`.
- **Pand**: `identificatieBAGPND` is de identificatie van het pand in de BAG (bouwjaar, status,
  verblijfsobjecten). **Straat**: `identificatieBAGOPR` van een openbareruimtelabel is de openbare
  ruimte in de BAG.
- **Woningen of inwoners in een gebied**: niet in de BGT; de BAG telt verblijfsobjecten, de
  Postcodegebieden hebben CBS-cijfers.

## Resultaten klein houden

- `weglaten` in de zoekopdrachten: **een eigen lijst vervangt de standaardlijst**. Om de buurtcode
  erbij te krijgen: de standaardlijst zonder `buurtcode`; een lege lijst levert alles.
- Collecties: `properties` met alleen wat nodig is. Meer pagina's: `offset` = `nextOffset`.

## Voorbeelden

**Hoeveel procent van wijk Stadskern is groen?**
1. `collection_wijk` met `gemeente=0307`, `naam=Stadskern` → id `WK030701` en de geometrie.
2. `process_aggregate-features` met `source: {"collection": ["wegdeel", "ondersteunendwegdeel",
   "begroeidterreindeel", "onbegroeidterreindeel", "waterdeel", "ondersteunendwaterdeel", "pand",
   "overigbouwwerk", "kunstwerkdeel", "spoor"], "parameters": {"gemeentecode": "0307", "filter":
   "relatieveHoogteligging = 0"}}`, `clip: {"geometry": <geometrie van de wijk>}`, `groupBy:
   ["$collection", "bgtFysiekVoorkomen"]`, `aggregates: [{"function": "sum", "property": "$area"}]`
   (rond 4 seconden).
3. Aandeel = begroeidterreindeel / totaal; noem het aandeel erf erbij.

**Hoeveel bomen staan er per buurt in Amersfoort?**
`process_aggregate-features` met `source: {"query": "inrichtingselementen-in-gebied", "parameters":
{"gebied": "0307", "soort": ["boom"]}}`, `groupBy: ["bronhouder", "buurtcode"]`. Presenteer het als
"geregistreerd in de BGT", met wie ze bijhoudt.

**Hoeveel m² fietspad ligt er in wijk Stadskern?**
`process_aggregate-features` met `source: {"collection": "wegdeel", "parameters": {"gemeentecode":
"0307", "bgtFunctie": "fietspad"}}`, `clip` met de geometrie van de wijk, `aggregates`:
`[{"function": "sum", "property": "$area"}]`.

**Wat ligt er bij Stadhuisplein 1, Amersfoort?**
`query_adres-op-postcode` (BAG, postcode 3811LM, huisnummer 1) → punt van het verblijfsobject →
`query_wat-ligt-hier` met dat punt en `afstand` 20 voor ook de straat en het groen ervoor.
