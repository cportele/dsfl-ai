---
name: dsfl-ai-extended
description: >-
  Uitgebreide skill voor de MCP-servers voor Nederlandse ruimtelijke data: BAG, BGT, Wijken en buurten,
  Postcodegebieden, DSO (Omgevingswet), subsurface-models (REGIS II, GeoTOP), groundwater-monitoring
  (BRO GMW, GLD, GMN) en virtual-groundwater-heads. Gebruik vóór de eerste aanroep bij vragen over
  adressen, gebouwen, woningen, wegen, groen, water, bomen, buurten, CBS-cijfers per postcode, wat mag of
  vergunningplichtig is op een adres, en bodem, ondergrond, klei of veen, peilbuizen en grondwaterstanden
  voor een gebied of pand, ook gecombineerd. Bevat per server het model, de toolkeuze, de valkuilen en
  voorbeelden, volgens één vaste opzet. English: extended skill for Dutch geodata MCP servers.
---

# Ruimtelijke vragen oplossen met de dsfl-ai MCP-servers (uitgebreid)

De instructies van elke server beschrijven het model, de parameters en de valkuilen per API; lees die.
Deze skill vult ze aan: hoe je met de servers samen een vraag beantwoordt, en wat in proeven met echte
vragen tot verkeerde antwoorden leidde. Alle domeinen volgen dezelfde opzet: **bereik, model, welke tool
voor welke vraag, valkuilen, voorbeelden**. Houd Nederlandse datawaarden (statussen, veldnamen, codes)
letterlijk; antwoord in de taal van de gebruiker.

## Inhoud

1. Servers en kernafspraken
2. Algemene werkwijze
3. Gedeelde technieken: gebied → code, `clip`, veranderingen, grootte, fouten
4. BAG
5. BGT
6. CBS: Wijken en buurten, Postcodegebieden
7. DSO (Omgevingswet)
8. Ondergrond: subsurface-models
9. Grondwater: groundwater-monitoring
10. Virtuele grondwaterstanden: virtual-groundwater-heads
11. Bodem + grondwater gecombineerd
12. Het antwoord

---

## 1. Servers en kernafspraken

| Server | Inhoud |
|---|---|
| BAG | adressen, panden, verblijfsobjecten (woningen, winkels, ...), lig- en standplaatsen, met historie |
| BGT | de kaart op het niveau van straten en panden: wegen, groen, water, panden, inrichtingselementen, met historie |
| Wijken en buurten | namen, codes en grenzen van gemeenten, wijken en buurten (CBS 2026), **geen cijfers** |
| Postcodegebieden | CBS-cijfers per postcode (PC6) op 1 januari 2024: inwoners, huishoudens, woningen |
| DSO | werkstromen over de regels van de Omgevingswet op een adres, live uit het DSO |
| subsurface-models | REGIS II (lagen) en GeoTOP (voxels): kolom, doorsnede, aandeel lithoklasse |
| groundwater-monitoring | BRO GMW (putten), GLD (standreeksen), GMN (meetnetten); dagstanden, kwaliteitsbeoordeling |
| virtual-groundwater-heads | afgeleide standen: buisselectie, KNMI-stresses, TFN-modellen, virtuele standenreeks |

- **Dezelfde toolnaam op meer servers**: `process_aggregate-features` (BAG, BGT, Postcodegebieden) en
  `collection_pand` (BAG en BGT). Kies de server waarvan je de gegevens bedoelt; een BAG-collectie in de
  BGT-tool geeft een fout.
- Elke server bevat een uittreksel; de instructies zeggen welk. Ligt een vraag erbuiten, zeg dan dat de
  gegevens daar ontbreken, niet dat er niets is of dat een adres niet bestaat.
- Ondergrond- en grondwaterservers: toolnamen beginnen met de servernaam (`subsurface-models.trace`).
  Geometrie is GeoJSON, WGS84, `[lengtegraad, breedtegraad]`; standen zijn in m NAP; resultaten zijn
  bewijs met methode, versie en invoer, nooit een oordeel; een begrensd resultaat heeft een `window`
  (`total`, `returned`, `truncated`) en wordt gepagineerd, niet als volledig vertrouwd.

## 2. Algemene werkwijze

Doe de goedkope registerstappen eerst, zodat de dure ondergrond- en grondwaterstappen op zo min mogelijk
eenheden draaien.

| # | Stap | Wat je doet | Tools |
|---|---|---|---|
| 0 | **Definities vastleggen** | Schrijf elke drempel en term uit de vraag op (status, periode, kanskap, diepte, afstand, jaren, gatlengte, aangenomen stand). Het zijn parameters die je doorgeeft, nooit standaardwaarden van de server. Zoek onduidelijke ondergrondtermen en lithoklassecodes (klei, veen, zandige klei) op in de modelcatalogus; raad geen codes. Onduidelijk of inconsistent (wijk of buurt? 5 % of 10 %?): bevestig met de gebruiker. | `subsurface-models.model.search`, `.model.describe`, `.concepts.lookup` |
| 1 | **Eenheden en geometrie** | Gebied → code (§3.1); haal buurt- of pandgeometrie en attributen (bouwjaar, verhard oppervlak, maaiveld) uit de registers; zet om naar GeoJSON WGS84. | BAG, BGT, Wijken en buurten; AHN buiten deze servers |
| 2 | **Filteren en rangschikken** | Pas criteria zonder ondergrond toe en houd alleen de benodigde eenheden over (top N, vóór een jaar). Noem het aantal ervoor en erna. | BAG, BGT, CBS |
| 3 | **Ondergrond karakteriseren** | Gebiedsvraag: één aanroep per eenheid. Punt- of objectvraag: één kolom per eenheid. Laterale continuïteit: een doorsnede. Geef het dieptebereik en de drempels uit stap 0 door. | `subsurface-models.area-summary`, `.trace`, `.layers`, `.section`, `.band-confinement` |
| 4 | **Grondwaterbron bepalen** (alleen als standen gevraagd zijn) | Zoek buizen binnen de genoemde afstand, beoordeel elke op doel en diepte, controleer de datadekking tegen de genoemde regel. Gemeten als een buis voldoet, anders gemodelleerd; leg vast welke en waarom. | `groundwater-monitoring.tubes.search`, `.wells.get`, `virtual-groundwater-heads.tubes.select`, `.tubes.subsurface`, `groundwater-monitoring.series.assess` |
| 5 | **Standenreeks ophalen** | Gemeten: dagreeks per buis, per periode gepagineerd. Gemodelleerd: virtuele standschatting, gelabeld als proof of concept. | `groundwater-monitoring.series.daily` (of `.series.get`), `virtual-groundwater-heads.series.tfn`, `.estimate.series` |
| 6 | **Indicatoren afleiden** | Bereken wat gevraagd is uit de reeks en de genoemde stand (duur, langste reeks, aantal reeksen, maximale diepte, getroffen jaren); een gat langer dan de genoemde lengte is een onderbreking. Geen servertool doet dit nu. | aan de agentkant |
| 7 | **Combineren en scoren** | Alleen met een formule uit de vraag of met de gebruiker afgesproken; anders de componenten naast elkaar tonen. | geen |
| 8 | **Presenteren** | §12. Plots en kaart als gevraagd. | `subsurface-models.trace-plot`, `.section-plot`, `groundwater-monitoring.series.plot`, `virtual-groundwater-heads.estimate.plot` |

Voorgestelde reeksen: *gebieden rangschikken op een ondergrondaandeel* = 0 → 1 → 2 → 3 (`area-summary` per
eenheid, pagineren) → 7 → 8. *Objecten toetsen aan een grondwaterstand* = 0 → 1 → 2 → 3 (`trace` met
dieptebereik per object) → 4 → 5 → 6 → 8. *Mag dit op dit adres* = BAG-adrescontrole → DSO-werkstroom.

## 3. Gedeelde technieken

### 3.1 Gebied → code

Alle servers filteren op CBS-codes: gemeente `0307`, wijk `WK030701`, buurt `BU03070100`. Zoek de code met
`collection_wijk` of `collection_buurt` (Wijken en buurten) met `gemeente` en `naam`. Namen zijn
hoofdlettergevoelig en alleen binnen een gemeente uniek; geen treffer → `naam` met `*` (`*Hof*`) of
`filter: "CASEI(naam) = CASEI('hof')"`. Een stadsdeel of nieuwbouwwijk bestaat vaak uit meer CBS-wijken:
zoek `*Naam*`, noem alle treffers en tel samen wat erbij hoort (een bedrijventerrein met dezelfde naam is
meestal geen woonwijk; een voorvoegsel kan ook een ander dorp raken: Hoogland* vindt ook Hooglanderveen).

### 3.2 Tellen, optellen, verdelen

`process_aggregate-features` van de server met de gegevens, nooit de objecten ophalen. Een aanroep leest
hoogstens 100.000 objecten; anders per collectie of per wijk splitsen. Een aanroep duurt 1 tot 5
seconden, een gemeentebrede telling in de BAG tot een minuut. Per gebied groeperen: `groupBy:
["wijkcode","wijknaam"]` (of buurtcode en buurtnaam samen).

### 3.3 Resultaten klein houden

- Collecties: `properties` met alleen wat nodig is; de id komt altijd mee. Geen geometrie tenzij voor een
  kaart, een afstand of `clip`.
- Zoekopdrachten: **een eigen lijst in `weglaten` vervangt de standaardlijst**; neem de standaardwaarden
  op die weg moeten blijven. Een lege lijst levert alles.
- `limit` is hoogstens 5000; meer pagina's met `offset` = `nextOffset`.
- Is een resultaat te groot, dan meldt de tool een fout met de link naar het volledige resultaat: geef de
  link door (voor een kaart of een download), niet de gegevens.
- Veel namen tegelijk (alle buurten met hun wijk): één aanroep `collection_buurt` met `gemeente=<code>`,
  `properties: ["naam","wijk"]`, `limit` 500.

### 3.4 Het getal past bij de definitie die je noemt

Kies statussen en filters bewust en noem ze (zie BAG §4.4). Een deelvraag gebruikt hetzelfde filter.

### 3.5 Veranderingen: vergelijk twee toestanden

"Hoeveel woningen zijn erbij gekomen sinds 2015?" is de toestand nu min de toestand op 1 januari 2015:
twee aanroepen met hetzelfde gebied en dezelfde definitie, één met `"datetime": "2015-01-01"` in
`source.parameters`. Tellen op `bouwjaarPand` ≥ 2015 is geen antwoord daarop: het mist woningen die in
oudere panden zijn gemaakt (kantoren en winkels omgebouwd, woningen gesplitst) en negeert wat verdween. In
oude stadsdelen is dat het grootste deel; het verschil kan een factor vier zijn. Geef het netto verschil en
noem het aantal in nieuwbouw hoogstens als deel daarvan. De zoekopdrachten (`query_*`) kennen geen
`datetime`; de collecties en `process_aggregate-features` wel. BGT: begin van de historie en
bulkbewerkingen, zie §5.7.

### 3.6 Een geregistreerde gebeurtenis is niet altijd wat er gebeurd is

- **'Pand gesloopt'** markeert ook een pand dat is samengevoegd met een buurpand en een pand dat nooit is
  gebouwd. Van de grotere panden (`grondoppervlakte` ≥ 50 m²) is in een binnenstad soms maar één op de
  acht echt gesloopt; de kleine zijn meestal schuren. Geef het aantal "als gesloopt geregistreerd", splits
  op grootte, en controleer de grote panden of bied die controle aan (werkwijze: §4.7).
- `beginGeldigheid` is de datum van de registratie, soms jaren na de gebeurtenis.
- **BGT**: veel versies van één bronhouder met hetzelfde `tijdstipRegistratie` zijn een bulkbewerking
  (correctie, herinwinning), geen verandering op straat.

### 3.7 Oppervlakte in een gebied: `clip`

Een object hoort bij het gebied waarin een punt op zijn geometrie ligt. Een vijver of weg langs de grens
telt dan helemaal in de ene buurt en niet in de andere; voor water en grote wegen kan dat tientallen
procenten schelen. Voor elke oppervlakte of elk aandeel van een buurt of wijk, en rond een punt:

1. de grens: `collection_buurt` (of `collection_wijk`) met de code, met de volledige geometrie, zonder
   `zoom-level`: een vereenvoudigde grens verschuift de oppervlakte;
2. `process_aggregate-features` met `clip: {"geometry": <die geometrie>}` (of `{"point": [lon, lat],
   "distance": 250}`), `aggregates` met `{"function": "sum", "property": "$area"}` (`$length` voor lengte);
3. in `source.parameters` **`gemeentecode`, niet `buurtcode`**: het buurtfilter laat precies de objecten
   weg die van de buurt ernaast in de buurt steken. `clip` neemt alleen de objecten die het gebied
   snijden; de grens van 100.000 telt daarna.

Het resultaat met `clip` is de oppervlakte binnen het gebied; noem dat getal, niet de som van hele
objecten. Een aanroep met `clip` duurt een tot twee seconden.

### 3.8 Geregistreerd is niet aanwezig

- **BGT-inrichtingselementen en IMGeo-plus**: zie §5.5.
- **CBS per postcode**: een ontbrekende waarde is 0 tot 4 of geheim, geen nul (§6.3).
- **Wat de BAG niet heeft**: bewoners, namen van bedrijven, eigenaren, prijzen, energielabels. Woonboten
  (`ligplaats`) en woonwagens (`standplaats`) zijn geen verblijfsobjecten en ontbreken in elke telling van
  woningen; tel ze apart als de vraag ze kan bedoelen.

### 3.9 Fouten

Een verbindingsfout of time-out één keer opnieuw proberen. Een fout 502/503/504 of een melding dat een
document van `service.omgevingswet.overheid.nl` niet te lezen is: het DSO is niet bereikbaar, niet de
invoer fout; probeer geen andere invoer en zeg het de gebruiker. Een mislukte aanroep is nooit "geen
resultaat".

---

## 4. BAG: adressen en gebouwen

### 4.1 Bereik

Alle adressen en gebouwen met hun historie. Welke woonplaatsen de server bevat, geeft
`collection_woonplaats`. Wordt een adres niet gevonden, controleer dan eerst of de woonplaats erin staat,
en zeg anders dat de gegevens daar ontbreken, niet dat het adres niet bestaat.

### 4.2 Model

Een **adres** is een `nummeraanduiding` (postcode, huisnummer, huisletter, huisnummertoevoeging) die
`ligtAan` een `openbareruimte` (straat), die `ligtIn` een `woonplaats`. Adressen horen bij een
`verblijfsobject` (woning, winkel, kantoor; een punt), een `ligplaats` (woonboot) of een `standplaats`
(woonwagen). Een verblijfsobject `maaktDeelUitVan` een of meer **panden** (gebouwen; een vlak).

| Verwijzing | Omgekeerd zoeken |
|---|---|
| verblijfsobject.heeftAlsHoofdadres → nummeraanduiding | `collection_verblijfsobject` met `heeftAlsHoofdadres=<id>` |
| verblijfsobject.maaktDeelUitVan → pand | `collection_verblijfsobject` met `maaktDeelUitVan=<id>`, of `query_pand-met-inhoud` |
| nummeraanduiding.ligtAan → openbareruimte | `collection_nummeraanduiding` met `ligtAan=<id>` |

Identificaties hebben 16 cijfers; cijfer 5-6 geven het type (01 verblijfsobject, 10 pand, 20
nummeraanduiding, 30 openbare ruimte); een woonplaats heeft 4 cijfers. In een MCP-resultaat is een
verwijzing `{"id": ..., "title": ...}`; de titel van een adres is bijvoorbeeld 'Stadhuisplein 1, 3811LM
Amersfoort'.

Eigenschappen per objecttype in zoekresultaten (voor zover niet weggelaten via `weglaten`; splits een
gemengd resultaat op `objecttype`, niet op de volgorde):
- **pand**: oorspronkelijkBouwjaar (9999 = onbekend; oude panden vaak een geschat rond jaartal), status,
  beginGeldigheid (begin van de huidige versie), geometrie (bovenaanzicht), op verzoek grondoppervlakte (m²).
- **verblijfsobject**: gebruiksdoel (alle), oppervlakte (gebruiksoppervlakte m²; 999999 is geen
  werkelijke oppervlakte), status, beginGeldigheid, heeftAlsHoofdadres en heeftAlsNevenadres,
  maaktDeelUitVan (de panden), geometrie (punt), bouwjaarPand (oudste bouwjaar van die panden).
- **nummeraanduiding**: huisnummer, huisletter, huisnummertoevoeging, postcode (verwijst naar het
  postcodegebied in `postcode6`), typeAdresseerbaarObject, status, ligtAan (titel: straatnaam), ligtIn
  (alleen als de woonplaats afwijkt van die van de straat).
- **openbareruimte**: naam, type (Weg, Water, ...), status, ligtIn (woonplaats). **woonplaats**: naam,
  status. **ligplaats en standplaats**: heeftAlsHoofdadres, status, geometrie (vlak).

Objecttypen per zoekopdracht: `panden-in-gebied` pand; `verblijfsobjecten-in-panden` pand,
verblijfsobject; `verblijfsobjecten-in-gebied` en `verblijfsobjecten-in-de-buurt` verblijfsobject;
`adres-op-postcode` nummeraanduiding, openbareruimte, woonplaats, verblijfsobject, ligplaats, standplaats,
pand; `adres-op-straat` idem in andere volgorde; `pand-met-inhoud` pand, verblijfsobject, nummeraanduiding,
openbareruimte.

### 4.3 Welke tool voor welke vraag

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

Om te tellen nooit alle objecten ophalen: `process_aggregate-features` geeft het getal direct, ook met
kenmerken van het pand bij het verblijfsobject (`statusPand`, `bouwjaarPand`), zodat vragen over woningen
in oude of gesloopte panden één aanroep op `verblijfsobject` zijn.

### 4.4 Valkuilen

- **Statussen.** De zoekopdrachten leveren standaard alleen bestaande objecten in gebruik; de collecties en
  `process_aggregate-features` leveren alle statussen, ook gesloopt, ingetrokken en in aanbouw: geef daar
  een status op (parameter één waarde; meer met een filter). Pand: Bouwvergunning verleend, Bouw gestart,
  Pand in gebruik (niet ingemeten), Pand in gebruik, Verbouwing pand, Sloopvergunning verleend, Pand
  gesloopt, Pand buiten gebruik, Niet gerealiseerd pand, Pand ten onrechte opgevoerd. Verblijfsobject:
  Verblijfsobject gevormd (in aanbouw), Verblijfsobject in gebruik (niet ingemeten), Verblijfsobject in
  gebruik, Verbouwing verblijfsobject, Verblijfsobject buiten gebruik, Verblijfsobject ingetrokken, Niet
  gerealiseerd verblijfsobject, Verblijfsobject ten onrechte opgevoerd.
- **Woning** = verblijfsobject met gebruiksdoel woonfunctie. Standaard voor "woningen": `filter: "status IN
  ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing
  verblijfsobject')"`; noem woningen in aanbouw apart als ze ertoe doen (in een nieuwbouwwijk honderden).
  Zeg je "in gebruik", dan moet het getal uit dat filter komen; een telling zonder statusfilter is nooit
  "in gebruik". Een deelvraag ("waarvan sinds 2015 gebouwd") gebruikt hetzelfde filter, plus `bouwjaarPand`.
- **Bouwjaar** `oorspronkelijkBouwjaar`: 9999 is onbekend (uitsluiten met `bouwjaarTot` 9998 of een
  filter). Oude panden hebben vaak een geschat rond jaar (1600, 1700, 1800); aantallen per jaar vóór
  ongeveer 1900 zijn grof. `bouwjaarPand` bij een verblijfsobject is het oudste bouwjaar van zijn panden.
  Woningen "gebouwd sinds" een jaar missen woningen die later in een ouder pand zijn gemaakt; voor "erbij
  gekomen" zie §3.5.
- **Oppervlakte** van een verblijfsobject is de gebruiksoppervlakte; 999999 is geen werkelijke
  oppervlakte. `grondoppervlakte` van een pand is berekend uit de geometrie; `grondoppervlakteMin` 50
  sluit schuren en garages uit.
- **Gebruiksdoel** is de vergunde gebruiksfunctie (Bouwbesluit 2012), een lijst: woonfunctie,
  bijeenkomstfunctie, celfunctie, gezondheidszorgfunctie, industriefunctie, kantoorfunctie, logiesfunctie,
  onderwijsfunctie, sportfunctie, winkelfunctie, overige gebruiksfunctie. Geen soort voorziening:
  sportfunctie omvat sporthallen, sportscholen en kantines. Een verblijfsobject met meer gebruiksdoelen
  telt in een groepering in elke groep mee, in het totaal één keer.
- **Wat geteld is**: panden, verblijfsobjecten of oppervlakte geven verschillende beelden (een flatgebouw
  is één pand met veel woningen; de meeste gesloopte panden zijn schuren). Woonboten en woonwagens hebben
  geen gebruiksdoel: `process_aggregate-features` op `ligplaats` en `standplaats` (met status 'Plaats
  aangewezen') telt ze apart.
- **Data**: `beginGeldigheid` is het begin van de huidige versie; bij een gesloopt pand de datum van de
  registratie van de sloop, soms later dan de sloop. `sinds` en `tot` filteren daarop. Een 'Bouwvergunning
  verleend' kan jaren oud zijn als er nooit gebouwd is: combineer met `sinds`.
- **Adressen vinden**: `query_adres-op-straat` vraagt de volledige officiële straatnaam (Burgemeester, niet
  Burg.; Stadhuisplein, niet Stadhuispl.) en de **woonplaats**, niet de gemeente: een gemeente heeft vaak
  meer woonplaatsen. Geen resultaat: zoek de spelling met `collection_openbareruimte` en `naam` met `*`
  (`*Smittweg`) en lees de woonplaats uit `ligtIn`, of vraag de postcode.
- Een titel die eindigt op '(ingetrokken)' verwijst naar een ingetrokken adres, straat of woonplaats.
  Adreszoekopdrachten leveren alleen uitgegeven adressen, tenzij `status` ook 'Naamgeving ingetrokken'
  bevat. Is het gevraagde adres ingetrokken, zeg dat; de huidige adressen ernaast zijn geen vervanging,
  noem ze als zodanig. Een verblijfsobject kan ingetrokken nevenadressen houden waarvan de nummers nu
  hoofdadres van andere verblijfsobjecten zijn; tel die niet als extra woningen of adressen.
- **Gebieden**: zoekopdrachten nemen één code in `gebied`; panden, verblijfsobjecten, ligplaatsen en
  standplaatsen filteren op `gemeentecode`, `wijkcode` of `buurtcode`. Meer codes: `filter: "wijkcode IN
  ('WK030701','WK030702')"`. Gebiedscodes en -namen, `grondoppervlakte`, `aantalVerblijfsobjecten`,
  `bouwjaarPand`, `statusPand` en `objecttype` staan standaard niet in de uitvoer: collecties met
  `properties`, zoekopdrachten met `weglaten` zonder die eigenschap.

### 4.5 Historie

- Zonder `datetime` de versie van vandaag; met `datetime: "2015-01-01"` (collecties, `source.parameters`
  van `process_aggregate-features`) de versie die toen gold, ook van objecten die nu gesloopt of
  ingetrokken zijn. De zoekopdrachten kennen geen `datetime`.
- De toestand vlak vóór een wijziging (de status vóór een sloop, de verblijfsobjecten van toen):
  `collection_<type>` met `ids` of `maaktDeelUitVan` en `datetime` = de dag vóór `beginGeldigheid`.

### 4.6 Kenmerken in onderzoek

Hangt een antwoord af van één waarde van één object, of lijkt een waarde onwaarschijnlijk:
`process_aggregate-features` met `source: {"collection": "kenmerkinonderzoek", "parameters": {"datetime":
"now", "filter": "object IN ('<id>') AND inOnderzoek = true"}}`, `groupBy: ["kenmerk"]`; geen groepen =
niets in onderzoek. Eén object per aanroep; niet standaard bij elke vraag.

### 4.7 Sloop controleren

'Pand gesloopt' beëindigt ook een samenvoeging met een buurpand (dat op dezelfde datum groter wordt en de
verblijfsobjecten met hun adressen overneemt) en een pand dat nooit is gebouwd. Per pand, alleen voor de
grotere (`grondoppervlakte` ≥ 50 m²) en alleen als de vraag het nodig maakt (enkele aanroepen per pand):

1. De status de dag vóór `beginGeldigheid`: `collection_pand` met `ids` en `datetime`. Was dat
   'Bouwvergunning verleend', dan is het pand nooit gebouwd.
2. De verblijfsobjecten van die dag: `collection_verblijfsobject` met `maaktDeelUitVan` en `datetime`.
   Zijn ze nu (`ids`, zonder `datetime`) in gebruik in een ander pand, dan is het een samenvoeging; zijn ze
   'Verblijfsobject ingetrokken', dan een echte sloop.
3. `query_pand-met-inhoud` levert bij een samengevoegd pand alleen het pand, zonder verblijfsobjecten: dat
   is het teken, geen leeg pand.

Noem het resultaat per soort (echt gesloopt, samengevoegd, nooit gebouwd).

### 4.8 Combineren met andere API's

- **BGT**: de topografie rond een adres (`process_pand-bij-adres` levert de BGT-objecten op de plek;
  `query_wat-ligt-hier` met het punt van het verblijfsobject). Een BGT-pand verwijst met
  `identificatieBAGPND` naar het BAG-pand.
- **Wijken en buurten** levert alleen namen, codes en grenzen, geen inwoners; BAG-aantallen zijn tellingen
  van objecten, geen CBS-statistiek. **Postcodegebieden**: de postcode van een nummeraanduiding verwijst
  ernaar.
- **DSO**: de regels op een adres (postcode en huisnummer). Een punt in het Rijksdriehoeksstelsel: het
  argument `crs` = `http://www.opengis.net/def/crs/EPSG/0/28992` bij de collecties en zoekopdrachten.

### 4.9 Voorbeelden

**Hoeveel woningen heeft elke wijk van Amersfoort?** `process_aggregate-features` met `source:
{"collection": "verblijfsobject", "parameters": {"gemeentecode": "0307", "gebruiksdoel": "woonfunctie",
"filter": "status IN ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing
verblijfsobject')"}}`, `groupBy: ["wijkcode", "wijknaam"]`. Zeg dat verblijfsobjecten met woonfunctie geteld
zijn, inclusief gemengde functies, met deze statussen.

**Hoeveel woningen staan er per bouwperiode in wijk Stadskern?** Dezelfde bron met `wijkcode: "WK030701"`,
`groupBy: [{"property": "bouwjaarPand", "bucket": 50}]`, `aggregates: ["count", {"function": "avg",
"property": "oppervlakte"}]`.

**Welke panden zijn sinds 2020 als gesloopt geregistreerd in buurt Hof?** `query_panden-in-gebied` met
`gebied: "BU03070100"`, `status: ["Pand gesloopt"]`, `sinds: "2020-01-01"`, `weglaten` zonder
`grondoppervlakte`. Splits op grootte; voor de grote panden §4.7.

**Wat is de dichtstbijzijnde winkel bij Stadhuisplein 1?** `query_adres-op-postcode` (3811LM, 1) → punt van
het verblijfsobject → `process_nearest-features` met `source: {"collection": "verblijfsobject",
"parameters": {"gebruiksdoel": "winkelfunctie", "status": "Verblijfsobject in gebruik", "properties":
"heeftAlsHoofdadres,gebruiksdoel,oppervlakte"}}`, `point`, `distance: 500`. Zonder status komen ook
ingetrokken winkels mee.

---

## 5. BGT: de topografie

### 5.1 Bereik

De kaart van Nederland op het niveau van straten en panden, met historie. Welk gebied de server bevat,
staat in de instructies van de server. Een vraag over een plaats daarbuiten: zeg dat de gegevens daar
ontbreken, niet dat er niets is.

### 5.2 Welke tool voor welke vraag

| Vraag | Tool |
|---|---|
| Hoeveel, hoeveel m², hoeveel meter, per soort of per gebied | `process_aggregate-features` (van de BGT-server) |
| Verdeling van een gebied: groen, verharding, water, bebouwing | `process_aggregate-features` met `clip` (§3.7), of `query_topografie-in-gebied` voor de objecten |
| Wegen, fietspaden, voetpaden, parkeervlakken, spoor in een gebied | `query_wegen-in-gebied` (functie, fysiekVoorkomen) |
| Bomen, banken, lichtmasten, putten, borden, speeltoestellen | `query_inrichtingselementen-in-gebied` (soort) |
| Parken, speeltuinen, sportterreinen, begraafplaatsen, overkappingen, straatnaamlabels | `query_overige-objecten-in-gebied` |
| Wat ligt er op of bij een adres of punt | `query_wat-ligt-hier` (punt uit de BAG) |
| Wat is er veranderd in een gebied, nieuw, gewijzigd, verdwenen | `query_wijzigingen-in-gebied` (sinds, tot) |
| Objecten van één collectie met een eigenschap of in een bbox | `collection_pand`, `collection_wegdeel`, `collection_begroeidterreindeel`, `collection_onbegroeidterreindeel`, `collection_waterdeel` |

De andere collecties hebben geen eigen tool; ze zijn bereikbaar via de zoekopdrachten en via
`process_aggregate-features` (`source.collection` met hun id, ook een lijst van ids). De betekenis van de
waarden per collectie staat in aparte waardelijsten (niet in deze skill); lees die als niet duidelijk is
welke waarde bij een begrip hoort (is een grasveld 'grasland overig' of 'groenvoorziening'?).

### 5.3 Gebieden en grootte

- De zoekopdrachten nemen één code in `gebied`; collecties en `source.parameters` filteren op
  `gemeentecode`, `wijkcode` of `buurtcode`. De buurtcode bevat de gemeente- en de wijkcode.
- Een object hoort bij precies één buurt (punt op de geometrie). Voor oppervlakten in een gebied: `clip`,
  met `gemeentecode` in de bron (§3.7).
- Een gemeente van 150.000 inwoners heeft rond 250.000 vlakken (wegdeel en begroeidterreindeel elk rond
  50.000, pand rond 90.000). `process_aggregate-features` leest hoogstens 100.000 objecten: over een hele
  gemeente één collectie per aanroep. Met `clip` telt de grens pas na het knippen.
- `query_topografie-in-gebied` voor een buurt levert honderden objecten (rond 450 bytes per object zonder
  geometrie); voor een wijk duizenden. Ophalen alleen voor een lijst of een kaart, niet om te tellen.

### 5.4 Indeling van de objecten

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

- Waarden precies zo opgeven als in de waardelijsten, met spaties en kleine letters (`bgtFunctie=rijbaan
  lokale weg`). Een zoekbare eigenschap als parameter heeft één waarde; meer met een filter:
  `filter=bgtFunctie IN ('fietspad','voetpad')`.
- Een waarde met een dubbele punt verfijnt de waarde ervoor: `'recreatie: speeltuin'` is een soort
  `'recreatie'`. Alle soorten samen: `filter=plusType LIKE 'recreatie%'`.
- De waarde `transitie` komt voor bij bgtFunctie en bgtType, maar staat in geen waardelijst; er is geen
  definitie.

### 5.5 IMGeo-plus en bronhouders

- IMGeo-plus (plusFunctie, plusFysiekVoorkomen, plusType en alle inrichtingselementen) is optioneel: alleen
  gevuld waar de bronhouder het bijhoudt. Ontbreekt de waarde, dan staat er een reden: `waardeOnbekend` of
  `geenWaarde`; sommige objecten (palen) hebben helemaal geen plusType.
- De bronhouder is niet altijd de gemeente: in een gemeente liggen ook objecten van buurgemeenten (G...), de
  provincie (P...), het waterschap (W...) en het Rijk (L...: Rijkswaterstaat, ProRail). De namen staan in de
  codelijst `/bgt/codelists/bronhouder`.
- Tellen van inrichtingselementen: groepeer eerst op `["plusType", "bronhouder"]`. Voorbeeld uit een proef:
  van 420 lichtmasten kwamen er 364 van de provincie en 16 van de gemeente; van 1.687 bomen 12 van de
  gemeente. Een handvol banken of geen speeltoestellen voor een stad betekent dat de gemeente ze niet in de
  BGT bijhoudt, niet dat ze er niet zijn. Zeg "in de BGT geregistreerd" en wie ze bijhoudt.
- Bij aandelen per fysiek voorkomen: `plusFysiekVoorkomen` 'waardeOnbekend' kan een vijfde van de
  wegoppervlakte zijn (de grote wegen van andere bronhouders); de BGT-waarde (`bgtFysiekVoorkomen`) is
  volledig.

### 5.6 Oppervlakte, lengte en aandelen

- Op maaiveldniveau (relatieveHoogteligging 0) bedekken de vlakken het gebied zonder gaten en overlap; de
  som per soort is de verdeling van het gebied. Bruggen, overkappingen (1 en hoger) en tunnels (-1 en lager)
  tellen niet mee. Functionele gebieden (parken, speeltuinen) overlappen de vlakken en tellen ook niet mee.
- Groen voor een aandeel: `begroeidterreindeel` (alle soorten), eventueel per `bgtFysiekVoorkomen`.
  `onbegroeidterreindeel` met bgtFysiekVoorkomen 'erf' is de grond bij een pand: tuinen, binnenplaatsen,
  opritten. Een aandeel groen bevat dus geen tuinen; noem het aandeel erf erbij, vooral in woonbuurten.
- Het totaal voor een aandeel: de som van de vlakken op maaiveld met dezelfde `clip`, niet de oppervlakte
  uit een andere bron.
- `oppervlakte` (m²) en `lengte` (m) staan standaard niet in de uitvoer van de collecties; in
  `process_aggregate-features` zijn `$area` en `$length` de oppervlakte en lengte van de geometrie (met
  `clip` van het deel binnen het gebied).
- Panden hebben geen bgtFysiekVoorkomen; in een groepering op die eigenschap staan ze in de groep zonder die
  sleutel. BGT-pand en BAG-pand verschillen in oppervlakte hooguit een procent.

### 5.7 Tijd en versies

- Zonder `datetime` levert de API wat nu in de registratie staat, dus alleen bestaande objecten. Met
  `datetime=2020-01-01T00:00:00Z` de toestand op dat moment.
- **De historie begint per bronhouder bij de eerste levering** (voor de meeste gemeenten eind 2016). Vergelijk
  niet met een datum daarvoor; een toename tussen twee datums kan ook fijnere inwinning zijn.
- `query_wijzigingen-in-gebied`: een versie zonder link 'predecessor-version' is een nieuw object; een
  objectEindTijd is een beëindigd object. Een object dat in de periode eindigde, komt met zijn laatste
  versie, ook als die van vóór de periode is. Een nieuwe versie kan een wijziging in de werkelijkheid of een
  correctie zijn; de BGT maakt dat onderscheid niet.
- **Hoeveel er veranderd is**: `process_aggregate-features` met `source: {"query": "wijzigingen-in-gebied",
  "parameters": {"gebied": ..., "sinds": ..., "tot": ...}}` en `aggregates: ["count"]`, gegroepeerd op
  `$collection`; het totaal is het aantal objecten dat in de periode nieuw, gewijzigd of beëindigd is (een
  object met meer versies telt één keer). Tel niet met collecties en een filter op `objectBeginTijd` of
  `tijdstipRegistratie`: dat mist de objecten die in de periode zijn beëindigd. Haal de versies niet op om
  te tellen.
- Bulkbewerkingen vinden: `process_aggregate-features` met de zoekopdracht als bron, `groupBy:
  ["$collection", {"property": "tijdstipRegistratie", "bucket": "month"}]`; een piek daarna per exact
  `tijdstipRegistratie` en `bronhouder`. Honderden objecten van één bronhouder met hetzelfde tijdstip zijn
  een administratieve invoer of herinwinning. `bucket` voor een tijdstip is `year`, `month` of een getal.
- Begin met een buurt of een korte periode: een gemeente over meer dan een jaar haalt de grens van 100.000.

### 5.8 Combineren met andere API's

- **Adres → punt**: de BAG (`query_adres-op-postcode`) levert de geometrie van het verblijfsobject als
  lengte/breedtegraad; daarmee `query_wat-ligt-hier` (`punt`, eventueel `afstand` tot 100 m) of
  `process_aggregate-features` met `clip`.
- **Pand**: `identificatieBAGPND` is de identificatie van het pand in de BAG. **Straat**:
  `identificatieBAGOPR` van een openbareruimtelabel is de openbare ruimte in de BAG.
- **Woningen of inwoners in een gebied**: niet in de BGT; de BAG telt verblijfsobjecten, de
  Postcodegebieden hebben CBS-cijfers.

### 5.9 Voorbeelden

**Hoeveel procent van wijk Stadskern is groen?** (1) `collection_wijk` met `gemeente=0307`,
`naam=Stadskern` → id `WK030701` en de geometrie. (2) `process_aggregate-features` met `source:
{"collection": ["wegdeel", "ondersteunendwegdeel", "begroeidterreindeel", "onbegroeidterreindeel",
"waterdeel", "ondersteunendwaterdeel", "pand", "overigbouwwerk", "kunstwerkdeel", "spoor"], "parameters":
{"gemeentecode": "0307", "filter": "relatieveHoogteligging = 0"}}`, `clip: {"geometry": <geometrie van de
wijk>}`, `groupBy: ["$collection", "bgtFysiekVoorkomen"]`, `aggregates: [{"function": "sum", "property":
"$area"}]` (rond 4 seconden). (3) Aandeel = begroeidterreindeel / totaal; noem het aandeel erf erbij.

**Hoeveel bomen staan er per buurt in Amersfoort?** `process_aggregate-features` met `source: {"query":
"inrichtingselementen-in-gebied", "parameters": {"gebied": "0307", "soort": ["boom"]}}`, `groupBy:
["bronhouder", "buurtcode"]`. Presenteer als "geregistreerd in de BGT", met wie ze bijhoudt.

**Hoeveel m² fietspad ligt er in wijk Stadskern?** `process_aggregate-features` met `source:
{"collection": "wegdeel", "parameters": {"gemeentecode": "0307", "bgtFunctie": "fietspad"}}`, `clip` met de
geometrie van de wijk, `aggregates: [{"function": "sum", "property": "$area"}]`.

**Wat ligt er bij Stadhuisplein 1, Amersfoort?** `query_adres-op-postcode` (3811LM, 1) → punt van het
verblijfsobject → `query_wat-ligt-hier` met dat punt en `afstand` 20 voor ook de straat en het groen ervoor.

---

## 6. CBS: Wijken en buurten, Postcodegebieden

### 6.1 Bereik

- **Wijken en buurten**: gemeenten, wijken en buurten volgens de Wijk- en Buurtkaart 2026 met naam, code
  en grens. **Geen inwoners of andere cijfers.**
- **Postcodegebieden**: statistiek per postcode (PC6) op 1 januari 2024: inwoners naar geslacht, leeftijd en
  herkomst, huishoudens, woningen naar bouwjaar en eigendom, uitkeringen.
- Cijfers per buurt of wijk (inwoners, WOZ-waarde, inkomen) uit de Kerncijfers wijken en buurten van het CBS
  zitten in geen van beide.

### 6.2 Wijken en buurten

- Tools: `collection_gemeente`, `collection_wijk`, `collection_buurt`. De code is de id van het object;
  `wijk` en `gemeente` van een buurt zijn verwijzingen met de naam als titel.
- Namen zijn hoofdlettergevoelig (`Hof` vindt de buurt, `hof` niets); zie §3.1 voor zoeken. Veel buurten
  heten naar een straat met 'e.o.' (`Kersenbaan e.o.`): zoek met `*`.
- Een buurt of wijk op gemeentenaam: `filter: "gemeentenaam = 'Amersfoort'"` (alleen als filter; de naam
  staat niet in de uitvoer).
- **Grootte**: zonder `properties` komt de volledige geometrie mee (rond 2 tot 4 kB per buurt, een gemeente
  rond 80 kB). Voor namen en codes `properties: ["naam", "wijk"]` en `limit` 500. Voor `clip` de volledige
  geometrie van één buurt of wijk. Voor een kaart `zoom-level` 12 (een gemeente rond 3 kB), of de link uit
  het resultaat.

### 6.3 Postcodegebieden

- `collection_postcode6` met `postcode`, `gemeentecode`, `wijkcode` of `buurtcode`; andere eigenschappen met
  `filter` (`filter: "postcode LIKE '3811%'"`, `filter: "aantal_inwoners >= 500"`). Zonder `properties`
  komt de geometrie mee (rond 1,4 kB per postcode).
- `process_aggregate-features` van deze server telt en somt per gemeente, wijk of buurt zonder de
  postcodes op te halen: `source: {"collection": "postcode6", "parameters": {"gemeentecode": "0307"}}`,
  `groupBy: ["wijkcode"]`, `aggregates: [{"function": "sum", "property": "aantal_inwoners"}, {"function":
  "count", "property": "aantal_inwoners"}, "count"]`. `count` met een eigenschap telt de postcodes met een
  waarde; zet het naast `count` zonder eigenschap om te zeggen hoeveel postcodes meetellen. De groepen
  hebben de code als sleutel; de namen komen uit Wijken en buurten.
- Een postcodegebied hoort bij de buurt waarin een punt binnen het gebied ligt; een paar postcodes van
  adressen in de gemeente liggen volgens het CBS in een buurgemeente. In de BAG verwijst de postcode van een
  nummeraanduiding naar het postcodegebied.

### 6.4 Valkuilen: wat een ontbrekende waarde betekent

- Aantallen zijn op vijftallen afgerond, percentages op tientallen. Het CBS publiceert een waarde alleen bij
  ten minste vijf inwoners, huishoudens of woningen (percentages bij ten minste tien). **Een ontbrekende
  waarde is 0 tot 4 of geheim**, geen nul en geen onbekend aantal. Sommige postcodes hebben helemaal geen
  eigenschappen.
- Hoe vaak waarden ontbreken (een gemeente, ruim 3.600 postcodes): aantal inwoners 8 %, leeftijdsklassen 22
  tot 55 %, bouwjaarklassen 81 tot 94 %, eenouderhuishoudens 93 %, percentage koopwoningen 42 %,
  huurwoningen 73 %.
- **Sommen zijn ondergrenzen**, sommen van deelgroepen nog meer: de som van de leeftijdsklassen lag 8 % onder
  de som van de inwoners, de som van de vier huishoudtypen 20 % onder de som van de huishoudens. Zeg
  "minstens" of "ongeveer" en dat postcodes met weinig inwoners ontbreken.
- **Percentages** en de gemiddelde huishoudensgrootte zijn niet op te tellen. Een gewogen gemiddelde
  (`{"function": "avg", "property": "percentage_koopwoningen", "weight": "aantal_woningen"}`) telt alleen
  de postcodes met een waarde; omdat koop en huur vaak maar één van beide hebben, tellen de gewogen
  gemiddelden samen tot ver boven 100 %. Een aandeel koopwoningen per wijk volgt er niet uit: geef de
  spreiding of zeg dat het CBS het per wijk in de Kerncijfers publiceert.
- **Sorteren**: `sortby: "-aantal_inwoners"` zet de postcodes zonder waarde vooraan; filter op
  `aantal_inwoners IS NOT NULL`. Een vergelijking (`< 5`) treft een ontbrekende waarde nooit.
- **Grootte**: een postcode met twee eigenschappen zonder geometrie is rond 200 bytes; een buurt van 25 tot
  50 postcodes past ruim. Een hele gemeente (3.600 postcodes) met één eigenschap is 300 kB en past niet in
  het antwoord: tellen met `process_aggregate-features`, of per wijk ophalen. De geometrie van alle
  postcodes van een gemeente is meer dan een megabyte: alleen als link voor een kaart.

### 6.5 Voorbeelden

**Hoeveel huishoudens hebben de postcodes die met 3817 beginnen?** `process_aggregate-features`
(Postcodegebieden) met `source: {"collection": "postcode6", "parameters": {"filter": "postcode LIKE
'3817%'"}}`, `aggregates: [{"function": "sum", "property": "aantal_part_huishoudens"}, {"function": "count",
"property": "aantal_part_huishoudens"}, "count"]`. Antwoord: "minstens ..., in ... van de ... postcodes;
postcodes met minder dan vijf huishoudens ontbreken".

**Welke postcode in een gemeente heeft de meeste kinderen onder 15?** `collection_postcode6` met
`gemeentecode`, `filter: "aantal_inwoners_0_tot_15_jaar IS NOT NULL"`, `sortby:
"-aantal_inwoners_0_tot_15_jaar"`, `properties: ["postcode", "aantal_inwoners_0_tot_15_jaar", "buurtcode"]`,
`limit` 5.

---

## 7. DSO: regels van de Omgevingswet op een adres

### 7.1 Bereik

De werkstromen roepen live de API's van het Digitaal Stelsel Omgevingswet (DSO) aan, met de BAG van deze
server voor het adres. Het zijn bewerkte, niet-officiële kopieën van werkstromen van het DSO-team. Een
antwoord is informatie, geen juridisch advies of besluit: verwijs voor zekerheid naar het Omgevingsloket
(omgevingswet.overheid.nl) of de gemeente. Een aanroep duurt 1 tot 4 seconden, bij fouten van het DSO zelf
tot een halve minuut (de werkstroom probeert een stap dan een paar keer opnieuw); roep een werkstroom niet
onnodig opnieuw aan.

### 7.2 Welke werkstroom voor welke vraag

| Vraag | Werkstroom |
|---|---|
| Wat mag ik hier met wonen, welke woonregels gelden | `regels-over-wonen` |
| Mag ik hier een dakkapel (of iets anders) bouwen, heb ik een vergunning nodig | `dakkapel-hier` (vergunningcheck in rondes) |
| Staat er iets op stapel, wat verandert er, lopende ontwerpen | `wat-verandert-hier` |
| Een aanvraag of melding voorbereiden: activiteit, bevoegd gezag, vragen, indienbaar? | `verzoek-voorbereiden` (dient niets in) |
| Welke documenten golden hier op een datum | `documenten-op-peildatum` |
| De versies van een regeling | `versiehistorie` |
| De gegevens van een regeling | `regeling-detail` |
| Welke regels golden hier op een datum, en hun tekst | `regels-op-peildatum`, dan `ow-tekst-ophalen` |

### 7.3 Invoer

- **Adres**: postcode zonder spatie (`3811LM`) en huisnummer als tekst (`"1"`, geen getal), zonder huisletter
  of toevoeging. De eerste stap zoekt in de BAG van deze server **precies één** adres met die postcode en
  dat huisnummer, met een verblijfsobject. Dat mislukt voor adressen met een huisletter of toevoeging (een
  op de vijf), voor een kaal nummer naast nummers met letter (12 naast 12A), voor lig- en standplaatsen en
  buiten het gebied van de BAG. De fout is dan 422 "The step 'adres' of the workflow ... failed", zonder
  reden. Controleer het adres met `query_adres-op-postcode` (BAG): bestaat het, zeg dan dat de werkstroom
  dit adres niet aankan (niet dat het niet bestaat), en bied een adres zonder letter in hetzelfde pand aan
  als de vraag over het pand gaat. Bij twijfel vooraf hetzelfde controleren.
- **Twee datumnotaties**: `datum` is `dd-MM-jjjj` (toepasbare regels, meestal vandaag), `peildatum` is
  `jjjj-MM-dd`. `verzoek-voorbereiden` vraagt dezelfde dag in beide notaties.
- **Regeling**: `uriIdentificatie` met underscores, zoals de werkstromen hem leveren, bijvoorbeeld
  `_akn_nl_act_gm0307_2020_omgevingsplan`; de vorm met schuine strepen wordt geweigerd.
- **Punt in RD** (`rdX`, `rdY` voor de peildatum-werkstromen): de BAG levert het met het argument `crs` =
  `http://www.opengis.net/def/crs/EPSG/0/28992`, bijvoorbeeld `query_adres-op-postcode` (postcode,
  huisnummer, crs): de geometrie van het verblijfsobject is dan `[rdX, rdY]`. Alleen als de BAG-tools niet
  beschikbaar zijn: reken lengte/breedtegraad om met de benaderingsformule (nauwkeurig tot ongeveer 1 m):
  ```
  dp = 0.36 * (lat - 52.15517440);  dl = 0.36 * (lon - 5.38720621)
  rdX = 155000 + 190094.945*dl - 11832.228*dp*dl - 114.221*dp^2*dl - 32.391*dl^3 - 0.705*dp
        - 2.340*dp^3*dl - 0.608*dp*dl^3 - 0.008*dl^2 + 0.148*dp^2*dl^3
  rdY = 463000 + 309056.544*dp + 3638.893*dl^2 + 73.077*dp^2 - 157.984*dp*dl^2 + 59.788*dp^3
        + 0.433*dl - 6.439*dp^2*dl^2 - 0.032*dp*dl + 0.092*dl^4 - 0.054*dp*dl^4
  ```
  Controle: lon 5.38416472, lat 52.15671963 → rdX 154792, rdY 463172. Neem altijd het punt van het adres
  uit de vraag.

### 7.4 Fouten

- 422 over de stap 'adres': zie Invoer. 502, 503 of 504, of een melding dat een OpenAPI-document van
  `service.omgevingswet.overheid.nl` niet te lezen is: het DSO is niet bereikbaar. Niet met andere invoer
  opnieuw proberen; zeg de gebruiker dat het DSO nu niet antwoordt. Een mislukte werkstroom betekent nooit
  "er gelden geen regels".
- 429 "workflows are already running": hoogstens drie werkstromen tegelijk. Roep ze na elkaar aan, niet
  parallel, en probeer het na een paar seconden opnieuw.
- 422 met een 404 van het DSO "kan niet gevonden worden voor tijdreis" (`regels-op-peildatum`): de regeling
  gold op die peildatum nog niet of niet meer; dat is een antwoord, geen storing.

### 7.5 De uitvoer lezen

- **Parallelle lijsten**: elementen op dezelfde positie horen bij elkaar (`activiteiten[i]`,
  `conclusie[i]`, `vraagIds[i]`). Tel niet op en sorteer niet los van elkaar. `null` op een positie: voor
  dit element geen waarde.
- **Regelteksten** (`owTeksten`, uitvoer van `ow-tekst-ophalen`) zijn XML volgens STOP: de tekst staat in
  `<Al>` (alinea's) en `<Li>` (lijstonderdelen met `<LiNummer>`); negeer de attributen. Het artikelnummer
  staat in de identificatie, bijvoorbeeld `..._art_22.31` → artikel 22.31. Geef de tekst in gewone zinnen
  of als lijst weer, niet als XML.
- **Omgevingsplan en bestemmingsplannen**: tot een gemeente haar omgevingsplan helemaal heeft vernieuwd,
  gelden de regels van de oude bestemmingsplannen (Wro) als deel van het omgevingsplan. De werkstromen
  leveren beide: `omgevingsplan`, `owArtikelen`, `owTeksten` (nieuw) en `wroPlannen`, `wroBestemmingen`,
  `wroMaatvoeringen` (oud). Noem beide.

### 7.6 Per werkstroom

**regels-over-wonen**: zoekt in de bestemmingsplannen alleen de hoofdgroep 'wonen'. In binnensteden valt
wonen vaak onder 'centrum' of 'gemengd'; een lege `wroBestemmingen` betekent dus niet dat wonen er niet
mag. Zeg dat erbij.

**dakkapel-hier** (vergunningcheck):
1. Eerste ronde zonder `antwoorden`, `activiteit` als korte term (`dakkapel`), `datum` vandaag. De uitvoer
   heeft per gevonden activiteit (meestal een gemeentelijke en een van het Rijk) de vragen
   `vragenVergunningcheck[i]` met ids `vraagIds[i]`, en `conclusie[i]`.
2. Stel de vragen aan de gebruiker; beantwoord ze nooit zelf of met aannames. De eerste ronde levert alle
   vragen die kunnen spelen (voor een dakkapel 10 ja/nee-vragen: dakbedekking rondom, boven de nok,
   monument, voorkant, dakvlak naar openbaar gebied, plat dak, hoogte, afstanden tot dakvoet, nok en
   dakrand); stel ze samen of in een paar groepen. Beantwoorde vragen worden niet gemarkeerd: houd zelf bij
   wat al gevraagd is en stel geen vraag twee keer.
3. Volgende ronde met alle antwoorden tot nu toe in één lijst `{id, antwoord}`: `id` als getal, ja/nee als
   `"true"`/`"false"`, een keuze als de tekst van de optie. Nieuwe vragen kunnen volgen.
4. Klaar als elke `conclusie[i]` een waarde heeft: 'Vergunningplicht', 'Toestemmingsvrij', 'Neem contact op
   met' (de gemeente moet het beoordelen) of 'Niet van toepassing' (die check geldt hier niet; geen oordeel
   over de vraag). Meestal na twee rondes. De vorm van `vraagIds` kan per ronde verschillen (een lijst per
   activiteit of één lijst). `aanvragenVoor[i]` is de activiteit waarvoor men dan aanvraagt of meldt.

De artikelen uit het omgevingsplan (`owArtikelen`, `owTeksten`) horen bij de gemeentelijke activiteit; ze
kunnen algemener zijn dan de vraag. De rijksregels uit het Besluit bouwwerken leefomgeving staan er niet in;
de vergunningcheck van het Rijk wel.

**wat-verandert-hier**: `ontwerpen`, `typen`, `eindeInzage`, `wijzigingenArtikelen` en `wijzigingenTekst`
zijn parallel. Een ontwerp is nog geen recht; tot en met `eindeInzage` kan iedereen een zienswijze
indienen. De wijzigingen noemen alleen de bewerking per onderdeel (`toevoegen`, `verwijderen`), niet de
tekst: tel ze hoogstens. Programma's en visies van provincie of Rijk (bijvoorbeeld de Nota Ruimte) gelden
voor grote gebieden en zeggen weinig over deze plek; noem eerst wat de gemeente wijzigt. `toekomstigGeldend`
en `wroInProcedure` zijn paren van titel en datum of soort.

**verzoek-voorbereiden**: `toestemming` is verplicht: `Vergunning`, `Melding`, `Informatie`,
`InformatieOngewoonVoorval` of `AanvraagMaatwerkvoorschrift`. In `antwoorden` is `id` hier tekst, niet een
getal zoals bij `dakkapel-hier`. `zoekterm` moet specifiek zijn (bijvoorbeeld `boom kappen`). Een brede
term (`bouwen`) levert veel `kandidaten` en stopt: kies er met de gebruiker één en zoek gerichter.
**Controleer of de gekozen `activiteit` bij de vraag past**: 'bed and breakfast' leverde een
ontgrondingsactiviteit van het Rijk op. Past ze niet, gebruik de uitvoer dan niet en zeg dat het stelsel
geen activiteit voor de term vond. Een term die het stelsel voor de gemeente niet kent, levert niets;
probeer een synoniem, of voor bouwactiviteiten `dakkapel-hier`. `indienbaar` false met `verplichteVragen`:
antwoorden aanvullen (`antwoordenAlgemeneSet`, `antwoordenActiviteit`) en opnieuw. De werkstroom dient nooit
iets in.

**Peildatum** (de toestand op een eerdere datum):
1. `documenten-op-peildatum` met `rdX`, `rdY`, `peildatum` → `typen`, `titels`, `uriIdentificaties`
   (parallel). Het DSO levert voor elke datum in het verleden ook een vaste reeks latere documenten volgens
   de Omgevingswet. Een document waarvan het jaar in de `uriIdentificatie`
   (`_akn_nl_act_<organisatie>_<jaar>_...`) na de peildatum ligt, gold toen niet: laat het weg. Vóór 1
   januari 2024 golden de bestemmingsplannen (`NL.IMRO...`); de Omgevingswet was toen nog niet in werking.
2. `regeling-detail` en `versiehistorie` met een `uriIdentificatie`, alleen voor documenten volgens de
   Omgevingswet (niet voor bestemmingsplannen of structuurvisies).
3. `regels-op-peildatum` met `uriIdentificatie`, `rdX`, `rdY`, `peildatum` → de activiteiten op het punt en
   de `regeltekstWIds`. Bij een omgevingsplan zijn dat honderden regels: kies de wIds die bij de vraag
   horen.
4. `ow-tekst-ophalen` met dezelfde `uriIdentificatie`, een `wId` precies zoals geleverd en **dezelfde**
   `peildatum`; zonder peildatum bestaat een wId van een oudere versie niet.

### 7.7 Het antwoord presenteren

Eerst het antwoord, dan de bron: document (titel), artikel en datum. Bij een vergunningcheck: de conclusie
per activiteit en de antwoorden waarop ze berust. Zeg dat het informatie uit het DSO is op de dag van de
aanroep, geen besluit, en dat het Omgevingsloket en de gemeente de officiële bron zijn.

Nog niet nagemeten: de keten `regels-op-peildatum` → `ow-tekst-ophalen` voor een omgevingsplan (aantal
wIds) en andere activiteiten dan een dakkapel in de vergunningcheck.

---

## 8. Ondergrond: subsurface-models

### 8.1 Bereik

REGIS II (lagen) en GeoTOP (voxels). Toolnamen beginnen met `subsurface-models.`. Resultaten zijn
modelbewijs, nooit een oordeel. De data zijn voxel- en rastermodellen, geen featuretypes: er is geen tool
voor ruwe data; elke datatool is een stored query of processing.

### 8.2 Model: categorieën

| Categorie | Betekenis |
|---|---|
| Ruwe data | Eén featuretype van één dataset; filteren en de respons beperken. |
| Stored query | Een veelgestelde vraag met eenvoudiger parameters; nog steeds featuredata. |
| Processing | *Aggregatie* (featuredata plus telling, som) of *workflow* (gekoppelde stappen onder een versiegebonden methode). |
| Plot | Geeft een afbeelding, geen data. |
| Informatiemodel | Wat een modelelement betekent en hoe elementen zich verhouden; geen modeldata. |
| Methoden en herkomst | Wat de server berekent en hoe, en welke modellen hij bevat. |

### 8.3 Welke tool voor welke vraag

| Tool | Categorie | Toelichting |
|---|---|---|
| `trace` | Stored query | Verticale kolom op een punt (REGIS II-eenheden, GeoTOP-voxels). Optioneel `minDepth`/`maxDepth` (m onder het maaiveld van het model); meldt wat is weggelaten. |
| `section` | Stored query | Verticale doorsnede langs een lijn. Optioneel `elevationTop`/`elevationBottom` (m NAP). Begrensd, met een `window`. |
| `layers` | Stored query | Lagen die een hoogte-interval (m NAP) op een punt overlappen. |
| `area-summary` | Processing (aggregatie) | Aandeel van een gebied (willekeurig polygoon) dat door een GeoTOP-lithoklasse wordt ingenomen, over een dieptebereik, in één aanroep, uit het 2D-celraster. Kansen, alleen GeoTOP; vervolgpagina's bij grote gebieden. |
| `band-confinement` | Processing (workflow) | Of door de aanroeper opgegeven afdekkende lithoklassecodes elke bemonsterde bin van een doorsnede overspannen. De codes zijn van de aanroeper; de server hanteert geen eigen regels. |
| `trace-plot`, `section-plot` | Plot | De trace of doorsnede als PNG. |
| `concepts.schemes` | Informatiemodel | Catalogi achter de server (GTM, HGM, SM). |
| `concepts.lookup` | Informatiemodel | Betekenis van een GeoTOP- of REGIS II-term. |
| `model.search` | Informatiemodel | Een element vinden als de naam onbekend is. Eerst gebruiken. |
| `model.describe` | Informatiemodel | Element met attributen, relaties en identificaties. |
| `model.gaps` | Informatiemodel | Wat de semantische laag niet uitdrukt. |
| `methods.list`, `methods.describe` | Methoden en herkomst | Methoden met versie, invoer, aannames en grenzen; lees `methods.describe` voordat je op een resultaat vertrouwt. |
| `bundle.list` | Methoden en herkomst | Modellen in de ingestelde bundel (niet de catalogi). |

Kiezen: onbekende term → `model.search`, dan `model.describe` of `concepts.lookup`. Eén plaats → `trace`; een
lijn → `section`; één diepte-interval op een plaats → `layers`. Hoeveel van een gebied een lithoklasse is →
`area-summary`. Een plaatje → `trace-plot` of `section-plot`. Hoe een resultaat is gemaakt →
`methods.describe`.

### 8.4 Valkuilen

- **Bewijs, geen oordeel.** Geef lithoklasse of kans weer zoals het model hem geeft; "slappe bodem" of
  "afdekkend" is de definitie van de aanroeper, die je doorgeeft.
- **Aggregeer in één aanroep, nooit met een lus.** Voor een aandeel over een gebied `area-summary`, niet
  `trace` per cel.
- **Dieptereferentie.** `trace`-dieptes zijn m onder het maaiveld van het model; `section` en `layers`
  gebruiken m NAP. Meet de vraag vanaf AHN-maaiveld of NAP: reken expliciet om en meld verschillen, verberg
  ze niet.
- **Pagineer en zeg dat.** `window` (`total`, `returned`, `truncated`): verzamel alle vensters vóór je rekent,
  of meld dat je dat niet deed. Alleen GeoTOP geeft kansen; REGIS II levert eenheden.

---

## 9. Grondwater: groundwater-monitoring

### 9.1 Bereik

Toolnamen beginnen met `groundwater-monitoring.`. Bron: BRO GMW (putten), GLD (standreeksen), GMN
(meetnetten).

### 9.2 Model: categorieën

Ruwe data (één featuretype, geen interpretatie), Stored query, Processing, **Datavoorbereiding en kwaliteit**
(maakt van ruwe waarnemingen een analyseklare reeks of beoordeelt er een, onder een benoemde, versiegebonden
regelset), Plot, Informatiemodel.

### 9.3 Welke tool voor welke vraag

| Tool | Categorie | Toelichting |
|---|---|---|
| `wells.get` | Ruwe data (GMW) | Eén put op BRO-id: alle buizen, constructie en filterinterval waar gemeld. Een ontbrekende positie wordt als ontbrekend gemeld, nooit afgeleid. |
| `networks.get` | Ruwe data (GMN) | Eén meetnet op BRO-id, huidige geregistreerde situatie. |
| `networks.list` | Ruwe data (GMN) | BRO-id's van de meetnetten waarvoor een bronhouder verantwoordelijk is. |
| `series.get` | Ruwe data (GLD) | Waarnemingen van één GLD-onderzoeks-id, elk waarnemingstype, niet samengevoegd. Begrensd: hoogstens 500 waarden, `from`/`to` kiezen de periode, `window` meldt de afkap. |
| `tubes.search` | Stored query | Putten binnen een straal van een GeoJSON WGS84-punt, uitgewerkt naar buizen (GMW) met afstand, filterdiepte en geregistreerde GLD-reeksen. Nabijheid is geen relevantie. |
| `series.daily` | Datavoorbereiding (workflow) | Representatieve dagstand van één buis over al zijn GLD's, regel `noon-closest-priority-v1`. NAP, hoogstens 90 dagen, `window` meldt de afkap. |
| `series.assess` | Datavoorbereiding (workflow) | Voegt de reeksen van een buis samen en beoordeelt ze tegen `series-quality-v3`. `full=true` voegt de kalibratiewaarden toe voor server-naar-serveraanroepers. |
| `series.plot` | Plot | De `series.daily`-reeks als afbeelding. |
| `concepts.schemes`, `concepts.lookup` | Informatiemodel | BRO-domeintabellen; betekenis van een BRO-code of statuswaarde. |
| `model.search`, `model.describe`, `model.gaps` | Informatiemodel | Entiteit vinden (eerst), beschrijven, wat de semantische laag niet uitdrukt. |

Geen enkele tool hier is al een aggregatietool. Kiezen: onbekende term of code → `model.search`; putten bij
een plaats → `tubes.search`; één put volledig → `wells.get`; standen van één buis → `series.daily` voor de
analyseklare reeks, `series.get` voor de ruwe waarnemingen, `series.assess` voor geschiktheid; een plaatje →
`series.plot`.

### 9.4 Valkuilen

- **Nabijheid is geen relevantie.** Een buis binnen de genoemde afstand is een kandidaat; filterdiepte en
  eenheid (freatisch of niet) moeten nog bij de vraag passen.
- **De dekkingsregel in de vraag** (jaren, aandeel dagen, gatlengte) is niet de kwaliteitsregelset van de
  server (`series.assess` gebruikt 8 jaar); zeg welke de doorslag gaf.
- **`series.daily` is begrensd op 90 dagen per aanroep**; vijf jaar betekent pagineren en alle vensters
  verzamelen vóór je rekent.
- **Gemeten en gemodelleerd mengen nooit stilzwijgend**; label elke reeks met zijn bron.

---

## 10. Virtuele grondwaterstanden: virtual-groundwater-heads

### 10.1 Bereik

Toolnamen beginnen met `virtual-groundwater-heads.`. Alles wat hier wordt geproduceerd is **afgeleid**,
nooit gemeten, en draagt zijn methode, versie en invoer. De brondata komen van groundwater-monitoring en
subsurface-models. Documentatie komt ook als resources (`groundwater://rules/...`,
`groundwater://methods/...`, `groundwater://apis/knmi`, `groundwater://project/information-model`), te lezen
via `resources/read`.

### 10.2 Welke tool voor welke vraag

| Tool | Categorie | Toelichting |
|---|---|---|
| `meteo.stresses` | Stored query | KNMI-dagneerslag (`RH`) en Makkink-verdamping (`EV24`) voor een locatie en periode; gekozen en overgeslagen stations worden gemeld. |
| `tubes.subsurface` | Processing (workflow) | Het filter van een buis geplaatst in REGIS II-eenheden en GeoTOP-voxels (putmetadata plus `subsurface-models.trace`). Bewijs, geen oordeel. |
| `tubes.select` | Processing (workflow) | Of een buis relevant bewijs is voor een doel en een door de aanroeper gegeven diepte, onder `tube-selection-v1`. |
| `tubes.geotop-confinement` | Processing (workflow) | Laterale GeoTOP-klei/veen-continuïteit tussen een doel en het filter van een buis (`geotop-lateral-confinement-v1`). |
| `series.tfn` | Processing (workflow) | Transfer-functie-ruismodel van één buis via pastas, beoordeeld tegen `tfn-acceptance-v1`. Vereist de Python-runner. |
| `analysis.residual-dynamics` | Processing (workflow) | METRAN over de TFN-residuen van drie of meer buizen; de wetenschappelijke route. |
| `analysis.common-dynamics` | Processing (workflow) | Alleen als basislijn: METRAN over aangeleverde gemeten reeksen. |
| `estimate.series` | Processing (workflow) | Virtuele dagelijkse standenreeks op een locatie (`estimation-v2`), met ruimtelijke basislijn en benaderde band. |
| `estimate.plot` | Plot | Een bestaand `estimate.series`-resultaat als SVG. |
| `concepts.schemes`, `concepts.lookup`, `model.search`, `model.describe`, `model.gaps` | Informatiemodel | De VGH-catalogus en afgeleide concepten (zelf geschreven, voorlopig; geen MIM-model erachter). |

Geen tool hier is ruwe data of aggregatie. Kiezen: betekenis van een afgeleide waarde → `model.search`,
`model.describe`, dan de methode-resource; welke buizen tellen voor een plaats en diepte → `tubes.select`
met `tubes.subsurface` en `tubes.geotop-confinement` als bewijs; stresses → `meteo.stresses`; de respons van
één buis → `series.tfn`; gedeelde dynamiek van meer buizen → `analysis.residual-dynamics`; een
standenreeks op een locatie → `estimate.series`, dan `estimate.plot`.

### 10.3 Valkuilen

Virtuele standen zijn afgeleid en een proof of concept: label ze zo en meng ze nooit stilzwijgend met
gemeten standen. `tubes.select` is voorzichtig en beslist niet of een filter freatisch is.

---

## 11. Bodem + grondwater gecombineerd

**Wat gebruiksgevallen gemeen hebben**

| Element | Gebruiksgeval 1 (buurten) | Gebruiksgeval 2 (panden) |
|---|---|---|
| Eenheid van analyse | CBS-buurt (polygoon) | BAG-pand (polygoon, punt) |
| Selectie en rangschikking uit een register | Verhard aandeel uit BGT, rangschikken, top 3 | Bouwjaar vóór 1970 uit BAG |
| Ondergrondindicator | Aandeel GeoTOP-voxels boven een kleikans, bovenste 5 m | Klei- of veenkans per voxel, bovenste 5 m, per pand |
| Grondwaterbewijs | geen | Gemeten freatische reeks binnen 50 m, anders gemodelleerd |
| Afgeleide indicator | Gecombineerde score van twee aandelen | Tijd onder een aangenomen stand (vijf maten) |
| Uitvoer | Gerangschikte JSON | Kaart, tabel per pand, tijdreeksplot, disclaimer |

**Regels die de volgorde eerlijk houden:** ondergrondtools zijn bewijs, geen oordeel; aggregeer in één
aanroep; let op de dieptereferentie; meng gemeten en gemodelleerd nooit stilzwijgend; nabijheid is geen
relevantie; de dekkingsregel van de vraag is niet die van de server; pagineer en zeg dat.

**Open punten** (door geen tool beantwoord; reken zelf, vraag, of meld als open):

| Punt | Waar het speelt |
|---|---|
| Registerdata (BAG, BGT, CBS, AHN) | Stap 1 en 2; AHN buiten deze servers |
| Puntsgewijze ondergrondsamenvatting voor veel objecten in één aanroep | Gebruiksgeval 2 vraagt één `trace` per pand |
| Indicatoren onder een stand op een reeks (vijf maten) | Stap 6 |
| Freatische geschiktheid van een filter voorbij match op diepte en eenheid | Stap 4; `tubes.select` beslist dit niet |
| Dekkingsregel uit de vraag (3 tot 5 hydrologische jaren, 90 % van de dagen, gaten > 7 dagen) | Stap 4; `series.assess` gebruikt 8 jaar |
| `series.daily` is begrensd op 90 dagen per aanroep | Stap 5 |
| Referentielijn en markering onder de stand in de plot; een kaart | Stap 8 |
| Definitie van de gecombineerde score | Stap 7; niet gedefinieerd in gebruiksgeval 1 |
| Inconsistente grens: gebruiksgeval 1 zegt P(klei) > 5 %, ander materiaal 10 % | Stap 0; bevestig met de gebruiker |
| Gebruiksgeval 1 zegt "wijk" waar het buurten rangschikt | Stap 0; bevestig de eenheid |

---

## 12. Het antwoord

- Eerst het antwoord met het getal en wat het telt: objecttype, statussen, gebied (met naam, niet alleen de
  code), de stand van de gegevens (uit de instructies van de server). Per eenheid waarden met eenheden, bron
  (gemeten of afgeleid), methode en versie, datadekking.
- Dan alleen de kanttekeningen die bij deze vraag horen. Is er een controle die je niet hebt gedaan (sloop,
  bronhouder, groottes), noem wat die zou opleveren en bied haar aan.
- Een antwoord van het DSO is informatie, geen besluit; de officiële bron is het Omgevingsloket of de
  gemeente. Herhaal een disclaimer uit de vraag.
- Wil de gebruiker het nagaan of uitbreiden: de aanroepen met hun argumenten, of de link uit het resultaat.
