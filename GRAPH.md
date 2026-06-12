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

| FtM-Schema | Labels am Knoten |
|---|---|
| Person | `Entity` · `Human` · `LegalEntity` · `Thing` |
| Organization | `Entity` · `Organization` · `LegalEntity` · `Thing` |
| Company | `Entity` · `Company` · `Organization` · `LegalEntity` · `Asset` · `Thing` |
| PublicBody | `Entity` · `PublicBody` · `Organization` · `LegalEntity` · `Thing` |
| Event | `Entity` · `Event` · `Interval` · `Thing` |

Zwei wichtige Sonderfälle aus `config/graph.yml`:

- **`Person` ⇒ Label `Human`** (nicht `Person`!). Das Schema-Label ist
  umbenannt; die Eltern-Labels (`LegalEntity`, `Thing`) bleiben.
- **Ignorierte Schemata werden gar nicht zu Knoten:** `Position` und `Address`.
  (Adressen erscheinen stattdessen als reifizierte Wert-Knoten, s.u.)

Praktisch heißt das: über `Entity` erreicht man **alle** Entitäten, über
`LegalEntity` alle Personen + Organisationen + Firmen, über `Human` nur
natürliche Personen.

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
gehängt (gemäß `topics:` in der Config). Relevant hier:

| Topic | Zusatz-Label |
|---|---|
| `role.pep` | `Politician` |
| `role.rca` | `CloseAssociate` |
| `poi` | `PersonOfInterest` |
| `gov.head` / `gov.executive` / `gov.legislative` / `gov.judicial` | `HeadOfState` / `Executive` / `Legislative` / `Judicial` |
| `fin.bank` / `fin` | `Bank` / `FinancialServices` |
| `crime.fin` | `FinancialCrime` |
| `sanction` | `Sanctioned` |

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

| FtM-Schema | Relationship | von → nach | typische Felder |
|---|---|---|---|
| Membership | `BELONGS_TO` | LegalEntity → Organization | role, startDate, endDate |
| Representation | `REPRESENTS` | LegalEntity → LegalEntity | role, startDate, endDate |
| Directorship | `DIRECTS` | LegalEntity → Organization | role |
| Ownership | `OWNS` | LegalEntity → Asset | percentage, startDate |
| Payment | `PAID` | LegalEntity → LegalEntity | amount, currency, date, purpose |
| Employment | `WORKS_FOR` | Person → Organization | role |
| Family | `RELATED_TO` | Person → Person | relationship |
| Associate | `ASSOCIATED_WITH` | Person → Person | relationship |
| UnknownLink | `LINKED_TO` | Thing → Thing | role |

Kanten tragen `id`, `datasets` und die oben genannten featured Felder (als
Listen). **Ignoriert** (keine Kante): `Occupancy` (`HOLDS`, Person → Position) —
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

// Verbindung zwischen einer Person und dem Aserbaidschan-Laundromat
MATCH path = (p:Human)-[*1..3]-(c:Company)
WHERE "az_laundromat" IN c.datasets
RETURN path LIMIT 25;
```
