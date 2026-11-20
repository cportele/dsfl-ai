---
name: dsfl-ai-bodem-ondergrond-grondwater
description: >-
  Gebruik deze skill vóór de eerste aanroep van de MCP-servers subsurface-models, groundwater-monitoring
  en virtual-groundwater-heads, bij elke vraag over de Nederlandse bodem, ondergrond en grondwaterstand
  voor een gebied (buurt) of object (pand): lagen en lithoklassen (REGIS II, GeoTOP), het aandeel klei of
  veen in de bovenste meters, gemeten standen uit peilbuizen (BRO GMW, GLD, GMN), en geschatte
  grondwaterstanden waar geen bruikbare peilbuis is. Zorgt dat definities, dieptereferenties en de
  herkomst (gemeten of afgeleid) kloppen met wat je erover zegt. English: use before the first call of
  the subsurface-models, groundwater-monitoring and virtual-groundwater-heads MCP servers for any
  question on Dutch subsurface, soil and groundwater levels for an area or a building.
---

# Bodem, ondergrond en grondwater bevragen

Deze skill vult de instructies van de MCP-servers aan. Hier staat in welke volgorde je een vraag over
ondergrond en grondwater beantwoordt, welke tool welke stap dient, en welke regels voorkomen dat
bewijs als oordeel wordt gepresenteerd. Het is een eerste concept, afgeleid van `usecase-1.md` en
`usecase-3.md`; het beantwoordt die niet, maar legt de volgorde van analyse vast.

Afspraken voor alle servers: geometrie is GeoJSON, WGS84, `[lengtegraad, breedtegraad]`; standen zijn
in m NAP; resultaten zijn bewijs met methode, versie en invoer, nooit een oordeel; een begrensd
resultaat heeft een `window` (`total`, `returned`, `truncated`) en wordt gepagineerd, niet als
volledig vertrouwd.

## De servers

| Server | Inhoud | Details |
|---|---|---|
| subsurface-models | REGIS II (lagen) en GeoTOP (voxels): kolom op een punt, doorsnede, aandeel lithoklasse in een gebied | [references/subsurface-models.md](references/subsurface-models.md) |
| groundwater-monitoring | BRO GMW (putten en buizen), GLD (standreeksen), GMN (meetnetten); dagstanden en kwaliteitsbeoordeling | [references/groundwater-monitoring.md](references/groundwater-monitoring.md) |
| virtual-groundwater-heads | afgeleide standen: buisselectie, KNMI-stresses, TFN-modellen, virtuele standenreeks | [references/virtual-groundwater-heads.md](references/virtual-groundwater-heads.md) |

- Lees het referentiebestand van een server voor de eerste aanroep van die server in een gesprek.
- Toolnamen beginnen met de servernaam (`subsurface-models.trace`). Registergegevens (BAG, BGT, CBS,
  AHN) komen niet van deze servers maar uit de skill `dsfl-ai-gebouwde-omgeving`.

## Wat de gebruiksgevallen gemeen hebben

| Element | Gebruiksgeval 1 (buurten) | Gebruiksgeval 2 (panden) |
|---|---|---|
| Eenheid van analyse | CBS-buurt (polygoon) | BAG-pand (polygoon, punt) |
| Selectie en rangschikking uit een register | Verhard aandeel uit BGT, rangschikken, top 3 | Bouwjaar vóór 1970 uit BAG |
| Ondergrondindicator | Aandeel GeoTOP-voxels boven een kleikans, bovenste 5 m | Klei- of veenkans per voxel, bovenste 5 m, per pand |
| Grondwaterbewijs | geen | Gemeten freatische reeks binnen 50 m, anders gemodelleerd |
| Afgeleide indicator | Gecombineerde score van twee aandelen | Tijd onder een aangenomen stand (vijf maten) |
| Uitvoer | Gerangschikte JSON | Kaart, tabel per pand, tijdreeksplot, disclaimer |

Een vraag splitst zich in dezelfde stappen. Een gebruiksgeval verschilt in welke stappen nodig zijn,
niet in hun volgorde.

## Werkwijze

Doe de goedkope registerstappen eerst, zodat de dure ondergrond- en grondwaterstappen op zo min
mogelijk eenheden draaien.

| # | Stap | Wat je doet | Tools |
|---|---|---|---|
| 0 | **Definities vastleggen** | Schrijf elke drempel en term uit de vraag op (kanskap, diepte, afstand, jaren, gatlengte, aangenomen stand). Het zijn parameters die je doorgeeft, nooit standaardwaarden van de server. Zoek onduidelijke ondergrondtermen en lithoklassecodes (klei, veen, zandige klei) op in de modelcatalogus; raad geen codes. | `subsurface-models.model.search`, `.model.describe`, `.concepts.lookup` |
| 1 | **Eenheden en geometrie ophalen** | Haal buurt- of pandgeometrie en attributen (bouwjaar, verhard oppervlak, maaiveld) uit de registerservers; zet om naar GeoJSON WGS84. Valt buiten deze drie servers. | skill `dsfl-ai-gebouwde-omgeving` (BAG, BGT, CBS), AHN |
| 2 | **Filteren en rangschikken op registerattributen** | Pas de criteria zonder ondergrond toe en houd alleen de benodigde eenheden over (top N, vóór een jaar). Noem het aantal ervoor en erna. | skill `dsfl-ai-gebouwde-omgeving` |
| 3 | **Ondergrond karakteriseren** | Gebiedsvraag: één aanroep per eenheid. Punt- of objectvraag: één kolom per eenheid. Laterale continuïteit: een doorsnede. Geef het dieptebereik en de drempels uit stap 0 door. | `subsurface-models.area-summary`, `.trace`, `.layers`, `.section`, `.band-confinement` |
| 4 | **Grondwaterbron bepalen** (alleen als standen gevraagd zijn) | Zoek buizen binnen de genoemde afstand, beoordeel elke op doel en diepte, controleer de datadekking tegen de genoemde regel. Gemeten als een buis voldoet, anders gemodelleerd; leg vast welke en waarom. | `groundwater-monitoring.tubes.search`, `.wells.get`, `virtual-groundwater-heads.tubes.select`, `.tubes.subsurface`, `groundwater-monitoring.series.assess` |
| 5 | **Standenreeks ophalen** | Gemeten: dagreeks per buis, per periode gepagineerd. Gemodelleerd: virtuele standschatting, gelabeld als proof of concept. | `groundwater-monitoring.series.daily` (of `.series.get`), `virtual-groundwater-heads.series.tfn`, `.estimate.series` |
| 6 | **Indicatoren afleiden** | Bereken wat gevraagd is uit de reeks en de genoemde stand (duur, langste reeks, aantal reeksen, maximale diepte, getroffen jaren); een gat langer dan de genoemde lengte is een onderbreking. Geen servertool doet dit nu. | aan de agentkant, of een nieuwe tool |
| 7 | **Combineren en scoren** | Alleen met een formule uit de vraag of met de gebruiker afgesproken; anders de componenten naast elkaar tonen. | geen |
| 8 | **Presenteren** | Per eenheid: waarden met eenheden, bron, methode en versie, datadekking. Kaart en plots als gevraagd. Herhaal de disclaimer uit de vraag. | `subsurface-models.trace-plot`, `.section-plot`, `groundwater-monitoring.series.plot`, `virtual-groundwater-heads.estimate.plot` |

Voorgestelde reeksen (een schets, geen antwoorden):

- **Gebieden rangschikken op een ondergrondaandeel:** 0 → 1 → 2 → 3 (`area-summary` per eenheid, pagineren) → 7 → 8.
- **Objecten toetsen aan een grondwaterstand:** 0 → 1 → 2 → 3 (`trace` met dieptebereik per object) → 4 → 5 → 6 → 8.

## Wat een antwoord verandert

- **Ondergrondtools zijn bewijs, geen oordeel.** Een lithoklasse of kans geef je weer zoals het model
  hem geeft; "slappe bodem" of "afdekkend" is de definitie van de aanroeper, die je doorgeeft.
- **Aggregeer in één aanroep, nooit met een lus.** Voor een aandeel over een gebied gebruik je
  `area-summary`, niet `trace` per cel.
- **Let op de dieptereferentie.** `trace`-dieptes zijn meters onder het maaiveld van het model; een
  vraag die vanaf een AHN-maaiveld (of vanaf NAP) meet, vraagt om een expliciet genoemde en
  omgerekende referentie; meld verschillen, verberg ze niet.
- **Gemeten en gemodelleerd mengen nooit stilzwijgend.** Label elke standenreeks en elk getal met
  zijn bron.
- **Nabijheid is geen relevantie.** Een buis binnen de genoemde afstand is een kandidaat; filterdiepte
  en eenheid moeten nog bij de vraag passen (freatisch of niet).
- **Geschiktheidsregels verschillen.** De dekkingsregel in de vraag (jaren, aandeel dagen, gatlengte)
  is niet de kwaliteitsregelset van de server; zeg welke de doorslag gaf.
- **Pagineer en zeg dat.** Lange perioden en grote gebieden komen in vensters; verzamel alle vensters
  vóór je rekent, of meld dat je dat niet deed.

## Open punten

Door geen tool beantwoord; de agent rekent het zelf, vraagt het, of meldt het als open.

| Punt | Waar het speelt |
|---|---|
| Registerdata (BAG, BGT, CBS, AHN) | Stap 1 en 2; buiten deze servers |
| Puntsgewijze ondergrondsamenvatting voor veel objecten in één aanroep | Gebruiksgeval 2 vraagt één `trace` per pand |
| Indicatoren onder een stand op een reeks (vijf maten) | Stap 6 |
| Freatische geschiktheid van een filter voorbij match op diepte en eenheid | Stap 4; `tubes.select` is voorzichtig en beslist dit niet |
| Dekkingsregel uit de vraag (3 tot 5 hydrologische jaren, 90 % van de dagen, gaten > 7 dagen) | Stap 4; `series.assess` gebruikt een eigen regelset van 8 jaar |
| `series.daily` is begrensd op 90 dagen per aanroep | Stap 5; vijf jaar betekent pagineren |
| Referentielijn en markering onder de stand in de plot | Stap 8 |
| Een kaart | Stap 8 |
| Definitie van de gecombineerde score | Stap 7; niet gedefinieerd in gebruiksgeval 1 |
| Inconsistente grens: gebruiksgeval 1 zegt P(klei) > 5 %, ander materiaal 10 % | Stap 0; bevestig met de gebruiker |
| Gebruiksgeval 1 zegt "wijk" waar het buurten rangschikt | Stap 0; bevestig de eenheid |
