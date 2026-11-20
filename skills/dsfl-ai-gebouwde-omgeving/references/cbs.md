# CBS: Wijken en buurten, Postcodegebieden

Twee servers met gegevens van het CBS:

- **Wijken en buurten**: de gemeenten, wijken en buurten volgens de Wijk- en Buurtkaart 2026 met
  naam, code en grens. **Geen inwoners of andere cijfers.**
- **Postcodegebieden**: statistiek per postcode (PC6) op 1 januari 2024: inwoners naar geslacht,
  leeftijd en herkomst, huishoudens, woningen naar bouwjaar en eigendom, uitkeringen.

Wat beide servers bevatten, staat in hun instructies. Cijfers per buurt of wijk (inwoners,
WOZ-waarde, inkomen) uit de Kerncijfers wijken en buurten van het CBS zitten in geen van beide.

## Wijken en buurten

- `collection_gemeente`, `collection_wijk`, `collection_buurt`. De code is de id van het object;
  `wijk` en `gemeente` van een buurt zijn verwijzingen met de naam als titel.
- **Namen zijn hoofdlettergevoelig** (`Hof` vindt de buurt, `hof` niets). Geen treffer: `naam` met
  `*` (`*Hof*`) of `filter: "CASEI(naam) = CASEI('hof')"`, voordat je zegt dat het gebied niet
  bestaat. Veel buurten heten naar een straat met 'e.o.' (`Kersenbaan e.o.`): zoek met `*`.
- Een buurt of wijk op gemeentenaam: `filter: "gemeentenaam = 'Amersfoort'"` (alleen als filter;
  de naam staat niet in de uitvoer).
- **Stadsdelen en nieuwbouwwijken** bestaan vaak uit meer wijken (`*Schothorst*` levert
  Schothorst-Noord en Schothorst-Zuid), soms met een bedrijventerrein met dezelfde naam. Noem de
  treffers, tel samen wat de vraag bedoelt en zeg welke wijken je hebt meegenomen. Een voorvoegsel kan ook een ander dorp raken (Hoogland* vindt ook
  Hooglanderveen).
- **Grootte**: zonder `properties` komt de volledige geometrie mee (rond 2 tot 4 kB per buurt, een
  gemeente rond 80 kB). Voor namen en codes `properties: ["naam", "wijk"]` en `limit` 500 (alle
  buurten van een gemeente in één aanroep). Voor `clip` de volledige geometrie van één buurt of
  wijk. Voor een kaart `zoom-level` 12 (een gemeente rond 3 kB), of de link uit het resultaat.

## Postcodegebieden

- `collection_postcode6` met `postcode`, `gemeentecode`, `wijkcode` of `buurtcode`; andere
  eigenschappen met `filter` (`filter: "postcode LIKE '3811%'"`, `filter: "aantal_inwoners >=
  500"`). Zonder `properties` komt de geometrie mee (rond 1,4 kB per postcode).
- `process_aggregate-features` van deze server telt en somt per gemeente, wijk of buurt zonder de
  postcodes op te halen: `source: {"collection": "postcode6", "parameters": {"gemeentecode":
  "0307"}}`, `groupBy: ["wijkcode"]`, `aggregates: [{"function": "sum", "property":
  "aantal_inwoners"}, {"function": "count", "property": "aantal_inwoners"}, "count"]`. `count` met een
  eigenschap telt de postcodes met een waarde; zet het naast `count` zonder eigenschap om te zeggen
  hoeveel postcodes meetellen. De groepen hebben de code als sleutel; de namen komen uit Wijken en
  buurten.
- Een postcodegebied hoort bij de buurt waarin een punt binnen het gebied ligt; een paar postcodes
  van adressen in de gemeente liggen volgens het CBS in een buurgemeente.
- In de BAG verwijst de postcode van een nummeraanduiding naar het postcodegebied.

### Wat een ontbrekende waarde betekent

- Aantallen zijn op vijftallen afgerond, percentages op tientallen. Het CBS publiceert een waarde
  alleen bij ten minste vijf inwoners, huishoudens of woningen (percentages bij ten minste tien).
  **Een ontbrekende waarde is 0 tot 4 of geheim**, geen nul en geen onbekend aantal. Sommige
  postcodes hebben helemaal geen eigenschappen.
- Hoe vaak waarden ontbreken (een gemeente, ruim 3.600 postcodes): aantal inwoners 8 %,
  leeftijdsklassen 22 tot 55 %, bouwjaarklassen 81 tot 94 %, eenouderhuishoudens 93 %, percentage
  koopwoningen 42 %, huurwoningen 73 %.
- **Sommen zijn ondergrenzen**, sommen van deelgroepen nog meer: in een gemeente lag de som van de
  leeftijdsklassen 8 % onder de som van de inwoners, de som van de vier huishoudtypen 20 % onder de
  som van de huishoudens. Zeg "minstens" of "ongeveer" en dat
  postcodes met weinig inwoners ontbreken.
- **Percentages** en de gemiddelde huishoudensgrootte zijn niet op te tellen. Een gewogen
  gemiddelde (`{"function": "avg", "property": "percentage_koopwoningen", "weight":
  "aantal_woningen"}`) telt alleen de postcodes met een waarde; omdat koop en huur vaak maar één van
  beide hebben (100 % koop, huur ontbreekt), tellen de gewogen gemiddelden samen tot ver boven
  100 %. Een aandeel koopwoningen per wijk volgt er niet uit: geef de spreiding (de postcodes met en
  zonder waarde) of zeg dat het CBS het per wijk in de Kerncijfers publiceert.
- **Sorteren**: `sortby: "-aantal_inwoners"` zet de postcodes zonder waarde vooraan; filter op
  `aantal_inwoners IS NOT NULL`. Een vergelijking (`< 5`) treft een ontbrekende waarde nooit.

### Grootte

- Een postcode met twee eigenschappen zonder geometrie is rond 200 bytes; een buurt van 25 tot 50
  postcodes past ruim. Een hele gemeente (3.600 postcodes) met één eigenschap is 300 kB en past niet
  in het antwoord: tellen met `process_aggregate-features`, of per wijk ophalen.
- De geometrie van alle postcodes van een gemeente is meer dan een megabyte: alleen als link voor een
  kaart, nooit door het model.

## Voorbeelden

**Hoeveel huishoudens hebben de postcodes die met 3817 beginnen?**
`process_aggregate-features` (Postcodegebieden) met `source: {"collection": "postcode6",
"parameters": {"filter": "postcode LIKE '3817%'"}}`, `aggregates: [{"function": "sum", "property":
"aantal_part_huishoudens"}, {"function": "count", "property": "aantal_part_huishoudens"},
"count"]`. Antwoord:
"minstens ..., in ... van de ... postcodes; postcodes met minder dan vijf huishoudens ontbreken".

**Welke postcode in een gemeente heeft de meeste kinderen onder 15?**
`collection_postcode6` met `gemeentecode`, `filter: "aantal_inwoners_0_tot_15_jaar IS NOT NULL"`,
`sortby: "-aantal_inwoners_0_tot_15_jaar"`, `properties: ["postcode",
"aantal_inwoners_0_tot_15_jaar", "buurtcode"]`, `limit` 5.

**Hoeveel inwoners heeft elke wijk?**
`process_aggregate-features` (Postcodegebieden) met `groupBy: ["wijkcode"]` en de som van
`aantal_inwoners`; de namen uit `collection_wijk` met `properties: ["naam"]`. Zeg dat het sommen
over postcodes zijn, afgerond en zonder de kleinste postcodes, en dat een postcode over een
wijkgrens heen bij één wijk telt.
