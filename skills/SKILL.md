---
name: dsfl-ai
description: >-
  Gebruik deze skill vóór de eerste aanroep van de MCP-servers voor Nederlandse ruimtelijke data:
  BAG, BGT, Wijken en buurten, Postcodegebieden, DSO (Omgevingswet), subsurface-models,
  groundwater-monitoring en virtual-groundwater-heads. Voor vragen over adressen, gebouwen, woningen,
  wegen, groen, water, bomen, buurten en CBS-cijfers per postcode; wat mag of vergunningplichtig is op
  een adres; en bodem, ondergrond (REGIS II, GeoTOP), klei of veen, peilbuizen en grondwaterstanden voor
  een gebied of pand, ook gecombineerd. Geeft de volgorde van analyse, de juiste tool per stap en de
  valkuilen waardoor tellingen, oppervlakten, diepten en herkomst (gemeten of afgeleid) kloppen. English:
  use before the first call of these Dutch geodata MCP servers (addresses, buildings, topography, area
  statistics, Omgevingswet rules, subsurface, groundwater levels).
---

# Ruimtelijke vragen oplossen met de dsfl-ai MCP-servers

De instructies van elke server beschrijven model, parameters en API-valkuilen; lees die. Deze skill
geeft de route van vraag naar antwoord en de fouten die in proeven tot verkeerde antwoorden leidden.

## 1. Servers en wat ze beantwoorden

| Server | Voor | Hoofdtools |
|---|---|---|
| **BAG** | adressen, panden, verblijfsobjecten (woningen, winkels), lig- en standplaatsen, historie | `process_aggregate-features`, `query_adres-op-postcode`, `query_adres-op-straat`, `process_pand-bij-adres`, `query_panden-in-gebied`, `query_verblijfsobjecten-in-gebied`, `process_nearest-features`, `collection_<type>` |
| **BGT** | topografie: wegen, groen, water, panden, inrichtingselementen, historie | `process_aggregate-features` (met `clip`), `query_wegen-in-gebied`, `query_inrichtingselementen-in-gebied`, `query_wat-ligt-hier`, `query_wijzigingen-in-gebied`, `collection_<type>` |
| **Wijken en buurten** | namen, codes, grenzen van gemeente/wijk/buurt (CBS 2026), **geen cijfers** | `collection_gemeente`, `collection_wijk`, `collection_buurt` |
| **Postcodegebieden** | CBS-cijfers per PC6 (1-1-2024): inwoners, huishoudens, woningen | `collection_postcode6`, `process_aggregate-features` |
| **DSO** | regels van de Omgevingswet op een adres, live | werkstromen `regels-over-wonen`, `dakkapel-hier`, `wat-verandert-hier`, `verzoek-voorbereiden`, `documenten-op-peildatum`, `regels-op-peildatum`, `ow-tekst-ophalen`, `regeling-detail`, `versiehistorie` |
| **subsurface-models** | REGIS II-lagen, GeoTOP-voxels | `subsurface-models.` `trace`, `section`, `layers`, `area-summary`, `band-confinement`, `trace-plot`, `section-plot` |
| **groundwater-monitoring** | BRO GMW/GLD/GMN: putten, buizen, standreeksen | `groundwater-monitoring.` `tubes.search`, `wells.get`, `series.daily`, `series.get`, `series.assess`, `series.plot`, `networks.get` |
| **virtual-groundwater-heads** | afgeleide standen waar geen bruikbare buis is | `virtual-groundwater-heads.` `tubes.select`, `tubes.subsurface`, `tubes.geotop-confinement`, `meteo.stresses`, `series.tfn`, `estimate.series`, `estimate.plot` |

- Dezelfde toolnaam bestaat op meer servers (`process_aggregate-features`, `collection_pand`): kies de server met de gegevens die je bedoelt.
- Elke server bevat een uittreksel (gebied, peildatum; zie de instructies). Ligt de vraag erbuiten: zeg dat de gegevens daar ontbreken, niet dat er niets is of dat een adres niet bestaat.
- Onbekende term of code in de ondergrond/grondwater-servers: eerst `model.search`, dan `model.describe` of `concepts.lookup`; raad geen lithoklassecodes. `methods.describe` zegt hoe een resultaat is gemaakt.

## 2. Algemene route (volgorde: goedkoop en registergebaseerd eerst)

1. **Definities vastleggen.** Schrijf elke term en drempel uit de vraag op (status, periode, kanskap, diepte, afstand, jaren, aangenomen stand). Het zijn parameters die je doorgeeft, nooit standaardwaarden van de server. Onduidelijk of inconsistent (wijk of buurt? 5 % of 10 %?): bevestig met de gebruiker.
2. **Gebied → code.** Alle servers filteren op CBS-codes: gemeente `0307`, wijk `WK030701`, buurt `BU03070100`. Zoek met `collection_wijk`/`collection_buurt` op `gemeente` en `naam`. Namen zijn hoofdlettergevoelig en alleen binnen een gemeente uniek; geen treffer → `naam` met `*` (`*Hof*`) of `filter: "CASEI(naam) = CASEI('hof')"`. Stadsdelen bestaan vaak uit meer wijken: noem alle treffers.
3. **Eenheden selecteren en rangschikken** in BAG/BGT/CBS (aantal ervoor en erna noemen), zodat dure ondergrond- en grondwaterstappen op zo min mogelijk eenheden draaien. Geometrie als GeoJSON WGS84 `[lengtegraad, breedtegraad]`.
4. **Tellen, optellen, verdelen** met `process_aggregate-features` van de juiste server, nooit objecten ophalen om te tellen. Hoogstens 100.000 objecten per aanroep (anders per collectie of wijk splitsen). Houd resultaten klein: `properties`/`weglaten` met alleen wat nodig is, geen geometrie tenzij voor kaart, afstand of `clip`. In zoekopdrachten **vervangt een eigen `weglaten`-lijst de standaardlijst**. Te groot resultaat: geef de link uit de tool door.
5. **Ondergrond** (indien gevraagd): gebiedsaandeel → één `area-summary` per eenheid (nooit `trace` per cel); punt/object → één `trace` met dieptebereik; laterale continuïteit → `section`/`band-confinement`; een interval op een plaats → `layers`.
6. **Grondwater** (indien standen gevraagd): `tubes.search` binnen de genoemde afstand → beoordeel elke buis op doel en filterdiepte (`wells.get`, `tubes.select`, `tubes.subsurface`) → dekking toetsen (`series.assess`). Voldoet een buis: **gemeten** (`series.daily`, max. 90 dagen per aanroep, dus pagineren; `series.get` voor ruwe waarnemingen). Anders **gemodelleerd** (`series.tfn`, `estimate.series`, gelabeld als proof of concept).
7. **Indicatoren afleiden** (duur onder een stand, langste reeks, aantal reeksen, maximale diepte): geen servertool doet dit; reken zelf uit de reeks, een gat langer dan de genoemde lengte is een onderbreking.
8. **Combineren/scoren** alleen met een formule uit de vraag of afgesproken met de gebruiker; anders componenten naast elkaar.
9. **Presenteren.** Zie §6. Plots: `trace-plot`, `section-plot`, `series.plot`, `estimate.plot`.

Schetsen: *gebieden rangschikken op ondergrondaandeel* = 1 → 2 → 3 → 5 (`area-summary` per eenheid) → 8 → 9. *Objecten toetsen aan een grondwaterstand* = 1 → 2 → 3 → 5 (`trace`) → 6 → 7 → 9. *Mag dit op dit adres* = `query_adres-op-postcode` (bestaat het adres?) → DSO-werkstroom.

## 3. Gebouwde omgeving: wat een antwoord verandert

**BAG**
- Een woning is een verblijfsobject met gebruiksdoel woonfunctie. Collecties en `process_aggregate-features` leveren **alle statussen** (ook in aanbouw, ingetrokken, ten onrechte opgevoerd); zoekopdrachten alleen bestaande objecten in gebruik. Kies statussen bewust en noem ze. Standaard "woningen": `status IN ('Verblijfsobject in gebruik','Verblijfsobject in gebruik (niet ingemeten)','Verbouwing verblijfsobject')`; woningen in aanbouw apart noemen als ze ertoe doen. "In gebruik" betekent dat het getal uit dat filter komt.
- Een deelvraag ("waarvan sinds 2015 gebouwd") gebruikt hetzelfde filter plus `bouwjaarPand`. Bouwjaar 9999 = onbekend (uitsluiten); oude jaren zijn geschat. Oppervlakte 999999 is geen waarde. `grondoppervlakteMin` 50 sluit schuren en garages uit. Gebruiksdoel is de vergunde functie, geen soort voorziening.
- Panden, verblijfsobjecten en oppervlakte geven verschillende beelden (een flat is één pand met veel woningen). Woonboten (`ligplaats`) en woonwagens (`standplaats`) zijn geen verblijfsobjecten: tel apart als de vraag ze kan bedoelen. De BAG heeft geen bewoners, bedrijfsnamen, eigenaren, prijzen of energielabels.
- Adressen: `query_adres-op-straat` vraagt de volledige straatnaam en de **woonplaats**, niet de gemeente. Geen resultaat: spelling via `collection_openbareruimte` met `*`. '(ingetrokken)' in een titel: zeg dat; huidige adressen ernaast zijn geen vervanging. Ingetrokken nevenadressen niet als extra woningen tellen.
- Gebiedsfilters: `gemeentecode`, `wijkcode`, `buurtcode`; meer codes met `filter: "wijkcode IN (...)"`; per gebied `groupBy: ["wijkcode","wijknaam"]`.

**Veranderingen = twee toestanden vergelijken.** "Erbij gekomen sinds 2015" = nu minus de toestand op 1-1-2015: twee aanroepen, zelfde gebied en definitie, één met `"datetime": "2015-01-01"` in `source.parameters`. Tellen op `bouwjaarPand` ≥ 2015 mist ombouw en splitsing en negeert wat verdween (factor vier verschil mogelijk). Geef het netto verschil, nieuwbouw hoogstens als deel. `query_*` kent geen `datetime`; collecties en `process_aggregate-features` wel. De toestand vlak vóór een wijziging: `collection_<type>` met `datetime` = dag vóór `beginGeldigheid`.

**Een geregistreerde gebeurtenis is niet altijd wat er gebeurd is.**
- 'Pand gesloopt' omvat ook samenvoeging met een buurpand en nooit gebouwd (grote panden ≥ 50 m²: soms maar 1 op 8 echt gesloopt). Meld "als gesloopt geregistreerd", splits op grootte en bied controle aan: status dag vóór `beginGeldigheid` ('Bouwvergunning verleend' = nooit gebouwd); verblijfsobjecten van die dag nu in een ander pand in gebruik = samenvoeging, 'ingetrokken' = echte sloop; `query_pand-met-inhoud` zonder verblijfsobjecten bij zo'n pand is het teken.
- `beginGeldigheid` is registratiedatum, soms jaren na de gebeurtenis. Een 'Bouwvergunning verleend' kan oud zijn: combineer met `sinds`.
- Hangt een antwoord af van één waarde of lijkt die onwaarschijnlijk: aggregeer op collectie `kenmerkinonderzoek` (`object IN ('<id>') AND inOnderzoek = true`, `groupBy: ["kenmerk"]`).

**BGT**
- Waarden exact opgeven zoals in de waardelijsten (spaties, kleine letters: `bgtFunctie=rijbaan lokale weg`); meerdere waarden via `filter=bgtFunctie IN ('fietspad','voetpad')`. `'recreatie: speeltuin'` verfijnt `'recreatie'`; alle soorten: `LIKE 'recreatie%'`. Onzeker welke waarde bij een begrip hoort: lees de waardelijst van de collectie.
- **Oppervlakte in een gebied: `clip`.** Een object hoort bij het gebied waarin een punt van zijn geometrie ligt; langs grenzen kan dat tientallen procenten schelen. Werkwijze: (1) grens met volledige geometrie via `collection_buurt`/`collection_wijk` (zonder `zoom-level`); (2) `process_aggregate-features` met `clip: {"geometry": <grens>}` (of `{"point":[lon,lat],"distance":250}`) en `aggregates: [{"function":"sum","property":"$area"}]` (`$length` voor lengte); (3) in `source.parameters` **`gemeentecode`, niet `buurtcode`**. Noem het geknipte getal.
- Verdeling van een gebied (aandeel groen/verhard/water): vlakken op maaiveld (`relatieveHoogteligging = 0`) bedekken het gebied zonder overlap; totaal = som van die vlakken met dezelfde `clip`. Collecties: wegdeel, ondersteunendwegdeel, begroeidterreindeel, onbegroeidterreindeel, waterdeel, ondersteunendwaterdeel, pand, overigbouwwerk, kunstwerkdeel, spoor. Groen = `begroeidterreindeel`; `onbegroeidterreindeel` met `erf` zijn tuinen en opritten: noem dat aandeel erbij. Bruggen, tunnels en functionele gebieden tellen niet mee.
- **Inrichtingselementen en IMGeo-plus** (bomen, banken, lichtmasten, putten) zijn optioneel en komen vaak van provincie (P…), waterschap (W…) of Rijk (L…): groepeer eerst op `["plusType","bronhouder"]` en zeg "in de BGT geregistreerd" en door wie; weinig geregistreerd ≠ weinig aanwezig. `plusFysiekVoorkomen` 'waardeOnbekend' kan een vijfde van het wegoppervlak zijn; `bgtFysiekVoorkomen` is volledig.
- Historie begint per bronhouder bij de eerste levering (meestal eind 2016); toename kan fijnere inwinning zijn. Aantal wijzigingen: `process_aggregate-features` met `source: {"query":"wijzigingen-in-gebied","parameters":{gebied,sinds,tot}}`, `aggregates:["count"]`, `groupBy ["$collection"]`; niet tellen via `objectBeginTijd` (mist beëindigde objecten). Veel versies van één bronhouder met hetzelfde `tijdstipRegistratie` = bulkbewerking, geen verandering op straat. Begin met een buurt of korte periode (grens 100.000).
- Koppelingen: adres → punt via BAG (`query_adres-op-postcode`) → `query_wat-ligt-hier` (`afstand` ≤ 100 m); `identificatieBAGPND` verwijst naar het BAG-pand.

**CBS**
- Wijken en buurten heeft geen inwoners of andere cijfers; cijfers per buurt (WOZ, inkomen) staan in geen van beide servers. BAG-aantallen zijn objecttellingen, geen CBS-statistiek.
- Postcodegebieden: aantallen op vijftallen afgerond, percentages op tientallen. **Een ontbrekende waarde is 0–4 of geheim, geen nul.** Sommen zijn ondergrenzen (zeg "minstens"; sommen van deelgroepen nog lager); `count` met eigenschap naast `count` zonder eigenschap laat zien hoeveel postcodes meetellen. Percentages en gemiddelden niet optellen; koop-/huurpercentages ontbreken te vaak voor een aandeel per wijk. Sorteren: filter eerst op `... IS NOT NULL`. Tel per wijk/buurt met `process_aggregate-features` `groupBy: ["wijkcode"]`; namen uit Wijken en buurten. RD-coördinaten voor DSO: argument `crs=http://www.opengis.net/def/crs/EPSG/0/28992` bij de BAG-tool.

**DSO (Omgevingswet)**
- Adres: postcode zonder spatie (`3811LM`) en huisnummer als **tekst**, zonder letter of toevoeging; de werkstroom vindt precies één BAG-adres. 422 op stap 'adres': controleer met `query_adres-op-postcode`; bestaat het, zeg dat de werkstroom dit adres niet aankan (niet dat het niet bestaat) en bied een adres zonder letter aan. Datums: `datum` is `dd-MM-jjjj`, `peildatum` is `jjjj-MM-dd`. `uriIdentificatie` met underscores zoals geleverd.
- Fouten: 502/503/504 of onleesbaar DSO-document → DSO niet bereikbaar; geen andere invoer proberen en nooit "er gelden geen regels" concluderen. 429 → werkstromen na elkaar, niet parallel. Een 404 'tijdreis' bij `regels-op-peildatum` is een antwoord (regeling gold toen niet).
- Uitvoer bestaat uit **parallelle lijsten** (zelfde positie hoort bij elkaar); `null` = geen waarde. Regelteksten zijn STOP-XML (`<Al>`, `<Li>`): geef gewone zinnen. Naast het omgevingsplan gelden oude bestemmingsplannen (Wro): noem beide. Een lege `wroBestemmingen` bij `regels-over-wonen` betekent niet dat wonen niet mag.
- `dakkapel-hier`: eerste ronde zonder `antwoorden`, `activiteit` kort (`dakkapel`); stel de vragen aan de gebruiker, beantwoord ze **nooit zelf**; volgende ronde met alle antwoorden `{id, antwoord}` (id als getal, ja/nee als `"true"`/`"false"`); klaar als elke `conclusie[i]` een waarde heeft ('Vergunningplicht', 'Toestemmingsvrij', 'Neem contact op met', 'Niet van toepassing' = geen oordeel).
- `verzoek-voorbereiden`: `toestemming` verplicht, `zoekterm` specifiek; controleer dat de gekozen activiteit bij de vraag past, anders gebruik de uitvoer niet. Dient nooit iets in.
- `wat-verandert-hier`: een ontwerp is nog geen recht; noem eerst wat de gemeente wijzigt, niet programma's van provincie of Rijk.
- Peildatum: `documenten-op-peildatum` (rdX, rdY, peildatum; laat documenten weg waarvan het jaar in de `uriIdentificatie` ná de peildatum ligt; vóór 2024 gold het bestemmingsplan) → `regels-op-peildatum` → `ow-tekst-ophalen` met een `wId` exact als geleverd en **dezelfde** `peildatum`.

## 4. Ondergrond en grondwater: wat een antwoord verandert

- **Bewijs, geen oordeel.** Geef lithoklasse of kans weer zoals het model hem geeft; "slappe bodem" of "afdekkend" is de definitie van de aanroeper, die je doorgeeft (bijv. confining-codes bij `band-confinement`).
- **Dieptereferentie.** `trace`-dieptes (`minDepth`/`maxDepth`) zijn m onder het maaiveld van het model; `section`/`layers` gebruiken m NAP. Meet de vraag vanaf AHN-maaiveld of NAP: reken expliciet om en meld verschillen.
- **Gemeten en gemodelleerd nooit stilzwijgend mengen**; label elke reeks en elk getal met bron, methode en versie. Virtuele standen zijn afgeleid en een proof of concept.
- **Nabijheid is geen relevantie**: een buis binnen de afstand is een kandidaat; filterdiepte en eenheid (freatisch of niet) moeten bij de vraag passen; `tubes.select` is voorzichtig en beslist dit niet.
- **Dekkingsregel van de vraag ≠ kwaliteitsregelset van de server** (`series.assess` gebruikt 8 jaar); zeg welke besliste. Ontbrekende positie wordt als ontbrekend gemeld, nooit afgeleid.
- **Pagineren.** `window` (`total`, `returned`, `truncated`) betekent onvolledig: verzamel alle vensters vóór je rekent, of meld dat je dat niet deed. `area-summary` heeft vervolgpagina's; `series.get` max. 500 waarden.
- Alleen GeoTOP geeft kansen (`area-summary`); REGIS II levert eenheden.

## 5. Fouten en grenzen

- Verbindingsfout of time-out: één keer opnieuw. Een mislukte aanroep is nooit "geen resultaat".
- Een aanroep duurt 1–5 s, gemeentebrede BAG-telling tot een minuut, DSO 1–4 s (tot 30 s bij herhaling).
- Wat geen server levert (open punten): puntsgewijze ondergrondsamenvatting voor veel objecten in één aanroep, indicatoren onder een stand, een kaart, referentielijn in plots, een gecombineerde score zonder gegeven formule. Reken zelf, vraag, of meld het als open.

## 6. Het antwoord

- Eerst het antwoord met het getal en wat het telt: objecttype, statussen, gebied (naam, niet alleen code), stand van de gegevens; per eenheid waarden met eenheden, bron (gemeten/afgeleid), methode en versie, datadekking.
- Dan alleen de kanttekeningen die bij deze vraag horen. Is er een controle die je niet deed (sloop, bronhouder, groottes), noem wat ze zou opleveren en bied haar aan.
- Een DSO-antwoord is informatie, geen besluit: de officiële bron is het Omgevingsloket of de gemeente. Herhaal een disclaimer uit de vraag.
- Wil de gebruiker nagaan of uitbreiden: geef de aanroepen met hun argumenten, of de link uit het resultaat.
