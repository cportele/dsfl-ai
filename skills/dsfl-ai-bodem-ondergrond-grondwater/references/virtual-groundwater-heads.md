# Virtuele grondwaterstanden (mcp-virtual-groundwater-heads)

Elke toolnaam begint met `virtual-groundwater-heads.`. Alles wat hier wordt geproduceerd is **afgeleid**, nooit gemeten, en draagt
zijn methode, versie en invoer. De brondata komen van `mcp-groundwater-monitoring` en `mcp-subsurface-models`.

## Categorieën

| Categorie | Betekenis |
|---|---|
| **Ruwe data** | Eén featuretype van één dataset. |
| **Stored query** | Een veelgestelde vraag met eenvoudiger parameters; nog steeds brondata (hier KNMI). |
| **Processing** | Óf *aggregatie* óf een *workflow* (gekoppelde verzoeken aan de zusterservers en de Python-runner, onder een versiegebonden regelset). |
| **Plot** | Geeft een afbeelding, geen data. |
| **Informatiemodel** | Wat de afgeleide concepten betekenen en hoe ze ketenen. Zelf geschreven, voorlopig; geen MIM-model erachter. |

## Tools

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
| `concepts.schemes` | Informatiemodel | De VGH-catalogus. |
| `concepts.lookup` | Informatiemodel | Een afgeleid concept op exacte naam. |
| `model.search` | Informatiemodel | Een concept vinden op naam of definitie. |
| `model.describe` | Informatiemodel | Concept met waarvan het is afgeleid en wat ervan is afgeleid. |
| `model.gaps` | Informatiemodel | Wat de concepten niet stellen (zelf geschreven; externe bronnen). |

Documentatie komt ook als resources (`groundwater://rules/...`, `groundwater://methods/...`, `groundwater://apis/knmi`,
`groundwater://project/information-model`), te lezen via `resources/read`.

Geen enkele tool hier is *Ruwe data*, en geen enkele is *Processing (aggregatie)*.

## Kiezen

1. Betekenis van een afgeleide waarde: `model.search`, `model.describe`, dan de relevante methode-resource.
2. Welke buizen tellen voor een plaats en diepte: `tubes.select`, met `tubes.subsurface` en `tubes.geotop-confinement` als bewijs.
3. Stresses voor een periode: `meteo.stresses`.
4. De respons van één buis: `series.tfn`; gedeelde dynamiek van meer buizen: `analysis.residual-dynamics`.
5. Een standenreeks op een locatie: `estimate.series`, dan `estimate.plot`.
