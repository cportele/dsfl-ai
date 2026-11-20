# Grondwatermonitoring (mcp-groundwater-monitoring)

Elke toolnaam begint met `groundwater-monitoring.`. Bron: BRO GMW (putten), GLD (standreeksen), GMN (meetnetten).

## Categorieën

| Categorie | Betekenis |
|---|---|
| **Ruwe data** | Eén featuretype van één dataset; filteren en, waar geboden, de respons beperken. Geen interpretatie. |
| **Stored query** | Een veelgestelde vraag met eenvoudiger parameters; nog steeds featuredata, mogelijk uit meer featuretypes. |
| **Processing** | Óf *aggregatie* óf een *workflow* (gekoppelde verzoeken op de achtergrond, onder een versiegebonden regel). |
| **Datavoorbereiding en kwaliteit** | Maakt van ruwe waarnemingen een analyseklare reeks, of beoordeelt er een, onder een benoemde, versiegebonden regelset. |
| **Plot** | Geeft een afbeelding, geen data. |
| **Informatiemodel** | Wat een term, code of entiteit betekent en hoe elementen zich verhouden. |

## Tools

| Tool | Categorie | Toelichting |
|---|---|---|
| `wells.get` | Ruwe data (GMW) | Eén put op BRO-id: alle buizen, constructie en filterinterval waar gemeld. Een ontbrekende positie wordt als ontbrekend gemeld, nooit afgeleid. |
| `networks.get` | Ruwe data (GMN) | Eén meetnet op BRO-id, huidige geregistreerde situatie. |
| `networks.list` | Ruwe data (GMN) | BRO-id's van de meetnetten waarvoor een bronhouder verantwoordelijk is. |
| `series.get` | Ruwe data (GLD) | Waarnemingen van één GLD-onderzoeks-id, elk waarnemingstype, niet samengevoegd. Begrensd: hoogstens 500 waarden, `from`/`to` kiezen de periode, `window` meldt de afkap. |
| `tubes.search` | Stored query | Putten binnen een straal van een GeoJSON WGS84-punt, uitgewerkt naar buizen (GMW) met afstand, filterdiepte en geregistreerde GLD-reeksen. Nabijheid is geen relevantie. |
| `series.daily` | Datavoorbereiding en kwaliteit (workflow) | Representatieve dagstand van één buis over al zijn GLD's, regel `noon-closest-priority-v1`. NAP, hoogstens 90 dagen, `window` meldt de afkap. |
| `series.assess` | Datavoorbereiding en kwaliteit (workflow) | Voegt de reeksen van een buis samen en beoordeelt ze tegen `series-quality-v3`. `full=true` voegt de kalibratiewaarden toe voor server-naar-serveraanroepers. |
| `series.plot` | Plot | De `series.daily`-reeks als afbeelding. |
| `concepts.schemes` | Informatiemodel | BRO-domeintabellen die de conceptopzoeking kent. |
| `concepts.lookup` | Informatiemodel | Betekenis van een BRO-code of statuswaarde. |
| `model.search` | Informatiemodel | Een entiteit of term vinden als de exacte naam onbekend is. Eerst gebruiken. |
| `model.describe` | Informatiemodel | Eén entiteit met attributen, onderdelen, associaties en wat ernaar verwijst. |
| `model.gaps` | Informatiemodel | Wat de semantische laag niet uitdrukt. |

Geen enkele tool hier is al een *Processing (aggregatie)*-tool.

## Kiezen

1. Onbekende term of code: `model.search`, dan `model.describe` of `concepts.lookup`.
2. Putten bij een plaats: `tubes.search`; één put volledig: `wells.get`.
3. Standen van één buis: `series.daily` voor de analyseklare reeks, `series.get` voor de ruwe waarnemingen, `series.assess` voor geschiktheid.
4. Een plaatje: `series.plot`.
