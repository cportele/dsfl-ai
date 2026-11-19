---
name: dso
description: >-
  Lees dit voor vragen over de regels van de Omgevingswet op een adres met de DSO-werkstromen:
  welke werkstroom bij welke vraag, de invoer (adres, datums, identificaties), hoe de uitvoer te
  lezen is (parallelle lijsten, regelteksten in XML), de vergunningcheck in rondes, regels op een
  eerdere datum, en hoe het antwoord te presenteren. English: read before answering questions
  about the rules of the Dutch Environment and Planning Act at an address with the DSO workflows:
  choosing a workflow, inputs, reading the outputs, the permit check in rounds, rules on an
  earlier date, presenting the answer.
---

# Regels van de Omgevingswet op een adres

De werkstromen roepen live de API's van het Digitaal Stelsel Omgevingswet (DSO) aan, met de BAG
van deze server voor het adres. Het zijn bewerkte, niet-officiële kopieën van werkstromen van het
DSO-team. Een antwoord is informatie, geen juridisch advies of besluit: verwijs voor zekerheid naar
het Omgevingsloket (omgevingswet.overheid.nl) of de gemeente. Een aanroep duurt enkele seconden tot
een halve minuut; roep een werkstroom niet onnodig opnieuw aan.

## Welke werkstroom voor welke vraag

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

## Invoer

- **Adres**: postcode zonder spatie (`3811LM`) en huisnummer als tekst (`"1"`), zonder huisletter of
  toevoeging. Het adres moet in de BAG van deze server staan en een verblijfsobject hebben; staat
  het er niet in, dan geeft de werkstroom een fout. Een standplaats of ligplaats werkt niet.
- **Twee datumnotaties**: `datum` is `dd-MM-jjjj` (toepasbare regels, meestal vandaag),
  `peildatum` is `jjjj-MM-dd`. `verzoek-voorbereiden` vraagt dezelfde dag in beide notaties.
- **Regeling**: `uriIdentificatie` met underscores, zoals de werkstromen hem leveren, bijvoorbeeld
  `_akn_nl_act_gm0307_2020_omgevingsplan`; de vorm met schuine strepen wordt geweigerd.
- **Punt in RD** (`rdX`, `rdY` voor de peildatum-werkstromen): de BAG-tools leveren
  lengte/breedtegraad (WGS84). Reken om met de benaderingsformule (nauwkeurig tot ongeveer 1 m,
  genoeg om documenten op een punt te vinden):
  ```
  dp = 0.36 * (lat - 52.15517440);  dl = 0.36 * (lon - 5.38720621)
  rdX = 155000 + 190094.945*dl - 11832.228*dp*dl - 114.221*dp^2*dl - 32.391*dl^3 - 0.705*dp
        - 2.340*dp^3*dl - 0.608*dp*dl^3 - 0.008*dl^2 + 0.148*dp^2*dl^3
  rdY = 463000 + 309056.544*dp + 3638.893*dl^2 + 73.077*dp^2 - 157.984*dp*dl^2 + 59.788*dp^3
        + 0.433*dl - 6.439*dp^2*dl^2 - 0.032*dp*dl + 0.092*dl^4 - 0.054*dp*dl^4
  ```
  Stadhuisplein 1, Amersfoort: lon 5.38416472, lat 52.15671963 → rdX 154792, rdY 463172.

## De uitvoer lezen

- **Parallelle lijsten**: de uitvoer bestaat uit lijsten waarvan de elementen op dezelfde positie
  bij elkaar horen (bijvoorbeeld `activiteiten[i]`, `conclusie[i]`, `vraagIds[i]`). Tel nooit op
  of sorteer niet los van elkaar. `null` op een positie betekent: voor dit element geen waarde
  (bijvoorbeeld een ontwerp zonder titel, een check zonder conclusie).
- **Regelteksten** (`owTeksten`, de uitvoer van `ow-tekst-ophalen`) zijn XML volgens de standaard
  STOP: de tekst staat in `<Al>` (alinea's) en `<Li>` (lijstonderdelen met `<LiNummer>`); negeer de
  attributen. Het artikelnummer staat in de identificatie, bijvoorbeeld `..._art_22.31` →
  artikel 22.31. Geef de tekst in gewone zinnen of als lijst weer, niet als XML.
- **Omgevingsplan en bestemmingsplannen**: tot een gemeente haar omgevingsplan helemaal heeft
  vernieuwd, gelden de regels van de oude bestemmingsplannen (Wro) als deel van het omgevingsplan.
  Daarom leveren de werkstromen beide: `omgevingsplan`, `owArtikelen`, `owTeksten` voor het nieuwe
  deel, `wroPlannen`, `wroBestemmingen`, `wroMaatvoeringen` voor het oude. Noem beide.

## Per werkstroom

**regels-over-wonen**: zoekt in de bestemmingsplannen alleen de hoofdgroep 'wonen'. In
binnensteden valt wonen vaak onder 'centrum' of 'gemengd'; een lege `wroBestemmingen` betekent dus
niet dat wonen er niet mag. Zeg dat erbij.

**dakkapel-hier** (vergunningcheck):
1. Eerste ronde zonder `antwoorden`, `activiteit` als korte term (bijvoorbeeld `dakkapel`), `datum`
   vandaag. De uitvoer heeft per gevonden activiteit (meestal een gemeentelijke en een van het
   Rijk) de vragen `vragenVergunningcheck[i]` met hun ids `vraagIds[i]`, en `conclusie[i]`.
2. Stel de vragen aan de gebruiker; beantwoord ze nooit zelf of met aannames.
3. Volgende ronde met alle antwoorden tot nu toe in één lijst `{id, antwoord}`: `id` als getal,
   ja/nee als `"true"`/`"false"`, een keuze als de tekst van de optie. Nieuwe vragen kunnen volgen.
4. Klaar als elke `conclusie[i]` een waarde heeft, bijvoorbeeld 'Vergunningplicht',
   'Toestemmingsvrij' of 'Niet van toepassing' (die check geldt hier niet). `aanvragenVoor[i]` is
   de activiteit waarvoor men dan aanvraagt of meldt.
De artikelen uit het omgevingsplan (`owArtikelen`, `owTeksten`) horen bij de gemeentelijke
activiteit; ze kunnen algemener zijn dan de vraag (bijvoorbeeld een artikel over vergunningvrije
bijbehorende bouwwerken). De rijksregels uit het Besluit bouwwerken leefomgeving staan er niet in;
de vergunningcheck van het Rijk wel.

**wat-verandert-hier**: `ontwerpen`, `typen`, `eindeInzage`, `wijzigingenArtikelen` en
`wijzigingenTekst` zijn parallel. Een ontwerp is nog geen recht; tot en met `eindeInzage` kan
iedereen een zienswijze indienen. De wijzigingen noemen alleen de bewerking per onderdeel
(`toevoegen`, `verwijderen`), niet de tekst: tel ze hoogstens. Programma's en visies van provincie
of Rijk (bijvoorbeeld de Nota Ruimte) gelden voor grote gebieden en zeggen weinig over deze plek;
noem eerst wat de gemeente wijzigt. `toekomstigGeldend` en `wroInProcedure` zijn paren van titel
en datum of soort.

**verzoek-voorbereiden**: `zoekterm` moet specifiek zijn (bijvoorbeeld `boom kappen`). Een brede
term (`bouwen`) levert veel `kandidaten` en stopt: kies er met de gebruiker één en zoek gerichter.
Een term die het stelsel voor de gemeente niet kent, levert niets; probeer een synoniem, of voor
bouwactiviteiten `dakkapel-hier`. `indienbaar` false met `verplichteVragen`: antwoorden aanvullen
(`antwoordenAlgemeneSet`, `antwoordenActiviteit`) en opnieuw. De werkstroom dient nooit iets in.

**Peildatum** (de toestand op een eerdere datum):
1. `documenten-op-peildatum` met `rdX`, `rdY`, `peildatum` → `typen`, `titels`,
   `uriIdentificaties` (parallel).
2. `regeling-detail` en `versiehistorie` met een `uriIdentificatie`, alleen voor documenten volgens
   de Omgevingswet (niet voor bestemmingsplannen of structuurvisies).
3. `regels-op-peildatum` met `uriIdentificatie`, `rdX`, `rdY`, `peildatum` → de activiteiten op
   het punt en de `regeltekstWIds`. Bij een omgevingsplan zijn dat honderden regels: kies de wIds
   die bij de vraag horen.
4. `ow-tekst-ophalen` met dezelfde `uriIdentificatie`, een `wId` precies zoals geleverd en
   **dezelfde** `peildatum`; zonder peildatum bestaat een wId van een oudere versie niet.

## Het antwoord presenteren

- Eerst het antwoord, dan de bron: document (titel), artikel en datum.
- Bij een vergunningcheck: de conclusie per activiteit en de antwoorden waarop ze berust.
- Zeg dat het informatie uit het DSO is op de dag van de aanroep, geen besluit, en dat het
  Omgevingsloket en de gemeente de officiële bron zijn.
