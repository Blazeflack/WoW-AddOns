# BlazeMail

Mailbox-tema og alt-modtagervælger til WoW Forever. Ingen eksterne addon-afhængigheder.

## Brug

- Installer mappen `BlazeMail` som et selvstændigt addon, og aktivér det på dine characters.
- Log ind på hver character én gang for at registrere den. Listen gemmes account-wide i `BlazeMailDB` ved normal logout/afslutning eller `/reload`.
- Åbn mailboxens **Send Mail**, og klik på den lille **v**-knap til højre for **To:**.
- **Inbox** og **Send Mail** deler en topnavigation i et vindue på 390 UI-enheders bredde. Den aktive fane har en afdæmpet orange understregning. Indbakken viser en baggrund for hvert brev og en kort besked på en tom side. Modtager, emne, brevtekst og vedhæftninger er samlet under navigationen. Åbne breve bruger samme mørke farver og skriftstørrelser på 11/13.
- Itemikoner, kvalitetskanter, møntikoner, C.O.D.-markeringer, Blizzards læst/ulæst-farver og fejltilstande bevares. Navigation, penge/C.O.D., vedhæftninger, åbning, sletning og afsendelse håndteres fortsat af Blizzard.
- Vælg en alt for at udfylde modtagerfeltet med **Fornavn Efternavn**. Navnene vises i class-color. Du sender selv brevet.
- Efter en vellykket afsendelse genudfyldes det netop afsendte modtagernavn, når Blizzard har nulstillet formularen. Det gælder også manuelt indtastede modtagere og gør det muligt at sende flere portioner items til samme character. Et nyt valg fra listen erstatter navnet. Der genudfyldes ikke efter fejl eller lukning af mailboxen, og nye navnevalg/manuelle ændringer får forrang. Navnet huskes kun for den aktuelle mailbox-session.
- Efter valg fra listen og genudfyldning sættes tekstcursoren til starten af modtagerfeltet, så fornavnet vises frem for slutningen af efternavnet.
- Listen viser kun andre characters med samme region, ruleset-identifikator og faction. Syv entries vises pr. side.
- Brug **Favorite** og **Unfavorite** i **Manage characters** til at ændre favoritter. Knapperne og **Note** har lysere baggrund og kant og vises kun i administrationen. Favoritter har en vedvarende messingfarvet kant omkring rækken i begge lister og sorteres øverst inden for hver region/ruleset/faction. Inden for samme prioritet sorteres alfabetisk.
- **Search** filtrerer på en del af fornavnet eller efternavnet. **X** rydder søgningen. Søgningen nulstilles, når vinduet genåbnes, og ændrer ikke faction-/ruleset-filtreringen.
- Brug **Note** ved en character i administrationen for at redigere en note på op til 100 tegn, fx “Bank” eller “Alchemy”. **Save** eller Enter gemmer; **Cancel** eller Escape i notefeltet fortryder. Gem en tom note for at fjerne den. Noten vises under navnet, og hele noten kan læses i tooltip ved hover over rækken.
- Brug **Manage characters** eller `/blazemail` til at se alle gemte characters, grupperet ved sortering efter region, ruleset og faction. Klik på et navn, og bekræft med **Remove**. **Cancel** fortryder.
- **Back to recipients** vises kun, når mailboxens **Send Mail**-fane er åben, så det faktisk er muligt at vende tilbage til modtagerlisten.
- `/bm` er en kort alias for `/blazemail`, hvis kommandoen er ledig ved login. Tjekket foretages efter normal addon-indlæsning og omfatter eksisterende slash-aliaser (uanset store/små bogstaver), kommandocaches og secure kommandoer. Er `/bm` optaget, undlades aliaset, mens `/blazemail` fortsat virker. Addons, som registrerer kommandoer senere, kan ikke forudses.
- En fjernet character registreres igen næste gang, du logger ind på den. Addonet forsøger ikke at opdage slettede characters automatisk.
- Interfacet bruger mørke gråtoner, lys tekst og en afdæmpet orange valgmarkering. Character-navne beholder deres class-color.
- BlazeMail har egne fontobjekter baseret på WoW's: titler, characternavne, søgelabel og sidetal bruger **13 UI-enheder**; hjælpetekst, noter, knapper og inputfelter bruger **11 UI-enheder**. De arver WoW-fontenes skrifttype, farver, skygger og flags, mens størrelsen er fastlagt af BlazeMail. De globale WoW-fontobjekter ændres ikke. Vinduet bruger de oprindelige mål på **390 × 500 UI-enheder** med de oprindelige afstande, felter og knapper. UI-scale påvirker fortsat skærmstørrelsen.
- Ved bekræftelse af fjernelse bliver den valgte række vedvarende fremhævet med orange baggrund, også når musen flyttes væk. **Cancel** fjerner markeringen. Der er ingen separat fortryd-funktion efter en bekræftet fjernelse.
- Escape eller **Close** lukker listen. Modtagerlisten lukkes også, når **Send Mail** skjules.
- Træk i titelfeltet for at flytte vinduet. Modtagerlisten åbner hver gang 5 UI-enheder til højre for mailboxen, ligesom et åbent brev. Administrationen (`/bm`) husker sin placering mellem åbninger.
- Favoritter, noter og placeringer gemmes account-wide i den eksisterende `BlazeMailDB`. Genregistrering ved login opdaterer characterens identitet uden at overskrive favoritter eller noter.

## Forever-kompatibilitet

API'er og events er kontrolleret mod repositoryets `api.json`: interface **16001**, version **1.60.1**, build **70790**, builddato **3. november 2026**, eksporteret **5. november 2026**. TOC'en bruger dette interface; det er ikke verificeret mod en aktuelt kørende klient.

`UnitNameUnmodified`, `UnitGUID`, `UnitClass`, `UnitFactionGroup`, `GetCurrentRegion`, `GetRealmName`, `C_ClassColor.GetClassColor`, `issecretvalue` og de anvendte login/mail-events findes i snapshottet. Identitetsværdier kontrolleres for secret values før sammenligning eller strengbehandling.

De nye felters EditBox-metoder, `GetScript`, `GetCenter`, `GetWidth` og `GetHeight` samt flyttemetoderne er også kontrolleret mod snapshottet. Lokale Lua-tests dækker favoritsortering, søgefiltrering, bevarelse af metadata ved login, noter med gem/annullér, vedvarende valgmarkering og gendannelse af position i en ny UI-instans med samme SavedVariables. Det erstatter ikke en faktisk genstartstest i klienten.

Font-metoderne `GetFont`, `SetFontObject` og `SetFont` er dokumenteret i snapshottet. `CreateFont` er kun angivet som en eksisterende global uden signatur; den læste Forever `FontDocumentation.lua` udfylder heller ikke denne mangel. Oprettelse af de nye fontobjekter og faktisk layout skal derfor kontrolleres i klienten efter `/reload`. Størrelserne kan kontrolleres med `/dump select(2, BlazeMailFontSmall:GetFont())` (11) og `/dump select(2, BlazeMailFontNormal:GetFont())` (13), når BlazeMail-vinduet er åbnet.

Genudfyldning anvender de dokumenterede events `MAIL_SEND_SUCCESS`, `MAIL_FAILED`, `MAIL_SHOW` og `MAIL_CLOSED` samt `C_Timer.After(0, callback)` og EditBox-metoden `SetCursorPosition(0)`. `SendMail` og `hooksecurefunc` findes i snapshottet, men snapshottet dokumenterer ikke deres fulde signaturer. Modtagernavnet som første argument til `SendMail` og nulstillingen i Blizzards success-handler er kontrolleret i ovennævnte Forever `MailFrame.lua`. Et sikkert post-hook observerer afsendelser; addonet sender ikke selv breve. Den korte engangstimer sikrer genudfyldning efter alle success-handlere uanset rækkefølgen. Lokale tests dækker begge handler-rækkefølger, manuel modtager, fejlet afsendelse, nyt valg, manuel rydning og luk/genåbn inden timeren kører.

Snapshottet kalder navnefunktionens anden returværdi `unitServer`. Forevers egen Camelot-UI-kode behandler den som **efternavn**: [NameUtil.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Camelot/NameUtil.lua). Addonet samler navnet med mellemrum efter brugerens bekræftede mailformat.

Modtagerfeltet `SendMailNameEditBox`, dets `OnTextChanged`-opdatering og `SendMailFrame` er kontrolleret i Forevers [MailFrame.xml](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MailFrame/MailFrame.xml) og [MailFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua). Der kaldes ikke send-mail-funktioner, og Blizzards eksisterende scripts erstattes ikke. De eksterne kilder er en nyere `forever`-branch, ikke et fastlåst match til snapshot-buildet.

Mailbox-temaet ligger i `MailTheme.lua` og indlæses før hovedfilen. Det tilsluttes, når `Blizzard_MailFrame` er tilgængeligt, og bruger de samme fontobjekter som alt-vinduet. `GetRegions`, `IsObjectType`, tekst-/fontmetoderne og knappernes teksturmetoder er kontrolleret mod `api.json`. De konkrete frames, dekorative regioner og faneskiftet er kontrolleret i ovennævnte mailbox-kilder og Forevers [SharedUIPanelTemplates.xml](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml). SimpleHTML-brevtekstens `SetFontObject` og `SetTextColor` er dokumenteret med et teksttype-argument; visningen af almindelige breve, HTML-overskrifter og fakturaer skal stadig kontrolleres i klienten.

Temaet opretter dekorationer én gang pr. kendt frame og post-hooker faneskift for at opdatere farverne. Det ændrer ikke Blizzards events, `OnClick`-scripts, hitområder, scrollfunktioner eller mailindhold og foretager ingen mailhandlinger. Lokale regressionstests kontrollerer gentagen anvendelse uden nye teksturer/hooks samt bevarelse af klikfunktioner, ikonregioner og advarselsfarver. Kombinationer med andre addons, der ændrer mailboxen, er ikke testet.

Slash-registerets interne tabeller er ikke dokumenteret i `api.json`; `IsSecureCmd` er kun angivet som en eksisterende global uden signatur. Alias-tjekket er derfor verificeret mod Forevers [SlashCommandsRegistry.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommandsRegistry.lua) og [ChatFrameEditBox.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua). Test `/bm` efter `/reload`; med et andet addon, der allerede bruger aliaset ved login, skal det fortsat åbne det andet addons funktion.

**Ruleset-identifikation:** Brugeren har verificeret, at `GetRealmName()` returnerer `CAMWOW EU4 Realm 7 PvE` på en PvE-character. Addonet udleder derfor `PvE` fra slutningen og ignorerer det nummererede forbindelsesnavn. Det genkender de fire oplyste ruleset-navne `PvE`, `PvP`, `Roleplay` og `PvP Roleplay` som hele værdien eller et afsluttende ord/udtryk. `PvP Roleplay` matches først, så det holdes adskilt fra `Roleplay`. Region gemmes separat. Allerede gemte forbindelsesnavne normaliseres automatisk ved addon-load, uden at characters slettes. Der bruges ingen realm-ID'er fra GUID, og der tilføjes ingen realm-suffixer til modtagernavne.

Kun PvE-formatet er verificeret i spillet. De tre øvrige suffixer bygger på brugerens ruleset-navne og kræver kontrol på de pågældende characters. Ukendte eller manglende suffixer gættes ikke: nye characters registreres ikke, og eksisterende entries bevares i administrationen, men matches ikke til et kendt ruleset i modtagerlisten.

## Test i spillet

1. Kontrollér `/dump select(4, GetBuildInfo())` og `/dump GetRealmName()` på dine characters. Hele forbindelsesnavnet behøver ikke være ens på samme ruleset; det genkendte suffix skal være det samme. Kontrollér især de faktiske suffixer for PvP, Roleplay og PvP Roleplay, hvis du bruger disse rulesets.
2. Kontrollér `/dump UnitNameUnmodified("player")`, og at begge navne vises korrekt i `/blazemail`.
3. Log ind på to characters med samme faction/ruleset. Åbn **Send Mail**, vælg en alt, og kontrollér modtagerfeltet og en faktisk testforsendelse.
4. Kontrollér, at modsatte faction, andre rulesets og den aktuelle character er skjult i modtagerlisten, men findes i administrationen.
5. Fjern en character, genstart spillet normalt, og kontrollér, at den fortsat er væk. Log ind på den fjernede character, og kontrollér genregistrering.
6. Kontrollér placering, lange navne, sideskift, Escape, skift mellem mailboxens faner og genåbning af mailboxen med din UI-scale og eventuelle UI-addons.
7. Markér en favorit, gem en note, og flyt `/bm`-vinduet. Kontrollér favoritsortering, søgning på både fornavn og efternavn samt notevisning. Log ud/afslut normalt, og kontrollér efter genstart, at alle tre ændringer er bevaret. Kontrollér også efter login på en anden character.
8. Vælg en character til fjernelse, flyt musen væk, og kontrollér den vedvarende orange markering. Tryk **Cancel**, og kontrollér, at markeringen forsvinder, og characteren bevares. Åbn `/bm` uden mailboxen, og kontrollér, at **Back to recipients** er skjult.
9. Send et testbrev, og kontrollér, at modtagerfeltet genudfyldes med samme navn og viser fornavnet. Vedhæft næste portion items, og send igen. Vælg derefter en anden alt, og kontrollér, at navnet erstattes. Kontrollér også en manuelt indtastet modtager og et langt efternavn. Luk og genåbn mailboxen, og kontrollér, at en tidligere afsendelse ikke genudfylder den nye session.
10. Efter `/reload`: Åbn mailboxen, skift flere gange mellem **Inbox** og **Send Mail**, og kontrollér farver, fontstørrelser, felter og knapper. Åbn et brev og en auktionsfaktura, og kontrollér læsbarhed, scrolling, links, ikoner og vedhæftninger. Kontrollér læst/ulæst-markeringer, udløbstid, sideskift, inaktive knapper og fejltekst. Genprøv penge/C.O.D. og et almindeligt testbrev med ufarligt indhold, og kontrollér alt-vælger og genudfyldning.

Ingen in-game-tests er udført fra udviklingsmiljøet. Addonet er ikke kopieret til en live WoW-installation.
Brugeren har bekræftet afsendelse, genudfyldning og cursor ved navnets start i klienten før mailbox-temaet blev tilføjet. Det nye tema kræver selvstændig in-game-verifikation.

## Lokal regressionstest

Kør `lua BlazeMail/tests/regression.lua` fra repositoryets rod med Lua 5.1. Testfilen er ikke med i TOC'en.
