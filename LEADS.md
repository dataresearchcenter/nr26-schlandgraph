# Fünf Leads für den Schlandgraph

Begleitmaterial zum nr26-Workshop **„Wenn das Geld Spuren hinterlässt"**:
fünf echte Recherche-Ansätze aus dem Redaktionsalltag — und wie weit man mit
ihnen im Schlandgraph kommt. Alle Abfragen sind am geladenen Graphen getestet
(Datenstand der Quellen: Juni 2026). Ebenso wichtig wie die Treffer: die
ehrlichen Grenzen. Wo der Graph nichts weiß, steht das hier auch.

## Bevor es losgeht

Graph starten und laden (einmalig, siehe README):

```bash
docker compose up -d
make graph
```

Dann den Neo4j-Browser öffnen: <http://localhost:7474>, Login `neo4j` /
`schlandgraph`. Abfragen in die Eingabezeile oben kopieren und mit ▶
ausführen.

### Cypher in 60 Sekunden

Cypher, die Abfragesprache von Neo4j, beschreibt Muster: runde Klammern
`(...)` sind Knoten (Personen, Firmen, Parteien …), Pfeile `-[:SO]->` sind
Beziehungen zwischen ihnen. `MATCH` heißt „finde dieses Muster", `WHERE`
filtert, `RETURN` bestimmt, was angezeigt wird. Eine Abfrage liest sich also
wie ein Satz: *„Finde alle, die Geld an eine Partei gezahlt haben, und zeig
mir Name, Betrag und Jahr."*

Zwei Anzeige-Modi, die man kennen sollte: Wer in `RETURN` einzelne Spalten
nennt, bekommt eine **Tabelle**. Wer einen ganzen Pfad zurückgibt
(`MATCH pfad = (...)-[...]-(...) RETURN pfad`), bekommt das **Netzwerk-Bild** —
das ist meist der Aha-Moment fürs Publikum.

### Die wichtigsten Vokabeln im Schlandgraph

| Im Graphen | Bedeutet |
|---|---|
| `:Human` | eine Person |
| `:Politician` | Person aus den Politik-Quellen — **Achtung:** AbgeordnetenWatch führt auch Kandidat:innen, die nie ein Mandat hatten |
| `:RoleLobby` | im Lobbyregister des Bundestags eingetragene Interessenvertreter:in |
| `:PolParty` | Partei |
| `:Organization`, `:Company` | Organisation, Unternehmen |
| `:Contract` | ein Lobbyauftrag (Mandat) aus dem Lobbyregister, mit Beschreibungstext |
| `:name`, `:address`, `:identifier` … | **geteilte Werte**: gleicher Name, gleiche Adresse, gleiche Kontonummer = derselbe Knoten |
| `-[:PAID]->` | hat Geld gezahlt — Parteispenden, mit Betrag (`amountEur`), Jahr (`date`) und Quelle (`sourceUrl`) |
| `-[:REPRESENTS]->` | ist als Lobbyist:in tätig für |
| `-[:BELONGS_TO]->` | ist Mitglied von / gehört zu |
| `-[:HAS_NAME]->`, `-[:HAS_ADDRESS]->` | führt zum geteilten Namens-/Adressknoten |

Der Kern-Trick des Graphen: Namen und Adressen sind **eigene Knoten**. Zwei
Einträge mit demselben Namen hängen automatisch am selben Namensknoten — quer
über alle zehn Datenquellen. Genau so entstehen die Brücken zwischen
Lobbyregister, Spendenlisten und PEP-Daten. Aber, einmal dick unterstrichen:
**Namensgleichheit ist ein Hinweis, kein Beweis.** Ob hinter zwei Knoten am
selben Namen wirklich dieselbe Person steckt, bleibt Handarbeit (und ist im
Workshop die Aufgabe von `make xref` / `make dedupe`).

---

## Lead 1: Die fast geschenkte Million — Horst Jan Winter und die AfD

**Die Ausgangslage.** Januar 2025: Ein bis dahin völlig unbekannter „Horst Jan
Winter" spendet knapp eine Million Euro an die AfD. Die Aufgabe damals: schnell
herausfinden, wer das ist und woher so viel Geld kommen könnte. Die Recherche
führte seinerzeit zur Böttcher AG und deren Chef.

**Schritt 1: Gibt es die Spende in unseren Daten?** Wir lassen uns die größten
AfD-Spenden ausgeben, absteigend sortiert:

```cypher
// Die größten Spenden an die AfD, größte zuerst
MATCH (spender)-[spende:PAID]->(partei:PolParty)
WHERE partei.caption =~ '(?i)afd.*'        // Schreibweisen "AfD"/"AFD" abdecken
RETURN spender.caption AS wer,
       spende.amountEur[0] AS betrag_eur,
       spende.date[0]      AS jahr,
       spende.sourceUrl[0] AS quelle
ORDER BY toFloat(spende.amountEur[0]) DESC
LIMIT 15;
```

Treffer: `Winter, Horst Jan — 999.990 € — 2025`, mit Quell-Link zur
Lobbypedia. Direkt darüber stehen übrigens die anderen Mega-Spenden des
AfD-Wahlkampfjahres (Gerhard Dingler 2,35 Mio., Winfried Stöcker 1,55 Mio.) —
allein diese Tabelle ist eine Geschichte.

**Schritt 2: Wo wohnt der Spender — und wer wohnt da noch?** Lobbypedia
verzeichnet zu Spender:innen den Wohnort. Im Graphen ist der Ort ein geteilter
Adressknoten — wir fragen also: Wer hängt an derselben Adresse?

```cypher
// Winters Adressknoten und alle, die ihn teilen
MATCH (winter {caption:'Winter, Horst Jan'})-[:HAS_ADDRESS]->(ort)<-[:HAS_ADDRESS]-(nachbar)
RETURN ort.caption AS ort, nachbar.caption AS nachbar, nachbar.datasets AS quelle;
```

Ergebnis: **Blankenhain**, ein kleiner Ort in Thüringen. Und am selben
Ortsknoten hängen weitere Parteispender: die **GRAFE Polymer Solutions GmbH**,
die **Hertig GmbH & Co. Recycling KG** und ein Grünen-Spender. Mit einem
einzigen Hüpfer über den Adressknoten sind wir bei der Frage, die auch die
echte Recherche antrieb: *Welches Geld sitzt eigentlich in diesem Ort?*

**Schritt 3: Was spenden die Nachbarn — und an wen?**

```cypher
// Spenden aller Entitäten am selben Ort wie Winter
MATCH (winter {caption:'Winter, Horst Jan'})-[:HAS_ADDRESS]->(ort)<-[:HAS_ADDRESS]-(nachbar)
MATCH (nachbar)-[spende:PAID]->(partei)
RETURN nachbar.caption AS wer, spende.amountEur[0] AS betrag_eur,
       spende.date[0] AS jahr, partei.caption AS an;
```

GRAFE spendete an CDU und FDP, Hertig 50.000 € an die CDU (2024). Als Bild
fürs Publikum:

```cypher
// Das Blankenhain-Geflecht als Netzwerk-Bild
MATCH pfad = (winter {caption:'Winter, Horst Jan'})-[:HAS_ADDRESS]->()<-[:HAS_ADDRESS]-()-[:PAID]->()
RETURN pfad;
```

**Aber — die Grenzen.** Die Böttcher AG und Udo Böttcher kommen in **keiner**
unserer zehn Quellen vor; diesen Teil der Geschichte lieferten damals
Handelsregister und Vor-Ort-Recherche, nicht Spenden- oder Lobbydaten. Außerdem
speichert Lobbypedia nur den **Ort**, keine Straße — die Adress-Brücke heißt
also „gleicher Ort", nicht „gleiches Haus". Und eine Stolperfalle der Daten:
Lobbypedia schreibt Namen als „Nachname, Vorname" — Winters Namensknoten
verbindet sich deshalb mit *niemandem* aus den anderen Quellen, die „Vorname
Nachname" schreiben. Die Dedup-Stufe der Pipeline (`make xref`) kann solche
gedrehten Namen trotzdem matchen — der reine Namensknoten-Trick nicht.

---

## Lead 2: EUTOP — die Drehtür, die das Register nicht flaggt

**Die Ausgangslage.** Die Lobbyagentur EUTOP gilt als eine der umtriebigsten —
viele heikle Kunden, viele Ex-Politiker:innen auf der Payroll. Gründer Klemens
Joos ist bestens in der Union vernetzt. Vor rund 20 Jahren arbeitete auch
Hendrik Wüst für EUTOP, bevor er als CDU-Generalsekretär in NRW den
„Rent-a-Rüttgers"-Skandal produzierte.

**Schritt 1: Wer oder was ist EUTOP im Graphen?**

```cypher
// Alle EUTOP-Gesellschaften im Lobbyregister
MATCH (eutop:Organization)
WHERE eutop.caption STARTS WITH 'EUTOP'
RETURN eutop.caption, eutop.id, eutop.datasets;
```

Vier Gesellschaften (Berlin, Europe, International, Brüssel) mit zusammen rund
50 eingetragenen Lobbyist:innen — plus ein Auftritt in den Lobbykontakte-Daten
und, Überraschung, ein Eintrag in den Parteispenden: EUTOP spendete 2002 an
CSU (48.500 €), CDU (19.750 €) und SPD (12.000 €).

**Schritt 2: Die Payroll.** Wer ist für EUTOP als Lobbyist:in registriert?

```cypher
// Alle für EUTOP registrierten Interessenvertreter:innen
MATCH (lobbyist:RoleLobby)-[:REPRESENTS]->(eutop)
WHERE eutop.caption STARTS WITH 'EUTOP'
RETURN DISTINCT lobbyist.caption AS person
ORDER BY person;
```

**Schritt 3: Die Drehtür sichtbar machen.** Das Lobbyregister verpflichtet
Lobbyist:innen nur, Ämter und Mandate der **letzten fünf Jahre** offenzulegen —
im Graphen tragen diese Personen das zusätzliche Label `Politician`. Wer
länger raus ist, taucht in dieser Selbstauskunft nicht auf. Dagegen hilft der
Namensknoten-Trick: Wir gleichen die EUTOP-Payroll mit *allen*
Politiker:innen-Profilen ab, die AbgeordnetenWatch je erfasst hat.

```cypher
// EUTOP-Lobbyist:innen, deren Name auch in den Politik-Daten auftaucht
MATCH (lobbyist:RoleLobby)-[:REPRESENTS]->(eutop)
WHERE eutop.caption STARTS WITH 'EUTOP'
MATCH (lobbyist)-[:HAS_NAME]->(:name)<-[:HAS_NAME]-(politik:Politician)
RETURN DISTINCT eutop.caption AS agentur, lobbyist.caption AS lobbyist,
       politik.id AS politik_profil, politik.datasets AS politik_quelle;
```

Treffer: **Stefan Mappus** — der frühere Ministerpräsident von
Baden-Württemberg steht für drei der vier EUTOP-Gesellschaften im Register.
Vom Register selbst als Ex-Amtsträger geflaggt ist er **nicht** (sein Mandat
liegt länger zurück als die Offenlegungspflicht reicht); die Fünf-Jahres-Flagge
tragen bei EUTOP nur zwei andere Namen. Genau dieser Kontrast — *was das
Register freiwillig verrät* gegen *was der Datenabgleich findet* — ist die
Pointe dieses Leads.

**Schritt 4: Wie offen ist EUTOP zu seinen Kunden?** Lobbyaufträge stehen als
`Contract`-Knoten im Graphen, mit dem Beschreibungstext aus dem Register:

```cypher
// Die Auftragsbeschreibungen, an denen Klemens Joos persönlich arbeitet
MATCH (joos:RoleLobby {caption:'Prof. Dr. Klemens Joos'})<-[:AWARDED_TO]-(auftrag:Contract)
RETURN auftrag.caption AS auftragstext;
```

Sieben Mandate, und alle Texte sind nahezu wortgleiche Formeln („Im Rahmen des
Auftrags wird Kontakt … aufgenommen") — **kein einziger Kundenname**. Zum
Vergleich lohnt derselbe Blick auf FGS Global (Lead 3), wo Kunden im Klartext
stehen. Verschwiegenheit ist hier als Datenmuster sichtbar. Sichtbar ist auch
das Netzwerk drumherum: EUTOP ist Mitglied im **Wirtschaftsrat der CDU**, im
**Wirtschaftsbeirat der Union (Bayern)** — und zugleich im Wirtschaftsforum
der SPD (Abfrage: `MATCH (e)-[:BELONGS_TO]->(o) WHERE e.caption STARTS WITH
'EUTOP' RETURN e.caption, o.caption;`).

**Und Hendrik Wüst?** Seine EUTOP-Zeit (~2003) liegt vor Einführung des
Registers (2022) — diese Kante **kann** es in den Daten nicht geben. Ehrliche
Antwort: hier schweigt der Graph. Was er stattdessen zeigt: Wüst existiert
dreimal — als AbgeordnetenWatch-Profil, als PEP-Eintrag im Bundesrat (als
Ministerpräsident) und als **Spender** (13.497 € an die CDU, 2022, ein
veröffentlichungspflichtiger Mandatsträgerbeitrag):

```cypher
// Drei Knoten, eine Person: alle Einträge am Namensknoten "Hendrik Wüst"
MATCH (n:name {caption:'Hendrik Wüst'})<-[:HAS_NAME]-(person)
RETURN person.caption, labels(person) AS rollen, person.datasets AS quelle;
```

Perfektes Anschauungsmaterial dafür, warum die Pipeline eine Dedup-Stufe hat.

---

## Lead 3: FGS Global und Katherina Reiche

**Die Ausgangslage.** Wirtschaftsministerin Katherina Reiche heuerte die
Agentur FGS Global an, um ihre Kommunikation zu verbessern. Fragestellung: Wer
ist FGS Global — welche Kunden, welche Verbindungen?

**Schritt 1: Das Personal.** FGS Global (Europe) GmbH hat 47 registrierte
Lobbyist:innen — und gehört bei den vom Register geflaggten
Ex-Amtsträger:innen zur Spitzengruppe des gesamten Registers:

```cypher
// Welche Organisationen haben die meisten frischen Ex-Amtsträger:innen an Bord?
MATCH (person:RoleLobby:Politician)-[:REPRESENTS]->(org)
RETURN org.caption AS organisation, count(DISTINCT person) AS ex_amtstraeger
ORDER BY ex_amtstraeger DESC
LIMIT 15;
```

FGS landet mit 8 Personen auf Platz 4 — direkt hinter BDI, Verbraucherzentrale
Bundesverband und BDEW. Die Namen:

```cypher
// Die geflaggten Ex-Amtsträger:innen bei FGS Global
MATCH (person:RoleLobby:Politician)-[:REPRESENTS]->(:Organization {caption:'FGS Global (Europe) GmbH'})
RETURN person.caption;
```

Darunter **Dr. Christoph Heusgen** (jahrelang außenpolitischer Berater im
Kanzleramt, danach Chef der Münchner Sicherheitskonferenz) und **Lutz
Stroppe** (Ex-Staatssekretär im Gesundheitsministerium).

**Schritt 2: Die Kunden.** Anders als EUTOP nennt FGS in den Auftragstexten
oft Klarnamen — man kann sie einfach lesen:

```cypher
// Alle Auftragsbeschreibungen, in denen FGS Global vorkommt
MATCH (auftrag:Contract)
WHERE auftrag.caption CONTAINS 'FGS Global'
RETURN auftrag.caption AS auftragstext;
```

Im Ergebnis stehen Enpal, BioNTech, Ericsson, Nexperia, Isar Aerospace — und
ein namentlich *nicht* genannter Kunde für „Energie- und Rohstoffpolitik".
Wer an welchem Mandat arbeitet, zeigt eine Verfeinerung:

```cypher
// Wer bei FGS betreut den BioNTech-Auftrag?
MATCH (auftrag:Contract)-[:AWARDED_TO]->(person:RoleLobby)
WHERE auftrag.caption CONTAINS 'BioNTech'
RETURN substring(auftrag.caption, 0, 120) AS auftrag, person.caption AS zustaendig;
```

(Antwort: u. a. Lutz Stroppe — der Ex-Staatssekretär aus genau dem
Ministerium, das über Pharma-Themen entscheidet.)

**Schritt 3: Reiche selbst — eine Karriere, vier Knoten.** Die Ministerin ist
das schönste Drehtür-Exponat des Graphen. Ihr zusammengeführter PEP-Knoten
zeigt die Abgeordnetenzeit samt Gremiensitzen:

```cypher
// Reiches Bundestagszeit: Partei, Fraktionen, Nebentätigkeits-Gremien
MATCH (reiche {id:'Q108126'})-[verbindung]-(gegenueber)
RETURN type(verbindung) AS art, gegenueber.caption AS womit
LIMIT 25;
```

Und in den protokollierten Lobbykontakten taucht sie **auf der anderen Seite
des Tisches** auf — 2018, als Hauptgeschäftsführerin des Verbands kommunaler
Unternehmen:

```cypher
// Reiche als Lobbyistin in den Lobbykontakte-Daten (zwei Schreibweisen!)
MATCH (person)-[rolle:BELONGS_TO]->(verband)
WHERE person.caption =~ 'Kath[ae]rina Reiche'
  AND verband.caption CONTAINS 'kommunaler Unternehmen'
RETURN person.caption, rolle.date AS datum, verband.caption;
```

Abgeordnete → Verbandslobbyistin → (Konzernchefin) → Ministerin: drei der vier
Stationen stehen in diesem Graphen, verteilt auf vier nicht zusammengeführte
Knoten — eine davon sogar mit Tippfehler in der Quelle („Katharina"). Auch
das: Futter für die Dedup-Übung.

**Aber.** Der FGS-Auftrag des Ministeriums selbst steht **nicht** im
Lobbyregister — das Register erfasst Lobbyarbeit *Richtung* Regierung, nicht
die Auftragsvergabe *der* Regierung. Diese Geschichte kam über
Auskunftsanfragen, nicht über diese Daten.

---

## Lead 4: Moving MountAIns — eine Gästeliste trifft den Graphen

**Die Ausgangslage.** Im Herbst war Ministerin Reiche „rein privat" auf einem
exklusiven Lobby-Netzwerkevent in Tirol, organisiert von Karl-Theodor zu
Guttenberg und Sebastian Kurz. Auskünfte dazu: keine. Anfang des Jahres
veröffentlichte FragDenStaat die Teilnehmenden-Broschüre:
<https://fragdenstaat.de/dokumente/274347-moving-mountains-2025/>

**Schritt 1: Die Gästeliste holen.** Die Broschüre liegt bei FragDenStaat mit
Texterkennung vor; die API liefert den Text aller 79 Seiten frei Haus:

```bash
curl -s "https://fragdenstaat.de/api/v1/document/274347/" \
  | jq -r '.pages[].content' > teilnehmende.txt
```

Schon beim Lesen fällt auf: Die Broschüre führt **„H.E. Katherina Reiche,
Federal Minister"** mit eigener Teilnehmerinnen-Seite — das Dokument
widerspricht dem „rein privat" ganz von selbst. Daneben: Ischinger,
Schallenberg, Roubini, Miliband, mehrere Minister und Botschafter, dazu viel
Tech- und Finanzprominenz.

**Schritt 2: Namen gegen den Graphen halten.** Welche Gäste sind in
Deutschland als Lobbyist:innen registriert?

```cypher
// Gästeliste (Auszug) gegen die Namensknoten des Graphen
MATCH (n:name)
WHERE toLower(n.caption) IN
      ['karl-theodor zu guttenberg', 'sebastian kurz', 'wolfgang ischinger',
       'moritz von der linden', 'eric demuth', 'rainer seele']
MATCH (n)<-[:HAS_NAME]-(treffer)
RETURN n.caption AS gast, treffer.caption, labels(treffer) AS rollen,
       treffer.datasets AS quelle;
```

Drei Treffer, alle drei `RoleLobby`:

- **Moritz von der Linden**, CEO von Marvel Fusion,
- **Eric Demuth**, CEO von Bitpanda,
- **Rainer Seele**, registriert für XRG P.J.S.C. (den Energie-Arm der
  Staatsfirma ADNOC aus Abu Dhabi — die VAE-Botschaft stand ebenfalls auf der
  Gästeliste).

Guttenberg, Kurz und Ischinger dagegen: kein Eintrag — auch ein Befund.

**Schritt 3: Der Amtsbezug.** Was will Marvel Fusion von der Politik? Der
Registereintrag beantwortet das erstaunlich präzise:

```cypher
// Das komplette Lobbyregister-Profil von Marvel Fusion
MATCH (marvel:Organization {caption:'Marvel Fusion GmbH'})-[verbindung]-(gegenueber)
RETURN type(verbindung) AS art, gegenueber.caption AS womit;
```

Marvel Fusion lobbyiert am **„Rechtsrahmen für … Fusionskraftwerke"**, ist
Mitglied bei Pro-Fusion e.V. und im Wirtschaftsrat (CDU-nah) — und weist
Zuwendungen vom **Bundesforschungsministerium** und vom EU-Innovationsfonds
aus. Fusionsregulierung und -förderung: exakt das Ressort der anwesenden
Ministerin. Und Bitpanda? Ein Blick auf die Spenden:

```cypher
// Bitpandas Parteispenden
MATCH (bitpanda)-[spende:PAID]->(partei)
WHERE bitpanda.caption CONTAINS 'Bitpanda'
RETURN bitpanda.caption, spende.amountEur[0] AS betrag_eur,
       spende.date[0] AS jahr, partei.caption AS an;
```

2025: je 500.000 € an CDU, SPD und FDP plus 250.000 € an die CSU — 1,75
Millionen in einem Jahr, quer durch die (fast) ganze Parteienlandschaft.

**Aber.** Das Event selbst, die Einladungslogik, wer mit wem sprach — all das
steht in keiner unserer Quellen. Der Graph beantwortet hier nur die engere
Frage: *Wer auf dieser Liste hat dokumentierte Lobby- oder Spendenbeziehungen
zur deutschen Politik?* Für alles Weitere: Broschüre lesen, Anfragen stellen.

---

## Lead 5: Harald Christ — der Allparteien-Spender mit eigener Agentur

**Die Ausgangslage.** Harald Christ war SPD-Mitglied, dann FDP-Schatzmeister,
betreibt heute eine Lobbyagentur, spendet rege und sitzt u. a. dem Beirat für
das Sondervermögen der Bundesregierung vor.

**Schritt 1: Die Spenden-Biografie.** Eine einzige Abfrage erzählt den ganzen
Lebenslauf:

```cypher
// Alle Spenden von Harald Christ und seiner Agentur, chronologisch
MATCH (spender)-[spende:PAID]->(partei)
WHERE spender.caption IN ['Christ, Harald', 'Christ&Company']
RETURN spender.caption AS wer, spende.amountEur[0] AS betrag_eur,
       spende.date[0] AS jahr, partei.caption AS an
ORDER BY spende.date[0];
```

SPD (2007, 2017) → FDP (2020, zur Schatzmeister-Zeit: 63.300 €) → und dann
2024 der Befund, der hängen bleibt: **je 40.000 € an CDU, CSU, FDP, Grüne und
SPD — im selben Jahr, an alle.** Die Agentur legte 2023 nach: 100.000 € an die
FDP, je 51.000 € an SPD, CDU und Grüne.

**Schritt 2: Die Agentur.** Christ & Company gehört mit 7 geflaggten
Ex-Amtsträger:innen ebenfalls in die Top-Liste des Registers (Abfrage siehe
Lead 3). Namentlich:

```cypher
// Geflaggte Ex-Amtsträger:innen bei Christ & Company
MATCH (person:RoleLobby:Politician)-[:REPRESENTS]->(:Organization {caption:'Christ & Company GmbH & Co. KG'})
RETURN person.caption;
```

Darunter **Dr. Jens Zimmermann**, langjähriger SPD-Bundestagsabgeordneter. Der
Namensknoten-Check zeigt seine komplette Spur durch die Datensätze — PEP-Liste,
AbgeordnetenWatch, Lobbykontakte, Spenden, Lobbyregister:

```cypher
// Jens Zimmermann: ein Name, ein halbes Dutzend Knoten quer durch die Quellen
MATCH (n:name)
WHERE n.caption ENDS WITH 'Jens Zimmermann'
MATCH (n)<-[:HAS_NAME]-(knoten)
RETURN n.caption, knoten.id, labels(knoten) AS rollen, knoten.datasets AS quelle;
```

**Schritt 3: Das Fundstück.** In den Aufträgen der Agentur steckt eine
Übernahme-Geschichte im Klartext — ein Mandatstext beginnt mit „Joschka
Fischer & Company berät Anglo American …", hängt aber an Christ & Company:

```cypher
// Der geerbte Auftrag: Joschka Fischers Anglo-American-Mandat bei Christ & Company
MATCH (auftrag:Contract)-[:AWARDED_TO]->(wer)
WHERE auftrag.caption STARTS WITH 'Joschka Fischer & Company'
RETURN substring(auftrag.caption, 0, 200) AS auftragstext,
       wer.caption AS vergeben_an, labels(wer) AS rolle;
```

Die Agentur des Ex-Außenministers hat ihr Geschäft eingestellt; das Mandat
läuft bei Christ weiter — und das Register hat den alten Text gleich
mitkopiert. Daneben im Portfolio: die Bayer AG.

**Aber.** Christs Beiratsvorsitz beim Sondervermögen steht in keiner unserer
Quellen — Gremienbesetzungen der Bundesregierung sind (noch) kein Datensatz
dieser Pipeline.

---

## Werkzeugkasten: Abfragen für eigene Leads

Die Muster oben funktionieren für jeden Namen. Zum Selbst-Weiterbohren:

```cypher
// 1. Volltextsuche: Wer oder was taucht zu einem Stichwort auf?
MATCH (n) WHERE toLower(n.caption) CONTAINS 'suchbegriff'
RETURN n.caption, labels(n), n.datasets LIMIT 25;

// 2. Top-Spender:innen einer beliebigen Partei
MATCH (spender)-[spende:PAID]->(partei:PolParty {caption:'CDU'})
RETURN spender.caption, spende.amountEur[0] AS eur, spende.date[0] AS jahr
ORDER BY toFloat(spende.amountEur[0]) DESC LIMIT 20;

// 3. Drehtür-Scanner: Lobbyist:innen einer Organisation mit Politik-Vergangenheit
MATCH (lobbyist:RoleLobby)-[:REPRESENTS]->(org {caption:'…'})
MATCH (lobbyist)-[:HAS_NAME]->(:name)<-[:HAS_NAME]-(politik:Politician)
RETURN lobbyist.caption, politik.id, politik.datasets;

// 4. Ego-Netzwerk einer Organisation als Bild (zwei Schritte weit)
MATCH pfad = (org {caption:'…'})-[*1..2]-()
RETURN pfad LIMIT 200;
```

## Was der Graph nicht weiß — und was als Nächstes käme

- **Namensgleichheit ist kein Identitätsbeweis.** Jeder Treffer über einen
  Namensknoten ist ein Rechercheauftrag, kein Ergebnis.
- **Die Quellen haben Ränder.** Lobbyregister erst ab 2022 (Wüst/EUTOP:
  unsichtbar), Regierungsaufträge an Agenturen fehlen (Reiche/FGS), Firmen
  außerhalb der Lobby- und Spendenwelt fehlen (Böttcher AG), Gremien wie der
  Sondervermögen-Beirat fehlen (Christ).
- **Dubletten sind Programm.** Wüst dreimal, Reiche viermal, Zimmermann ein
  halbes Dutzend Mal: Genau dafür gibt es `make xref` und `make dedupe` — wer
  die Übung macht, sieht danach in `data/schland.json` (und nach `make graph`
  im Browser) zusammengeführte Personen statt Namens-Brücken.
