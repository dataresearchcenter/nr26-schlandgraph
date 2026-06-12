# Graph-Modell (Neo4j)

Modell-Referenz für den Schlandgraph, wie ihn `ftmg` aus den aggregierten
FollowTheMoney-Entitäten (`data/schland.json`) in Neo4j erzeugt. Gedacht als
Kontext, um daraus **Cypher-Abfragen zu generieren**. Die genaue Knoten- und
Kantenmenge wird von `config/graph.yml` bestimmt; alle Namen unten entsprechen
dieser Konfiguration.

> Hinweis: Bezeichner (Labels, Relationship-Typen) sind bewusst englisch, da
> Cypher und das FtM-Modell englisch sind.

## Grundprinzip

Drei Bausteine entstehen aus den FtM-Daten:

1. **Entity-Knoten** — jede „echte“ Entität (Person, Organisation, Firma …)
   wird ein Knoten.
2. **Relationships** — FtM-*Edge-Schemata* (Mitgliedschaft, Zahlung …) werden
   zu Kanten zwischen Entity-Knoten.
3. **Reifizierte Wert-Knoten** — geteilte Werte (Name, Adresse, E-Mail …) werden
   eigene Knoten, an denen mehrere Entitäten hängen. So werden gemeinsame Werte
   sofort als Verbindung sichtbar — der Kern der Graph-Recherche.

## Knoten

### Entity-Knoten

Jede Entität, deren Schema nicht ignoriert ist, wird zu einem Knoten. Knoten
tragen **mehrere Labels**: das Basis-Label `Entity`, das eigene Schema-Label
**plus alle Eltern-Schemata** der FtM-Typhierarchie.

Die folgenden Label-Mengen sind gegen die laufende Neo4j-Instanz verifiziert
(die genau vorkommenden Schemata hängen von den geladenen Daten ab):

| FtM-Schema | Labels am Knoten |
|---|---|
| Person | `Entity` · `Human` · `LegalEntity` |
| Organization | `Entity` · `Organization` · `LegalEntity` |
| PolParty | `Entity` · `PolParty` · `Organization` · `LegalEntity` |
| Company | `Entity` · `Company` · `Organization` · `LegalEntity` · `Asset` |
| PublicBody | `Entity` · `PublicBody` · `Organization` · `LegalEntity` |
| Project | `Entity` · `Project` |
| Contract | `Entity` · `Contract` · `Asset` |
| Document | `Entity` · `Document` |
| Article | `Entity` · `Article` · `Document` |
| Event | `Entity` · `Event` |

> Hinweis: Die abstrakten FtM-Wurzeln `Thing` und `Interval` werden **nicht**
> als Label vergeben — nur `Entity`, das Schema-Label und die konkreten
> Eltern-Schemata. `PolParty` ist ein **Schema**-Label (politische Partei,
> Unterklasse von Organization), kein Topic.

Zwei wichtige Sonderfälle aus `config/graph.yml`:

- **`Person` ⇒ Label `Human`** (nicht `Person`!). Das Schema-Label ist
  umbenannt; die Eltern-Labels (`LegalEntity`) bleiben.
- **Ignorierte Schemata werden gar nicht zu Knoten:** `Position` und `Address`.
  (Adressen erscheinen stattdessen als reifizierte Wert-Knoten, s.u.)

Praktisch heißt das: über `Entity` erreicht man **alle** Entitäten, über
`LegalEntity` alle Personen + Organisationen + Firmen, über `Human` nur
natürliche Personen.

> **`Company` ist hier fast nie vergeben — nicht zum Finden von Firmen
> benutzen.** Das Schema-Label hängt von der Quelle ab; die meisten Quellen
> typisieren Unternehmen nur als `Organization`. Im Lobbyregister tragen z. B.
> nur **10 von ~24.000** Orgs das Label `Company` — Deutsche Telekom AG,
> ThyssenKrupp AG, Deloitte, Schufa usw. sind alle bloß `Organization`.
> `MATCH (c:Company)` verfehlt also fast alle echten Firmen. Stattdessen auf
> `Organization`/`LegalEntity` matchen und z. B. über den `caption`
> (Endung `AG`/`GmbH`/`SE`/`KG`) oder die Rolle weiter eingrenzen.

#### Eigenschaften (Properties) an Entity-Knoten

- `id` — kanonische Entitäts-ID (eindeutig, indiziert). Schlüssel für Joins.
- `caption` — menschenlesbare Bezeichnung (für Anzeige).
- `datasets` — Liste der Quell-Datensätze (z. B. `["de_lobbyregister",
  "de_bundestag"]`). Mehrere Werte = die Entität wurde über Quellen hinweg
  zusammengeführt (Dedup-Treffer!).
- Alle skalaren FtM-Properties des Schemas (z. B. `name`, `firstName`,
  `lastName`, `birthDate`, `nationality`, `country`, `incorporationDate` …),
  jeweils als **Liste von Strings**. Ausgenommen: lange Freitexte, Topics und
  Entity-Referenzen (die werden zu Labels bzw. Kanten).

### Topic-Labels

Klassifizierende FtM-*Topics* werden als **zusätzliche Labels** an Entity-Knoten
gehängt. Die in `config/graph.yml` aufgeführten Topics bekommen das dort
festgelegte Label; **nicht aufgeführte Topics erhalten ein automatisch aus dem
Topic-Namen gebildetes CamelCase-Label** (z. B. `role.lobby` → `RoleLobby`,
`gov` → `Gov`). Die Spalte „Im Graphen" zählt die Knoten in der laufenden
Instanz — viele in der Config definierte Labels kommen mangels passender Daten
(noch) nicht vor:

| Topic | Zusatz-Label | Im Graphen |
|---|---|---|
| `role.lobby` *(auto)* | `RoleLobby` | 39.704 |
| `role.pep` | `Politician` | 36.967 |
| `gov.executive` | `Executive` | 35 |
| `gov` *(auto)* | `Gov` | 17 |
| `crime.fin` | `FinancialCrime` | 4 |
| `role.rca` | `CloseAssociate` | 0 |
| `poi` | `PersonOfInterest` | 0 |
| `gov.head` | `HeadOfState` | 0 |
| `gov.legislative` | `Legislative` | 0 |
| `gov.judicial` | `Judicial` | 0 |
| `fin.bank` | `Bank` | 0 |
| `fin` | `FinancialServices` | 0 |
| `sanction` | `Sanctioned` | 0 |

Die Verwaltungsebenen `gov.national` / `gov.state` / `gov.muni` sind in der
Config explizit `ignore` und erzeugen daher kein Label.

Beispiel: `MATCH (p:Politician) RETURN p` liefert alle als PEP markierten
Personen.

### Reifizierte Wert-Knoten

Für die in `config/graph.yml` mit `reify: true` markierten Werttypen wird **pro
eindeutigem Wert ein gemeinsamer Knoten** angelegt. Label = Typname
(**kleingeschrieben**), Kante vom Entity-Knoten dorthin:

| Werttyp | Knoten-Label | Kante (Entity → Wert) |
|---|---|---|
| name | `name` | `HAS_NAME` |
| address | `address` | `HAS_ADDRESS` |
| identifier | `identifier` | `HAS_IDENTIFIER` |
| phone | `phone` | `HAS_PHONE` |
| email | `email` | `HAS_EMAIL` |
| url | `url` | `HAS_URL` |

Wert-Knoten haben `id` (normalisierter Wert) und `caption` (Originalwert).

Normalisierung/Filter beim Reifizieren: Namen ohne Leerzeichen werden
übersprungen; Identifier < 7 Zeichen verworfen und normalisiert; Telefonnummern
auf Ziffern reduziert (mind. 5); URLs vergleichsnormalisiert; E-Mails
kleingeschrieben.

> **`make graph-prune`** löscht Wert-Knoten mit **weniger als 2** verschiedenen
> Quell-Entitäten. Nach dem Prune repräsentiert ein verbleibender `address`-/
> `name`-Knoten also immer einen **geteilten** Wert — d. h. eine echte
> Verbindung.

## Relationships (Kanten)

### Aus FtM-Edge-Schemata

FtM-Beziehungsentitäten werden zu Kanten (nicht zu Knoten). Der Relationship-Typ
ist der großgeschriebene FtM-`edge_label`. Richtung: Quelle → Ziel.

Folgende Kantentypen sind in der laufenden Instanz vorhanden (Spalte „Im
Graphen" = Anzahl Kanten), sortiert nach Häufigkeit:

| FtM-Schema | Relationship | von → nach | featured Felder | Im Graphen |
|---|---|---|---|---|
| Membership | `BELONGS_TO` | LegalEntity → Organization | role, startDate, date | 87.871 |
| Representation | `REPRESENTS` | LegalEntity → LegalEntity | role | 39.704 |
| Payment | `PAID` | LegalEntity → LegalEntity | amount, amountEur, currency, date | 34.944 |
| (Projektteilnahme) | `PARTICIPATES_IN` | LegalEntity → Project | — | 20.010 |
| (Vergabe/Zuschlag) | `AWARDED_TO` | Contract → LegalEntity | — | 2.611 |
| Directorship | `DIRECTS` | LegalEntity → Organization | role, startDate, endDate | 1.669 |
| Employment | `WORKS_FOR` | Person → Organization | — | 1 |

Kanten tragen immer `id` und `datasets`, dazu die oben genannten featured Felder
(als Listen). `PARTICIPATES_IN` und `AWARDED_TO` stammen aus den geladenen
Projekt-/Vergabedaten (EU-Förderung) und tragen außer `id`/`datasets` keine
featured Felder.

> **Achtung `amount` / `amountEur` sind oft leer.** Bei `PAID`-Kanten aus
> Sponsoring-Daten fehlt der Eurobetrag (z. B. ~500 der ~27.000 `PAID →
> PolParty`-Kanten haben kein `amountEur`). Beim Summieren also immer
> `coalesce(...)` einsetzen, sonst fällt die Kante stillschweigend raus.

**In den Daten (noch) nicht vorhanden**, obwohl als FtM-Edge-Schema möglich —
also keine Kanten in der aktuellen Instanz: `OWNS` (Ownership),
`RELATED_TO` (Family), `ASSOCIATED_WITH` (Associate), `LINKED_TO` (UnknownLink).

**Ignoriert** (keine Kante): `Occupancy` (`HOLDS`, Person → Position) —
gestrichen, weil auch `Position` als Knoten ignoriert ist.

> Welche dieser Typen tatsächlich vorkommen, hängt von den geladenen Daten ab:
> Parteispenden/Sponsoring → `PAID`; Lobbyregister/Lobbykontakte →
> `REPRESENTS` / `BELONGS_TO`; Laundromat → `PAID` zwischen Firmen.

### Aus Entity-Properties

Entity-referenzierende Properties, die **kein** eigenes Edge-Schema sind, werden
direkt zu Kanten; der Typ ist der großgeschriebene Property-Name (z. B.
`parent` → `PARENT`). Selten in diesen Daten, der Vollständigkeit halber genannt.

## Konventionen für Abfragen

- **`id` ist eindeutig und indiziert** (Unique Constraint pro Label) — der beste
  Einstieg für Lookups und Joins.
- **`caption`** für die Anzeige verwenden; Properties sind **immer Listen**, also
  `p.name[0]` oder `ANY(...)` bedenken.
- Für schema-übergreifende Treffer auf `Entity` matchen; für „nur Menschen“ auf
  `Human`; für „Person oder Organisation“ auf `LegalEntity`.
- **Zusammengeführte Entitäten** erkennt man an mehr als einem Eintrag in
  `datasets` — der eigentliche „Follow the Money“-Treffer über Quellen hinweg.
- **Der Dedup ist konservativ — dieselbe reale Org existiert oft als mehrere
  un-gemergte Knoten** (z. B. „Deutsche Telekom AG“ dreimal mit
  unterschiedlichen Label-Mengen). Sich allein auf `datasets` zu verlassen
  unterschätzt Querverbindungen also stark. **Lockerer joinen über den
  geteilten `name`-Knoten:** `(a)-[:HAS_NAME]->()<-[:HAS_NAME]-(b)`. Nach
  `graph-prune` steht ein `name`-Knoten immer für einen **geteilten**
  normalisierten Namen, ist also ein belastbares (wenn auch nicht perfektes)
  Merge-Signal jenseits des fertigen Dedups.
- **Nebentätigkeiten (`de_abgeordnetenwatch_sidejobs`) sind keine eigene Kante**,
  sondern `BELONGS_TO` (Beiräte/Mitgliedschaften) bzw. `DIRECTS` (Aufsichtsrat
  etc.); die Art steht in `r.role`. **Beträge gibt es nicht** — „Nebeneinkünfte“
  im Wortsinn lässt sich aus diesen Kanten nicht ableiten, nur die Funktion
  (oft „ehrenamtlich“).
- **Parteien stehen selbst im `de_lobbyregister`** (z. B. die Grünen). Bei
  „Org ist im Lobbyregister“-Joins daher `AND NOT o:PolParty` setzen, sonst
  leakt schlichte Parteimitgliedschaft als vermeintliche Lobby-Tätigkeit hinein.

## Beispiel-Abfragen

```cypher
// Personen, die in mehreren Quellen auftauchen (Dedup-Treffer)
MATCH (p:Human)
WHERE size(p.datasets) > 1
RETURN p.caption, p.datasets LIMIT 50;

// Geteilte Adressen: zwei Entitäten an derselben Adresse
MATCH (a:Human)-[:HAS_ADDRESS]->(addr)<-[:HAS_ADDRESS]-(b:Human)
WHERE a.id < b.id
RETURN a.caption, addr.caption, b.caption LIMIT 50;

// Politiker:innen und ihre Zahlungsbeziehungen
MATCH (p:Politician)-[r:PAID]->(t)
RETURN p.caption, r.amount, t.caption LIMIT 50;

// Wer ist im Lobbyregister vertreten (Representation)?
MATCH (rep:LegalEntity)-[:REPRESENTS]->(client:LegalEntity)
RETURN rep.caption, client.caption LIMIT 50;

// Nebentätigkeiten von Politiker:innen bei Lobbyregister-Orgs.
// Lockerer Join über den geteilten name-Knoten (fängt auch vom Dedup
// verpasste Merges); NOT o:PolParty filtert reine Parteimitgliedschaft raus.
MATCH (p:Politician)-[r]->(o)-[:HAS_NAME]->()<-[:HAS_NAME]-(lobby)
WHERE "de_abgeordnetenwatch_sidejobs" IN r.datasets
  AND "de_lobbyregister" IN lobby.datasets
  AND NOT o:PolParty
RETURN p.caption AS politiker, o.caption AS org,
       coalesce(r.role[0], "") AS rolle
ORDER BY politiker LIMIT 50;

// Verbindung zwischen einer Person und dem Aserbaidschan-Laundromat
MATCH path = (p:Human)-[*1..3]-(c:Company)
WHERE "az_laundromat" IN c.datasets
RETURN path LIMIT 25;

// Kern-Treffer dieses Experiments: Firmen, die in einer Quelle (hier
// az_laundromat) auftauchen UND an deutsche Parteien gespendet haben.
// Properties sind Listen → [0]; amountEur kann fehlen → coalesce.
MATCH (c:Company)-[r:PAID]->(p:PolParty)
WHERE "az_laundromat" IN c.datasets
RETURN c.caption AS firma, p.caption AS partei,
       count(r) AS spenden,
       sum(toFloat(coalesce(r.amountEur[0], "0"))) AS summe_eur
ORDER BY summe_eur DESC;
```
