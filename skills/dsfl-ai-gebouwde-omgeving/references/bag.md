# BAG: adressen en gebouwen

De BAG bevat alle adressen en gebouwen met hun historie. Welke woonplaatsen deze server bevat,
geeft `collection_woonplaats`. Wordt een adres niet gevonden, controleer dan eerst of de woonplaats
erin staat, en zeg anders dat de gegevens daar ontbreken, niet dat het adres niet bestaat.

## Het model

Een **adres** is een `nummeraanduiding` (postcode, huisnummer, huisletter, huisnummertoevoeging) die
`ligtAan` een `openbareruimte` (straat), die `ligtIn` een `woonplaats`. Adressen horen bij een
`verblijfsobject` (woning, winkel, kantoor; een punt), een `ligplaats` (woonboot) of een
`standplaats` (woonwagen). Een verblijfsobject `maaktDeelUitVan` een of meer **panden** (gebouwen;
een vlak).

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
| Hoeveel, hoeveel m², gemiddeld, per gebied, per bouwperiode, per gebruiksdoel, op een datum | `process_aggregate-features` |
| Adres op postcode en huisnummer | `query_adres-op-postcode` |
| Adres op straat, huisnummer en woonplaats | `query_adres-op-straat` |
| Het pand bij een adres, met bouwjaar en de BGT op die plek | `process_pand-bij-adres` |
| Wat zit er in een pand | `query_pand-met-inhoud` |
| Panden in een gebied op bouwjaar, status, sloopdatum, grondoppervlakte | `query_panden-in-gebied` |
| Verblijfsobjecten in een gebied op gebruiksdoel, status, oppervlakte; de grootste eerst | `query_verblijfsobjecten-in-gebied` |
| Verblijfsobjecten in panden met een status of bouwjaar (woningen in aanbouw, scholen in oude panden) | `query_verblijfsobjecten-in-panden` |
| Wat ligt het dichtst bij een punt, met afstand | `process_nearest-features` |
| Verblijfsobjecten met een gebruiksdoel binnen een afstand | `query_verblijfsobjecten-in-de-buurt` |
| De toestand op een datum, andere eigenschappen | `collection_<type>` met `datetime`, eigenschappen of `filter` |

Welke objecttypen een zoekopdracht levert en wat hun eigenschappen betekenen:
[bag-eigenschappen.md](bag-eigenschappen.md).

Om te tellen nooit alle objecten ophalen: `process_aggregate-features` geeft het getal direct, ook
met kenmerken van het pand bij het verblijfsobject (`statusPand`, `bouwjaarPand`), zodat vragen over
woningen in oude of gesloopte panden één aanroep op `verblijfsobject` zijn. Een gemeentebrede
telling over alle verblijfsobjecten duurt tot een minuut; per wijk enkele seconden.

## Adressen vinden

- `query_adres-op-straat` vraagt de volledige officiële straatnaam (Burgemeester, niet Burg.;
  Stadhuisplein, niet Stadhuispl.) en de **woonplaats**, niet de gemeente: een gemeente heeft vaak
  meer woonplaatsen. Geen resultaat: zoek de spelling met `collection_openbareruimte` en `naam` met
  `*` (`*Smittweg`) en lees de woonplaats uit `ligtIn`, of vraag de postcode.
- Een titel die eindigt op '(ingetrokken)' verwijst naar een ingetrokken adres, straat of
  woonplaats. Adreszoekopdrachten leveren alleen uitgegeven adressen, tenzij `status` ook
  'Naamgeving ingetrokken' bevat. Is het gevraagde adres ingetrokken, zeg dat; de huidige adressen
  ernaast zijn geen vervanging, noem ze als zodanig.
- Een verblijfsobject kan ingetrokken nevenadressen houden waarvan de nummers nu hoofdadres van
  andere verblijfsobjecten zijn; tel die niet als extra woningen of adressen.

## Gebieden

- Zoekopdrachten nemen één code in `gebied`; panden, verblijfsobjecten, ligplaatsen en standplaatsen
  filteren op `gemeentecode`, `wijkcode` of `buurtcode`. Meer codes: `filter: "wijkcode IN
  ('WK030701','WK030702')"`.
- Per gebied groeperen: `groupBy: ["wijkcode", "wijknaam"]` (of buurtcode en buurtnaam samen).
- Gebiedscodes en -namen, `grondoppervlakte`, `aantalVerblijfsobjecten`, `bouwjaarPand`,
  `statusPand` en `objecttype` staan standaard niet in de uitvoer: collecties met `properties`,
  zoekopdrachten met `weglaten` zonder die eigenschap.

## Wat een antwoord verandert

- **Status**: de zoekopdrachten leveren standaard alleen bestaande objecten in gebruik; de
  collecties en `process_aggregate-features` leveren alle statussen, ook gesloopt, ingetrokken en in
  aanbouw: geef daar een status op. Als parameter één waarde; meer met een filter.
  Pand: Bouwvergunning verleend, Bouw gestart, Pand in gebruik (niet ingemeten), Pand in gebruik,
  Verbouwing pand, Sloopvergunning verleend, Pand gesloopt, Pand buiten gebruik, Niet gerealiseerd
  pand, Pand ten onrechte opgevoerd. Verblijfsobject: Verblijfsobject gevormd (in aanbouw),
  Verblijfsobject in gebruik (niet ingemeten), Verblijfsobject in gebruik, Verbouwing
  verblijfsobject, Verblijfsobject buiten gebruik, Verblijfsobject ingetrokken, Niet gerealiseerd
  verblijfsobject, Verblijfsobject ten onrechte opgevoerd.
- **Bouwjaar** `oorspronkelijkBouwjaar`: 9999 is onbekend (uitsluiten met `bouwjaarTot` 9998 of een
  filter). Oude panden hebben vaak een geschat rond jaar (1600, 1700, 1800); aantallen per jaar vóór
  ongeveer 1900 zijn grof. `bouwjaarPand` bij een verblijfsobject is het oudste bouwjaar van zijn
  panden. Woningen "gebouwd sinds" een jaar missen woningen die later in een ouder pand zijn gemaakt;
  voor "erbij gekomen" zie SKILL.md, "Veranderingen".
- **Oppervlakte** van een verblijfsobject is de gebruiksoppervlakte; 999999 is geen werkelijke
  oppervlakte. `grondoppervlakte` van een pand is berekend uit de geometrie; `grondoppervlakteMin`
  50 sluit schuren en garages uit.
- **Gebruiksdoel** is de vergunde gebruiksfunctie (Bouwbesluit 2012), een lijst: woonfunctie,
  bijeenkomstfunctie, celfunctie, gezondheidszorgfunctie, industriefunctie, kantoorfunctie,
  logiesfunctie, onderwijsfunctie, sportfunctie, winkelfunctie, overige gebruiksfunctie. Geen soort
  voorziening: sportfunctie omvat sporthallen, sportscholen en kantines. Een verblijfsobject met meer
  gebruiksdoelen telt in een groepering in elke groep mee, in het totaal één keer.
- **Wat geteld is**: panden, verblijfsobjecten of oppervlakte geven verschillende beelden (een
  flatgebouw is één pand met veel woningen; de meeste gesloopte panden zijn schuren). Woonboten en
  woonwagens hebben geen gebruiksdoel: `process_aggregate-features` op `ligplaats` en `standplaats`
  (met status 'Plaats aangewezen') telt ze apart.
- **Data**: `beginGeldigheid` is het begin van de huidige versie; bij een gesloopt pand de datum van
  de registratie van de sloop, soms later dan de sloop. `sinds` en `tot` filteren daarop. Een
  'Bouwvergunning verleend' kan jaren oud zijn als er nooit gebouwd is: combineer met `sinds`.
- **Gemengde resultaten** (adreszoekopdrachten, pand-met-inhoud, verblijfsobjecten-in-panden):
  splits op `objecttype`, niet op de volgorde.

## Historie

- Zonder `datetime` de versie van vandaag; met `datetime: "2015-01-01"` (collecties,
  `source.parameters` van `process_aggregate-features`) de versie die toen gold, ook van objecten
  die nu gesloopt of ingetrokken zijn. De zoekopdrachten kennen geen `datetime`.
- De toestand vlak vóór een wijziging (de status vóór een sloop, de verblijfsobjecten van toen):
  `collection_<type>` met `ids` of `maaktDeelUitVan` en `datetime` = de dag vóór `beginGeldigheid`.

## Sloop controleren

'Pand gesloopt' beëindigt ook een samenvoeging met een buurpand (dat op dezelfde datum groter wordt
en de verblijfsobjecten met hun adressen overneemt) en een pand dat nooit is gebouwd. Per pand,
alleen voor de grotere (`grondoppervlakte` ≥ 50 m²) en alleen als de vraag het nodig maakt (het
kost enkele aanroepen per pand):

1. De status de dag vóór `beginGeldigheid`: `collection_pand` met `ids` en `datetime`. Was dat
   'Bouwvergunning verleend', dan is het pand nooit gebouwd.
2. De verblijfsobjecten van die dag: `collection_verblijfsobject` met `maaktDeelUitVan` en
   `datetime`. Zijn ze nu (`ids`, zonder `datetime`) in gebruik in een ander pand, dan is het een
   samenvoeging; zijn ze 'Verblijfsobject ingetrokken', dan een echte sloop.
3. `query_pand-met-inhoud` levert bij een samengevoegd pand alleen het pand, zonder
   verblijfsobjecten: dat is het teken, geen leeg pand.

Noem het resultaat per soort (echt gesloopt, samengevoegd, nooit gebouwd).

## Kenmerken in onderzoek

Hangt een antwoord af van één waarde van één object, of lijkt een waarde onwaarschijnlijk:
`process_aggregate-features` met `source: {"collection": "kenmerkinonderzoek", "parameters":
{"datetime": "now", "filter": "object IN ('<id>') AND inOnderzoek = true"}}`, `groupBy:
["kenmerk"]`; geen groepen = niets in onderzoek. Eén object per aanroep; niet standaard bij elke
vraag.

## Combineren met de andere API's

- **BGT**: de topografie rond een adres (`process_pand-bij-adres` levert de BGT-objecten op de plek;
  de BGT-zoekopdracht `query_wat-ligt-hier` met het punt van het verblijfsobject). Een BGT-pand
  verwijst met `identificatieBAGPND` naar het pand in de BAG.
- **Wijken en buurten** levert alleen namen, codes en grenzen, geen inwoners of andere CBS-cijfers;
  aantallen uit de BAG zijn tellingen van objecten, geen CBS-statistiek.
- **Postcodegebieden**: CBS-cijfers per postcode; de postcode van een nummeraanduiding verwijst
  ernaar.
- **DSO**: de regels op een adres (postcode en huisnummer). Een punt in het Rijksdriehoeksstelsel
  (voor de DSO-werkstromen op een peildatum): het argument `crs` =
  `http://www.opengis.net/def/crs/EPSG/0/28992` bij de collecties en zoekopdrachten.

## Resultaten klein houden

- Collecties: `properties` met alleen wat nodig is; de id komt altijd mee.
- Zoekopdrachten: **een eigen lijst in `weglaten` vervangt de standaardlijst**; neem de
  standaardwaarden op die weg moeten blijven. Een lege lijst levert alles.
- `limit` is hoogstens 5000; meer pagina's met `offset` = `nextOffset`. Een grote uitvoer past niet
  in het antwoord (de tool meldt dan een fout met de link naar het resultaat); om te tellen
  `process_aggregate-features`.
- Veel namen tegelijk (alle buurten met hun wijk): één aanroep `collection_buurt` met
  `gemeente=<code>`, `properties: ["naam", "wijk"]`, `limit` 500.

## Voorbeelden

**Hoeveel woningen heeft elke wijk van Amersfoort?**
`process_aggregate-features` met `source: {"collection": "verblijfsobject", "parameters":
{"gemeentecode": "0307", "gebruiksdoel": "woonfunctie", "filter": "status IN ('Verblijfsobject in
gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing verblijfsobject')"}}`,
`groupBy: ["wijkcode", "wijknaam"]`. Zeg dat verblijfsobjecten met woonfunctie geteld zijn,
inclusief gemengde functies, met deze statussen.

**Hoeveel woningen staan er per bouwperiode in wijk Stadskern?**
Dezelfde bron met `wijkcode: "WK030701"`, `groupBy: [{"property": "bouwjaarPand", "bucket": 50}]`,
`aggregates: ["count", {"function": "avg", "property": "oppervlakte"}]`.

**Welke panden zijn sinds 2020 als gesloopt geregistreerd in buurt Hof?**
`query_panden-in-gebied` met `gebied: "BU03070100"`, `status: ["Pand gesloopt"]`, `sinds:
"2020-01-01"`, `weglaten` zonder `grondoppervlakte`. Splits op grootte; voor de grote panden
"Sloop controleren".

**Wat is de dichtstbijzijnde winkel bij Stadhuisplein 1?**
`query_adres-op-postcode` (3811LM, 1) → punt van het verblijfsobject → `process_nearest-features`
met `source: {"collection": "verblijfsobject", "parameters": {"gebruiksdoel": "winkelfunctie",
"status": "Verblijfsobject in gebruik", "properties": "heeftAlsHoofdadres,gebruiksdoel,oppervlakte"}}`,
`point`, `distance: 500`. Zonder status komen ook ingetrokken winkels mee.
