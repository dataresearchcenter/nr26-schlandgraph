# Schlandgraph

Begleit-Repository zum nr26-Workshop **„Wenn das Geld Spuren hinterlässt:
Recherchieren mit dem FollowTheMoney-Toolkit“**.

Wir bauen eine kleine, aber vollständige Daten-Pipeline: von rohen Datensätzen
zu politischem Einfluss und Lobbyismus in Deutschland bis zu einem
durchsuchbaren, deduplizierten Netzwerk-Graphen. Jede Stufe demonstriert einen
Baustein des [FollowTheMoney](https://followthemoney.tech)-Stacks.

## Worum geht es?

Die Pipeline kombiniert zwei Arten von Quellen:

**Deutsche Einfluss- und Lobbydaten** (von [data.ftm.store](https://data.ftm.store),
bereits ins FtM-Format gemappt):

- `de_abgeordnetenwatch_full` — Abgeordnete, Mandate, Parteien
- `de_abgeordnetenwatch_sidejobs` — Nebentätigkeiten
- `de_abgeordnetenwatch_lobbykontakte` — protokollierte Lobbykontakte
- `de_abgeordnetenwatch_parteispenden` — Parteispenden
- `de_abgeordnetenwatch_sponsoring` — Sponsoring
- `de_lobbyregister` — Lobbyregister des Bundestages *(am Quellportal
  gelegentlich leer; die Pipeline verkraftet das)*

**Vergleichsdaten von [OpenSanctions](https://www.opensanctions.org)**, um
Personen über Quellen hinweg zu verknüpfen:

- `de_bundestag`, `de_bundesrat` — PEP-Listen (politisch exponierte Personen)
- `az_laundromat` — der Aserbaidschan-Laundromat (Geldwäsche-/Einflussschema,
  das auch europäische Politiker:innen erreichte)

Der investigative Reiz: Taucht dieselbe Person in AbgeordnetenWatch **und** in
einer PEP- oder Laundromat-Liste auf? Genau das macht die Dedup-Stufe sichtbar.

## Voraussetzungen

- Python-Umgebung mit `followthemoney` und `nomenklatura` (liefert die CLIs
  `ftm` und `nk`)
- [`qsv`](https://github.com/dathere/qsv) für schnelle CSV-Operationen
- `curl`, `make`
- *(optional, nur für die Graph-Stufe)* Docker + das Paket
  [`followthemoney-graph`](https://github.com/opensanctions/followthemoney-graph)
  (liefert `ftmg`)

## Die Pipeline Schritt für Schritt

```
download → statements → combine → resolve → aggregate → xref → dedupe → (graph)
```

`make help` zeigt alle Targets. Der Kernlauf:

```bash
make download     # 1. fertige FtM-Entitäten von beiden Portalen holen
make all          # 2.–5. statements → combine → resolve → aggregate
```

Ergebnis ist `data/schland.json` — ein Strom aggregierter FtM-Entitäten.

### 1. `download` — Daten holen

Beide Portale liefern Entitäten als
[FtM-JSON](https://followthemoney.tech/docs/entities/) (eine Entität pro Zeile).
Wir müssen also nichts selbst scrapen oder mappen — der Schritt zeigt, dass der
FtM-Stack ein gemeinsames Austauschformat hat, in das CSVs, APIs und Scraper
münden.

### 2. `statements` — Entitäten in Aussagen zerlegen

```bash
ftm statements -d <dataset> -f csv quelle.json -o stmt.csv
```

Jede Entität wird in einzelne [Statements](https://followthemoney.tech/docs/statements/)
zerlegt: „Entität X hat Property `name` = 'Y', laut Datensatz Z, gesehen am …“.
Das Statement-Modell ist die Grundlage für Herkunftsnachweis (welche Quelle sagt
was?) und für das spätere Zusammenführen.

### 3. `combine` — zusammenführen und Rauschen filtern

```bash
qsv cat rows stmt/*.csv | qsv search -v -s prop_type '^text$' -o schland.statements.csv
```

Alle Statements in eine Tabelle. Lange Freitexte (`prop_type = text`, z. B.
Beschreibungen) werfen wir raus — für Abgleich und Graph sind sie nur Ballast.

### 4. `resolve` — Dedup-Entscheidungen anwenden

```bash
nk apply-statements -i schland.statements.csv -o schland.resolved.csv -f csv
```

Setzt die `canonical_id` für jedes Statement gemäß den gespeicherten
Zusammenführungs-Entscheidungen (dem *Resolver*, `nomenklatura.db`). Beim ersten
Lauf ist der Resolver leer — Entitäten bleiben getrennt. Nach `make dedupe`
(s. u.) fließen die Entscheidungen hier ein.

### 5. `aggregate` — Statements zu Entitäten verdichten

```bash
qsv sort -s canonical_id schland.resolved.csv | ftm aggregate-statements -f csv -i - -o schland.json
```

Statements mit gleicher `canonical_id` werden zu einer Entität gerollt — bei
zusammengeführten Personen verschmelzen so die Aussagen aus AbgeordnetenWatch,
PEP-Liste und Laundromat zu **einem** Knoten.

### 6. `xref` — Dedup-Kandidaten finden

```bash
make xref     # nk xref -l 100000 --algorithm er-unstable -a 0.96 data/schland.json
```

Sucht ähnliche Entitäten und vergibt Scores. Paare über der `-a`-Schwelle (0.96)
werden automatisch zusammengeführt, der Rest wartet auf manuelle Beurteilung.

### 7. `dedupe` — Kandidaten beurteilen

```bash
make dedupe   # interaktive TUI
```

Hier entscheidet man Paar für Paar: dieselbe Person oder nicht? Die
Entscheidungen landen im Resolver. **Danach `make all` erneut laufen lassen**,
damit `data/schland.json` die Zusammenführungen widerspiegelt.

### 8. `graph` *(optional)* — ins Neo4j laden

```bash
docker compose up -d        # Neo4j starten (Browser: http://localhost:7474)
make graph                  # ftmg load config/graph.yml -d data/schland.json
make graph-prune            # einmalig referenzierte reifizierte Knoten entfernen
```

`ftmg` übersetzt die Entitäten in einen Property-Graphen. Gemäß
`config/graph.yml` werden geteilte Werte (Namen, Adressen, E-Mails …) als eigene
Knoten *reifiziert* — so wird eine gemeinsame Adresse zweier Personen sofort als
Verbindung sichtbar. Erkundung dann im Neo4j-Browser per Cypher, z. B.:

```cypher
// Personen, die sich eine Adresse teilen
MATCH (p1:Human)-[:ADDRESS]->(a)<-[:ADDRESS]-(p2:Human)
WHERE id(p1) < id(p2)
RETURN p1, a, p2 LIMIT 50;
```

## Aufräumen

```bash
make clean            # abgeleitete Dateien löschen, Downloads behalten
make clean-all        # alles inkl. Downloads
make flush-resolver   # Dedup-Entscheidungen + Xref-Index zurücksetzen
```
