# Eigenschappen in de resultaten van de zoekopdrachten

Wat de eigenschappen in de resultaten van de zoekopdrachten betekenen, voor zover ze niet zijn
weggelaten (parameter `weglaten`). Elk object in een resultaat met meer objecttypen heeft zijn
objecttype (`objecttype`); splits daarop, niet op de volgorde.

Een verwijzing heeft een titel en, in een MCP-resultaat, de identificatie (`id`) of, in de API, een link (`href`); de titel van een ingetrokken adres, straat of woonplaats eindigt op '(ingetrokken)'.

## Per objecttype

- **pand**: oorspronkelijkBouwjaar (9999 betekent onbekend; bij oude panden vaak een geschat rond jaartal), status, beginGeldigheid (begin van de huidige versie), geometrie (het bovenaanzicht), op verzoek grondoppervlakte (m², berekend uit de geometrie).
- **verblijfsobject**: gebruiksdoel (alle gebruiksdoelen), oppervlakte (gebruiksoppervlakte in m²; 999999 is geen werkelijke oppervlakte), status, beginGeldigheid, heeftAlsHoofdadres en heeftAlsNevenadres (titel: het adres), maaktDeelUitVan (de panden), geometrie (een punt), bouwjaarPand (het oudste oorspronkelijk bouwjaar van die panden).
- **nummeraanduiding**: huisnummer, huisletter, huisnummertoevoeging, postcode (titel: de postcode, verwijst naar het postcodegebied in /postcode6), typeAdresseerbaarObject, status, ligtAan (titel: de straatnaam), ligtIn (alleen als de woonplaats afwijkt van die van de straat).
- **openbareruimte**: naam, type (bijvoorbeeld Weg of Water), status, ligtIn (titel: de woonplaats).
- **woonplaats**: naam, status.
- **ligplaats en standplaats**: heeftAlsHoofdadres (titel: het adres), status, geometrie (een vlak).

## Objecttypen per zoekopdracht

| Zoekopdracht | Objecttypen in het resultaat |
|---|---|
| `panden-in-gebied` | pand |
| `verblijfsobjecten-in-panden` | pand, verblijfsobject |
| `verblijfsobjecten-in-gebied` | verblijfsobject |
| `adres-op-postcode` | nummeraanduiding, openbareruimte, woonplaats, verblijfsobject, ligplaats, standplaats, pand |
| `adres-op-straat` | woonplaats, openbareruimte, nummeraanduiding, verblijfsobject, ligplaats, standplaats, pand |
| `verblijfsobjecten-in-de-buurt` | verblijfsobject |
| `pand-met-inhoud` | pand, verblijfsobject, nummeraanduiding, openbareruimte |
