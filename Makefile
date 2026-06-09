# Schlandgraph — eine FollowTheMoney-Pipeline für den nr26-Workshop
#
# „Wenn das Geld Spuren hinterlässt“. Diese Pipeline lädt deutsche Daten zu
# politischem Einfluss und Lobbyismus (AbgeordnetenWatch, Lobbyregister),
# überführt sie ins FollowTheMoney-Entitätenmodell, gleicht sie mit
# OpenSanctions-Daten ab (Bundestag/Bundesrat-PEPs, Aserbaidschan-Laundromat),
# dedupliziert und lädt das Ergebnis optional in einen Neo4j-Graphen.
#
# Die Stufen entsprechen den Schritten des Workshops — siehe README.md.
# Reihenfolge:  download → statements → combine → resolve → aggregate
#               → xref → dedupe → (graph)

DATA := data

# Quell-URLs der beiden Datenportale
FTM := https://data.ftm.store
OS  := https://data.opensanctions.org/datasets/latest

# AbgeordnetenWatch + Lobbyregister: bereits ins FtM-Format gemappte Entitäten.
# Hinweis: de_lobbyregister kann am Quellportal zeitweise leer sein — die
# Pipeline verkraftet das (leere Statements-Datei mit nur einer Kopfzeile).
FTM_SETS := \
	de_abgeordnetenwatch_full \
	de_abgeordnetenwatch_sidejobs \
	de_abgeordnetenwatch_lobbykontakte \
	de_abgeordnetenwatch_parteispenden \
	de_abgeordnetenwatch_sponsoring \
	de_lobbyregister

# OpenSanctions: PEP-Listen + Aserbaidschan-Laundromat als Vergleichsdaten.
OS_SETS := de_bundestag de_bundesrat az_laundromat

FTM_JSON := $(patsubst %,$(DATA)/src/%.json,$(FTM_SETS))
OS_JSON  := $(patsubst %,$(DATA)/src/%.json,$(OS_SETS))
ALL_JSON := $(FTM_JSON) $(OS_JSON)
STMT     := $(patsubst $(DATA)/src/%.json,$(DATA)/stmt/%.csv,$(ALL_JSON))

GRAPH_CONFIG := config/graph.yml

.PHONY: all download statements xref dedupe graph graph-prune graph-trash \
        check-config clean clean-all flush-resolver help
.PRECIOUS: $(DATA)/src/%.json $(DATA)/stmt/%.csv
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# 1. Download — fertige FtM-Entitäten von beiden Portalen holen
# ---------------------------------------------------------------------------
$(DATA)/src $(DATA)/stmt:
	mkdir -p $@

# Statische Pattern-Rules: dieselbe Zielablage (data/src), aber je Liste eine
# andere Basis-URL. So bleibt die Herkunft pro Datensatz eindeutig.
$(FTM_JSON): $(DATA)/src/%.json: | $(DATA)/src
	curl -sf -R -o $@ $(FTM)/$*/entities.ftm.json

$(OS_JSON): $(DATA)/src/%.json: | $(DATA)/src
	curl -sf -R -o $@ $(OS)/$*/entities.ftm.json

download: $(ALL_JSON)

# ---------------------------------------------------------------------------
# 2. Statements — jede Entität in ihre Einzelaussagen zerlegen, je mit Quelle
# ---------------------------------------------------------------------------
$(STMT): $(DATA)/stmt/%.csv: $(DATA)/src/%.json | $(DATA)/stmt
	ftm statements -d $* -f csv $< -o $@

statements: $(STMT)

# ---------------------------------------------------------------------------
# 3. Combine — alle Statements zusammenführen; lange Freitexte (prop_type=text)
#    wegfiltern, da sie für Abgleich/Graph nur Rauschen sind
# ---------------------------------------------------------------------------
$(DATA)/schland.statements.csv: $(STMT)
	qsv cat rows $^ | qsv search -v -s prop_type '^text$$' -o $@

# ---------------------------------------------------------------------------
# 4. Resolve — gespeicherte Dedup-Entscheidungen anwenden (canonical_id setzen)
# ---------------------------------------------------------------------------
$(DATA)/schland.resolved.csv: $(DATA)/schland.statements.csv
	nk apply-statements -i $< -o $@ -f csv

# ---------------------------------------------------------------------------
# 5. Aggregate — Statements nach canonical_id zu fertigen Entitäten verdichten
# ---------------------------------------------------------------------------
$(DATA)/schland.json: $(DATA)/schland.resolved.csv
	qsv sort -s canonical_id $< | ftm aggregate-statements -f csv -i - -o $@

all: $(DATA)/schland.json

# ---------------------------------------------------------------------------
# 6. Xref — Dedup-Kandidaten finden (Ähnlichkeit zwischen Entitäten scoren)
# ---------------------------------------------------------------------------
xref: $(DATA)/schland.json
	nk xref -l 100000 --algorithm er-unstable -a 0.96 $<

# 7. Dedupe — Kandidaten interaktiv beurteilen (TUI). Danach `make all` neu
#    laufen lassen, damit die Entscheidungen in schland.json einfließen.
dedupe: $(DATA)/schland.json
	nk dedupe $<

# ---------------------------------------------------------------------------
# 8. Graph (optional) — ins Neo4j laden. Braucht `ftmg` + laufendes Neo4j
#    (siehe docker-compose.yml und README). Werte aus .envrc / Umgebung.
# ---------------------------------------------------------------------------
graph: $(DATA)/schland.json
	ftmg load $(GRAPH_CONFIG) -d $<

graph-prune:
	ftmg prune $(GRAPH_CONFIG)

graph-trash:
	ftmg trash $(GRAPH_CONFIG)

check-config:
	ftmg check-config $(GRAPH_CONFIG)

# ---------------------------------------------------------------------------
# Aufräumen
# ---------------------------------------------------------------------------
# Abgeleitete Artefakte löschen, Downloads behalten
clean:
	rm -f $(DATA)/schland.*.csv $(DATA)/schland.json
	rm -rf $(DATA)/stmt

# Alles inkl. Downloads löschen
clean-all: clean
	rm -rf $(DATA)

# Dedup-Entscheidungen + Xref-Index zurücksetzen (Resolver leeren)
flush-resolver:
	rm -f nomenklatura.db
	rm -rf nomenklatura.data

help:
	@echo "Schlandgraph — FollowTheMoney-Pipeline (nr26)"
	@echo ""
	@echo "  make download    fertige FtM-Entitäten von beiden Portalen holen"
	@echo "  make statements  Entitäten in Einzelaussagen (Statements) zerlegen"
	@echo "  make all         kombinieren, resolven, aggregieren -> data/schland.json"
	@echo "  make xref        Dedup-Kandidaten finden und scoren"
	@echo "  make dedupe      Kandidaten interaktiv beurteilen (danach 'make all')"
	@echo "  make graph       data/schland.json in Neo4j laden (optional, braucht ftmg)"
	@echo "  make graph-prune verwaiste reifizierte Knoten entfernen"
	@echo "  make check-config Graph-Konfiguration validieren"
	@echo ""
	@echo "  make clean / clean-all / flush-resolver   aufräumen"
