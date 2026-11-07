# BlazeTweaks

To funktioner til WoW Forever: automatisk åbning af nye clams/containers og
automatisk valg af én tilgængelig bank-, taxi- eller vendor-gossipmulighed uden quests.

Åbn indstillinger med `/bt` eller `/blazetweaks`.

- Til/fra gemmes **pr. karakter**. Nye indstillinger er slået fra; eksisterende
  booleske valg for `autoOpenClams` og `autoGossip` bevares.
- Ændringer virker straks uden reload. Slår du en funktion fra, gør dens ventende
  callbacks ikke mere. Et item, der allerede er brugt, kan ikke trækkes tilbage.
- De tre faste clams er item-ID 5523, 5524 og 7973.
- Ekstra item-ID'er gemmes **kontofælles** i `BlazeTweaksDB.containerItems`.
  Skriv ét ID i det lille felt og tryk **Tilføj** eller Enter. Klik i feltet giver
  fokus med blinkende tekstmarkør. Tilføjelser og fjernelser gemmes straks.
  Feedback vises ved siden af Tilføj-knappen og forsvinder efter fem sekunder.
- Listen viser standard-items og ekstra items i **to kolonner** med ikon, navn og
  item-tooltip ved mouseover. Ved pladsmangel vises en scrollbar; både træk i
  scrollbaren og musehjulet kan bruges. Fjern et ekstra item med **X**;
  standard-items kan ikke fjernes.
  Standard-items står først; ekstra items vises derefter i tilføjelsesrækkefølge,
  læst fra venstre mod højre i hver række. Rækkefølgen gemmes kontofælles i
  `BlazeTweaksDB.containerItemOrder`. Fjernes et item og tilføjes igen, placeres
  det sidst. Ældre gemte lister har ingen historik om tilføjelse og indlæses derfor
  første gang i item-ID-rækkefølge; fremtidige tilføjelser sættes sidst.
  Dubletter og ugyldige ID'er afvises. Manglende itemdata hentes asynkront; gamle
  gemte items vises midlertidigt med en pladsholder, indtil data er klar.
  Et opslag uden svar afbrydes efter fem sekunder og kan forsøges igen.
  Et eksisterende item er ikke nødvendigvis en åbningsbar container; tilføj kun
  containers, du ønsker automatisk brug af.
- Kun tilgang efter aktivering køres i køen. Items, som allerede ligger i taskerne
  ved login, aktivering eller ændring af listen, åbnes ikke automatisk.
- Åbning venter ved kamp, åbent loot-vindue, butik, bank, låste items og manglende
  ledige pladser i normale tasker. Højst tre brug-forsøg pr. køpost.
- Hold Shift ved åbning af gossip for at springe automatisk valg over under den side.
- Gossip har separate undervalg for **Bank**, **Taxi** og **Vendor**, gemt pr.
  karakter i `BlazeTweaksCharDB.gossipTypes`. Alle tre er slået til som standard;
  hovedvalget er fortsat slået fra som standard. Undervalg kan ændres uden reload,
  og eksisterende individuelle valg bevares ved indlæsning.

De fjernede tweaks indlæses ikke længere. Ældre SavedVariables-felter, herunder
chathistorik, slettes ikke automatisk, men bruges heller ikke længere.

## Kompatibilitet og test

API-reference: repositoryets `api.json`, version 1.60.1, build 70790, interface
16001, eksporteret 5. november 2026. Container-/gossip-funktioner, item-GUID,
events, timer og anvendte dokumenterede felter er kontrolleret dér.
GUI'ens `C_Item.GetItemInfo`, `RequestLoadItemDataByID`, `ITEM_DATA_LOAD_RESULT`,
inputfokus og `SetBlinkSpeed` er også kontrolleret i snapshot. Tooltip-metoderne
`SetOwner`/`SetHyperlink` er ikke fuldt dokumenteret dér; brugen er kontrolleret
mod [Forever UI-kilden](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua)
og den tidligere gennemgåede DialogueUI-kode. Forever-grenen rapporterede build
70862 ved kontrollen, altså nyere end snapshot 70790. Ikoner, cursor og
tooltips kræver stadig visuel kontrol i Forever.

`ItemLocation:CreateFromBagAndSlot` er ikke beskrevet i snapshot. Signaturen er
kontrolleret i [Blizzards UI-kilde spejlet hos Gethe](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ObjectAPI/Mainline/ItemLocation.lua),
og funktionen kontrolleres for tilgængelighed før aktivering. Kilden er Mainline og
udgør ikke en Forever-runtime-test. UI-templates og alle framemetoder er heller
ikke fuldt dokumenteret i snapshot.

DialogueUI-integrationen er baseret på den gennemgåede version **1.0.7 b**.
Post-hooks på `DUIQuestFrame.ShowUI` og `HandleGossip` håndterer både indlæsningens
udskudte gossip og nye sider i et allerede synligt vindue. Hooks bliver siddende,
men er passive, når gossip er slået fra; de oprettes ikke igen ved hver aktivering.
Dette er en integration med interne metoder, som fremtidige DialogueUI-versioner
kan ændre.

Lokale regressionstests bruger en simuleret WoW-API og Lua 5.1:

```text
lua BlazeTweaks/tests/regression.lua
```

Kør kommandoen fra repositoryets rod. Testfilen indlæses ikke af addonets TOC.
Testene verificerer logik, ikke klienttilladelser, UI-layout eller diskpersistens.

Test i Forever efter første indlæsning af de nye filer:

1. Brug `/bt`, slå funktionerne til/fra og kontrollér effekten uden reload.
   Klik i item-ID-feltet, kontrollér cursoren, tilføj med knap og Enter, og test
   dubletter/ugyldige ID'er. Kontrollér item-ikoner, tooltips, scrolling og X-knapper.
2. Modtag nye clams og et kendt ekstra container-item. Prøv låste items, fulde tasker,
   kamp og åbent loot-vindue samt butik/bank. Kontrollér, at køen fortsætter bagefter.
3. Test bank/taxi/vendor med og uden Shift, questmuligheder og flere gossipvalg.
   Slå hver gossiptype fra/til individuelt og kontrollér, at hovedvalget stadig
   bestemmer, om automatiseringen kører.
4. Test med/uden DialogueUI, umiddelbart efter login og mellem allerede synlige sider.
5. Genstart klienten og kontrollér karaktervalg og den fælles itemliste på to karakterer.

Automatisk item-brug fra en timer kræver fortsat test af de konkrete containers i
Forever. API-tilstedeværelse beviser ikke tilladelser. Klientens beskyttelser omgås
ikke; items, der kræver brugerinput, skal åbnes manuelt.
