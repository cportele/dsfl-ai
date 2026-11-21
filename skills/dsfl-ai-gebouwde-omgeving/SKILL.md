---
name: dsfl-ai-gebouwde-omgeving
description: >-
  Gebruik deze skill vóór de eerste aanroep van de MCP-servers van bag.ldproxy.net (BAG, BGT,
  Wijken en buurten, Postcodegebieden, DSO), bij elke vraag over de gebouwde omgeving in Nederland:
  adressen, gebouwen en woningen; wegen, groen, water, bomen en straatmeubilair; gemeenten, wijken,
  buurten en CBS-cijfers per postcode; en of iets mag of vergunningplichtig is op een adres
  (dakkapel, aanbouw, bed & breakfast, boom kappen), welke regels daar gelden of op een datum
  golden en welke plannen eraan komen (Omgevingswet). Zorgt dat tellingen, oppervlakten,
  veranderingen en regels kloppen met wat je erover zegt. English: use before the first call of the
  bag.ldproxy.net MCP servers for any question on Dutch addresses, buildings, homes, topography,
  area statistics, or what is allowed and which planning rules apply at an address.
---

# De gebouwde omgeving bevragen

Deze skill vult de instructies van de MCP-servers aan; die beschrijven het model, de parameters en
de valkuilen per API. Hier staat hoe je met de servers samen een vraag beantwoordt, en wat in
proeven met echte vragen tot verkeerde antwoorden leidde.

## De servers

| Server | Inhoud | Details |
|---|---|---|
| BAG | adressen, panden, verblijfsobjecten (woningen, winkels, ...), lig- en standplaatsen, met historie | [references/bag.md](references/bag.md) |
| BGT | de kaart op het niveau van straten en panden: wegen, groen, water, panden, inrichtingselementen, met historie | [references/bgt.md](references/bgt.md) |
| Wijken en buurten | namen, codes en grenzen van gemeenten, wijken en buurten (CBS 2026), **geen cijfers** | [references/cbs.md](references/cbs.md) |
| Postcodegebieden | CBS-cijfers per postcode (PC6) op 1 januari 2024: inwoners, huishoudens, woningen | [references/cbs.md](references/cbs.md) |
| DSO | werkstromen over de regels van de Omgevingswet op een adres, live uit het DSO | [references/dso.md](references/dso.md) |

- Lees het referentiebestand van een server voor de eerste aanroep van die server in een gesprek.
- **Dezelfde toolnaam op meer servers**: `process_aggregate-features` (BAG, BGT, Postcodegebieden)
  en `collection_pand` (BAG en BGT). Kies de server waarvan je de gegevens bedoelt; een BAG-collectie
  in de BGT-tool geeft een fout.
- Elke server bevat een uittreksel; de instructies zeggen welk. Ligt een vraag erbuiten, zeg dan dat
  de gegevens daar ontbreken, niet dat er niets is of dat een adres niet bestaat.

## Soorten tools

| Soort | Tools | Gebruik voor | Niet voor |
|---|---|---|---|
| Collectie | `collection_*` | één objecttype: opzoeken op identificatie of eigenschap, filteren (CQL2), een eerdere toestand (`datetime`) | tellen of optellen; een vraag waarvoor een zoekopdracht bestaat |
| Zoekopdracht | `query_*` | een vaste vraag, vaak over meer objecttypen samen, met passende standaarden (zoals de status) | een eerdere toestand (geen `datetime`); tellen |
| Berekening | `process_aggregate-features`, `process_nearest-features` | tellen, optellen, gemiddelden, verdelen per groep; de dichtstbijzijnde objecten met afstand. De `source` is een collectie of een zoekopdracht met haar parameters | de objecten zelf bekijken |
| Werkstroom | `process_pand-bij-adres` (BAG), alle tools van DSO | een vaste reeks aanroepen, bij DSO live naar het DSO: enkele seconden tot een halve minuut, soms in rondes | eigen combinaties; dezelfde aanroep herhalen |

- **Wat terugkomt**: collecties en zoekopdrachten leveren een GeoJSON-FeatureCollection met
  `features`, `numberReturned` en `nextOffset` voor de volgende pagina (Wijken en buurten en
  Postcodegebieden ook `numberMatched`). Een verwijzing is `{id, title}`. Levert een zoekopdracht
  meer objecttypen, dan heeft elk object zijn `objecttype`: splits daarop, niet op de volgorde.
- **Klein houden**: `limit` zo laag als de vraag het toelaat (standaard 10, hoogstens 5000);
  `limit` verhogen om "alles" te zien is bijna altijd fout, tel dan met een berekening. Vraag met
  `properties` of `weglaten` alleen wat nodig is, geen geometrie tenzij voor een kaart, een afstand
  of `clip`.
- **Gegevens doorgeven, niet doorlezen**: elk resultaat van een collectie of zoekopdracht begint met
  een link naar dezelfde aanvraag in de HTTP-API, en een te groot resultaat geeft een fout met die
  link. Voor een kaart, een bestand of een grafiek geef je de link door; de objecten gaan dan niet
  door het gesprek.
- **Werkstroom in rondes**: geeft een werkstroom vragen terug in plaats van een antwoord, stel ze
  letterlijk aan de gebruiker; beantwoord ze nooit zelf en neem niets aan. Roep de
  werkstroom opnieuw aan met alle antwoorden tot nu toe, want de server onthoudt niets. Zonder
  gebruiker (een taak zonder dialoog): geef het voorlopige antwoord en de open vragen. Details in
  [references/dso.md](references/dso.md).
- **Ketens**: naam → code → filter (stap 1 hieronder); adres → object → punt (voor DSO in het
  Rijksdriehoeksstelsel, `crs` EPSG:28992); lijst → detail (geef `uriIdentificatie`, `wId` en de
  peildatum letterlijk door). Onafhankelijke aanroepen tegelijk; nooit één aanroep per object, maar
  één met `filter: "... IN (...)"` of een berekening. Een fout 400 zegt wat aan de invoer niet klopt.

## Werkwijze

1. **Gebied → code.** Alle servers filteren op CBS-codes: gemeente `0307`, wijk `WK030701`, buurt
   `BU03070100`. Zoek de code met `collection_wijk` of `collection_buurt` (Wijken en buurten) met
   `gemeente` en `naam`. Namen zijn hoofdlettergevoelig en alleen binnen een gemeente uniek; geen
   treffer → `naam` met `*` (`*Hof*`) of `filter: "CASEI(naam) = CASEI('hof')"`. Een stadsdeel of
   nieuwbouwwijk bestaat vaak uit meer CBS-wijken: zoek `*Naam*`, noem alle treffers en tel samen
   wat erbij hoort (een bedrijventerrein met dezelfde naam is meestal geen woonwijk).
2. **Tellen, optellen, verdelen**: `process_aggregate-features` van de server met de gegevens, nooit
   de objecten ophalen. Een aanroep leest hoogstens 100.000 objecten; anders per collectie of per
   wijk splitsen. Een aanroep duurt 1 tot 5 seconden, een gemeentebrede telling in de BAG tot een
   minuut.
3. **Fouten**: een verbindingsfout of time-out één keer opnieuw proberen. Een fout 502/503/504 of
   een melding dat een document van `service.omgevingswet.overheid.nl` niet te lezen is: het DSO is
   niet bereikbaar, niet de invoer fout; probeer geen andere invoer en zeg het de gebruiker.

## Wat een antwoord verandert

### Het getal past bij de definitie die je noemt

Een woning is in de BAG een verblijfsobject met gebruiksdoel woonfunctie. De collecties en
`process_aggregate-features` leveren **alle statussen**, ook in aanbouw ('Verblijfsobject
gevormd'), ingetrokken en ten onrechte opgevoerd. Kies de statussen bewust en noem ze. Standaard
voor "woningen": `filter: "status IN ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet
ingemeten)','Verbouwing verblijfsobject')"`; noem woningen in aanbouw apart als ze ertoe doen (in
een nieuwbouwwijk honderden). Zeg je "in gebruik", dan moet het getal uit dat filter komen; een
telling zonder statusfilter is nooit "in gebruik". Een deelvraag ("waarvan sinds 2015 gebouwd")
gebruikt hetzelfde filter, plus `bouwjaarPand`.

### Veranderingen: vergelijk twee toestanden

"Hoeveel woningen zijn erbij gekomen sinds 2015?" is de toestand nu min de toestand op 1 januari
2015: twee aanroepen met hetzelfde gebied en dezelfde definitie, één met `"datetime":
"2015-01-01"` in `source.parameters`. Tellen op `bouwjaarPand` ≥ 2015 is geen antwoord daarop: het
mist woningen die in oudere panden zijn gemaakt (kantoren en winkels omgebouwd, woningen gesplitst)
en negeert wat verdwenen is. In oude stadsdelen is dat het grootste deel; het verschil kan een
factor vier zijn. Geef het netto verschil en noem het aantal in nieuwbouw hoogstens als deel
daarvan. De zoekopdrachten (`query_*`) kennen geen `datetime`; de collecties en
`process_aggregate-features` wel. BGT: zie [references/bgt.md](references/bgt.md) over het begin van
de historie en bulkbewerkingen.

### Een geregistreerde gebeurtenis is niet altijd wat er gebeurd is

- **'Pand gesloopt'** markeert ook een pand dat is samengevoegd met een buurpand en een pand dat
  nooit is gebouwd. Van de grotere panden (`grondoppervlakte` ≥ 50 m²) is in een binnenstad soms
  maar één op de acht echt gesloopt; de kleine zijn meestal schuren. Geef het aantal "als gesloopt
  geregistreerd", splits op grootte, en controleer de grote panden of bied die controle aan (de
  werkwijze staat in [references/bag.md](references/bag.md), "Sloop controleren").
- `beginGeldigheid` is de datum van de registratie, soms jaren na de gebeurtenis.
- **BGT**: veel versies van één bronhouder met hetzelfde `tijdstipRegistratie` zijn een
  bulkbewerking (correctie, herinwinning), geen verandering op straat.

### Oppervlakte in een gebied: `clip`

Een object hoort bij het gebied waarin een punt op zijn geometrie ligt. Een vijver of weg langs de
grens telt dan helemaal in de ene buurt en niet in de andere; voor water en grote wegen kan dat
tientallen procenten schelen. Voor elke oppervlakte of elk aandeel van een buurt of wijk, en rond
een punt:

1. de grens: `collection_buurt` (of `collection_wijk`) met de code, met de volledige geometrie,
   zonder `zoom-level`: een vereenvoudigde grens verschuift de oppervlakte;
2. `process_aggregate-features` met `clip: {"geometry": <die geometrie>}` (of `{"point": [lon,
   lat], "distance": 250}`), `aggregates` met `{"function": "sum", "property": "$area"}`;
3. in `source.parameters` **`gemeentecode`, niet `buurtcode`**: het buurtfilter laat precies de
   objecten weg die van de buurt ernaast in de buurt steken. `clip` neemt alleen de objecten die het
   gebied snijden; de grens van 100.000 telt daarna.

Het resultaat met `clip` is de oppervlakte binnen het gebied; noem dat getal, niet de som van hele
objecten. Een aanroep met `clip` duurt een tot twee seconden.

### Geregistreerd is niet aanwezig

- **BGT-inrichtingselementen en IMGeo-plus** (bomen, banken, lichtmasten, putten, speeltoestellen)
  zijn optioneel: groepeer eerst op `bronhouder`. Vaak komen ze vooral van de provincie (P...),
  het waterschap (W...) of het Rijk (L...) en dekt het aantal alleen hun wegen en terreinen, terwijl
  de gemeente er bijna geen registreert. Zeg "in de BGT geregistreerd" en wie ze bijhoudt.
- **CBS per postcode**: een ontbrekende waarde is 0 tot 4 of geheim, geen nul. Sommen zijn
  ondergrenzen; sommen van deelgroepen (leeftijden, huishoudtypen) vallen nog lager uit.
  Percentages tel je niet op; koop- en huurpercentages ontbreken zo vaak dat er geen aandeel per
  wijk uit volgt. Zie [references/cbs.md](references/cbs.md).
- **Wat de BAG niet heeft**: bewoners, namen van bedrijven, eigenaren, prijzen, energielabels.
  Woonboten (`ligplaats`) en woonwagens (`standplaats`) zijn geen verblijfsobjecten en ontbreken in
  elke telling van woningen; tel ze apart als de vraag ze kan bedoelen.

## Het antwoord

- Eerst het antwoord met het getal en wat het telt: objecttype, statussen, gebied (met naam, niet
  alleen de code), de stand van de gegevens (uit de instructies van de server).
- Dan alleen de kanttekeningen die bij deze vraag horen. Is er een controle die je niet hebt gedaan
  (sloop, bronhouder, groottes), noem wat die zou opleveren en bied haar aan.
- Een antwoord van het DSO is informatie, geen besluit; de officiële bron is het Omgevingsloket of
  de gemeente.
- Wil de gebruiker het nagaan of uitbreiden: de aanroepen met hun argumenten, of de link uit het
  resultaat.
