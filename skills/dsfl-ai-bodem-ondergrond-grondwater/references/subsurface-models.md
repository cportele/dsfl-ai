# Ondergrondmodellen (mcp-subsurface-models)

REGIS II (lagen) en GeoTOP (voxels). Elke toolnaam begint met `subsurface-models.`. Resultaten zijn
modelbewijs, nooit een oordeel. Geometrie is GeoJSON, WGS84, `[lengtegraad, breedtegraad]`.

## Categorieën

De eerste drie volgen de categorisering die met collega's is afgesproken; de rest is toegevoegd voor deze servers.

| Categorie | Betekenis |
|---|---|
| **Ruwe data** | Eén featuretype van één dataset; filteren en de respons beperken. |
| **Stored query** | Een veelgestelde vraag met eenvoudiger parameters; nog steeds featuredata, mogelijk uit meer featuretypes. |
| **Processing** | Óf *aggregatie* (featuredata plus een telling, som, enz.) óf een *workflow* (gekoppelde stappen onder een versiegebonden methode). |
| **Plot** | Geeft een afbeelding, geen data. |
| **Informatiemodel** | Wat een modelelement betekent en hoe elementen zich verhouden. Beschrijft zichzelf; geen modeldata. |
| **Methoden en herkomst** | Wat de server berekent en hoe, en welke modellen hij bevat. |

## Tools

De data zijn voxel- en rastermodellen, geen featuretypes, dus er is geen tool voor *Ruwe data*: elke datatool is een stored query of processing.

| Tool | Categorie | Toelichting |
|---|---|---|
| `trace` | Stored query | Verticale kolom op een punt (REGIS II-eenheden, GeoTOP-voxels). Optioneel `minDepth`/`maxDepth` (m onder maaiveld van het model); meldt wat is weggelaten. |
| `section` | Stored query | Verticale doorsnede langs een lijn. Optioneel `elevationTop`/`elevationBottom` (m NAP). Begrensd, met een `window`. |
| `layers` | Stored query | Lagen die een hoogte-interval (m NAP) op een punt overlappen. |
| `area-summary` | Processing (aggregatie) | Aandeel van een gebied (willekeurig polygoon) dat door een GeoTOP-lithoklasse wordt ingenomen, over een dieptebereik, in één aanroep, uit het 2D-celraster. Kansen, alleen GeoTOP; vervolgpagina's bij grote gebieden. |
| `band-confinement` | Processing (workflow) | Of door de aanroeper opgegeven afdekkende lithoklassecodes elke bemonsterde bin van een doorsnede overspannen. De codes zijn van de aanroeper; de server hanteert geen eigen regels. |
| `trace-plot` | Plot | De trace als PNG. |
| `section-plot` | Plot | De doorsnede als PNG. |
| `concepts.schemes` | Informatiemodel | Catalogi achter de server (GTM, HGM, SM). |
| `concepts.lookup` | Informatiemodel | Betekenis van een GeoTOP- of REGIS II-term. |
| `model.search` | Informatiemodel | Een element vinden als de naam onbekend is. Eerst gebruiken. |
| `model.describe` | Informatiemodel | Element met attributen, relaties en identificaties. |
| `model.gaps` | Informatiemodel | Wat de semantische laag niet uitdrukt. |
| `methods.list` | Methoden en herkomst | Methoden met versie, invoer, aannames en grenzen. |
| `methods.describe` | Methoden en herkomst | Eén methode volledig. Lezen voordat je op een resultaat vertrouwt. |
| `bundle.list` | Methoden en herkomst | Modellen in de ingestelde bundel (niet de catalogi). |

## Kiezen

1. Onbekende term: `model.search`, dan `model.describe` of `concepts.lookup`.
2. Eén plaats: `trace`; een lijn: `section`; één diepte-interval op een plaats: `layers`.
3. Hoeveel van een gebied een lithoklasse is: `area-summary`. Loop niet met `trace` over een gebied.
4. Een plaatje: `trace-plot` of `section-plot`.
5. Hoe een resultaat is gemaakt: `methods.describe`.
