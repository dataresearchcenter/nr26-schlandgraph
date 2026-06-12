# Datenquellen

Übersicht über alle Datensätze, die der Schlandgraph kombiniert. Entitätszahlen
und Stand laut Portal-Metadaten (zuletzt geprüft 2026-06-09); sie ändern sich
mit jedem Crawl. Alle Datensätze liegen bereits im
[FollowTheMoney](https://followthemoney.tech)-Format vor.

| Datensatz | Titel | Entitäten | Herausgeber |
|---|---|---:|---|
| `de_abgeordnetenwatch_full` | German Legislators from AbgeordnetenWatch | 152.834 | Parlamentwatch e.V. |
| `de_abgeordnetenwatch_sidejobs` | Nebentätigkeiten Deutscher Politiker*innen | 28.882 | Parlamentwatch e.V. |
| `de_abgeordnetenwatch_lobbykontakte` | Lobbykontakte | 19.653 | Parlamentwatch e.V. |
| `de_abgeordnetenwatch_parteispenden` | Parteispenden | 4.795 | Parlamentwatch e.V. |
| `de_abgeordnetenwatch_sponsoring` | Parteien-Sponsoring | 1.805 | Parlamentwatch e.V. |
| `de_lobbyregister` | Lobbyregister des Deutschen Bundestages | 277.896 | Deutscher Bundestag |
| `eu_transparency_register` | EU Transparency Register | 53.275 | Europäische Kommission (Generalsekretariat) |
| `de_bundestag` | Members of the Bundestag | 5.739 | Deutscher Bundestag |
| `de_bundesrat` | Members of the Bundesrat | 359 | Bundesrat |
| `az_laundromat` | Azerbaijani Laundromat | 3.820 | OCCRP |

---

## AbgeordnetenWatch & Lobbyregister (data.ftm.store)

Bezugsquelle: [`data.ftm.store/lobbytracker`](https://data.ftm.store/lobbytracker/catalog.json)
— ein FtM-Katalog von [Parlamentwatch e.V. / abgeordnetenwatch.de](https://www.abgeordnetenwatch.de/).
abgeordnetenwatch.de dokumentiert Abstimmungsverhalten, Ausschussmitgliedschaften
und Nebeneinkünfte von Abgeordneten auf Bundes-, Landes- und EU-Ebene.

### `de_abgeordnetenwatch_full`
**German Legislators from AbgeordnetenWatch** · 152.834 Entitäten ·
Schemata: `Person`, `Organization`, `Position`

Mitglieder des Bundestages und der 16 Landtage. Der Kern-Personenbestand des
Graphen — hieran hängen Mandate, Parteien und Positionen.

### `de_abgeordnetenwatch_sidejobs`
**Nebentätigkeiten Deutscher Politiker*innen** · 28.882 Entitäten ·
Schemata: `Person`, `Organization`, `Address`

Gemeldete Nebeneinkünfte von Bundestagsabgeordneten — die klassische
„Wer zahlt nebenbei?“-Spur.

### `de_abgeordnetenwatch_lobbykontakte`
**Lobbykontakte** · 19.653 Entitäten ·
Schemata: `Person`, `Organization`, `PublicBody`

Gesammelte Treffen und ähnliche Kontakte zwischen (ehemaligen)
Regierungsmitgliedern, Ministerien und beteiligten Personen.

### `de_abgeordnetenwatch_parteispenden`
**Parteispenden** · 4.795 Entitäten ·
Schemata: `Person`, `LegalEntity`, `Organization`, `Address`

Parteispenden aus den jährlichen Rechenschaftsberichten der Parteien — verbindet
Spender:innen mit Parteien.

### `de_abgeordnetenwatch_sponsoring`
**Parteien-Sponsoring** · 1.805 Entitäten ·
Schemata: `LegalEntity`, `Organization`, `Event`, `Address`

Freiwillige Angaben der Parteien über Sponsoring von Veranstaltungen
(u.a. Parteitagen).

### `de_lobbyregister`
**Lobbyregister des Deutschen Bundestages** · 277.896 Entitäten ·
Herausgeber: [Deutscher Bundestag](https://www.lobbyregister.bundestag.de/)

Gesetzlich vorgeschriebenes Register (seit 2022) über Personen und
Organisationen mit Zugang zum Bundestag zu Lobbyzwecken — inkl. Auftraggeber,
Beauftragte und Geldgeber. Mit Abstand der größte Einzeldatensatz (~410 MB).

---

## EU-Transparenzdaten (data.ftm.store)

Dieselbe Mechanik eine Ebene höher: Wer in Berlin lobbyiert, tut das oft auch
in Brüssel. Beide Datensätze pflegt das
[Data and Research Center – DARC](https://dataresearchcenter.org/);
Originalquelle ist das Generalsekretariat der Europäischen Kommission.

### `eu_transparency_register`
**EU Transparency Register** · 53.275 Entitäten ·
Schemata: `Organization`, `Company`, `Person`, `Representation`, `Address`

Das verpflichtende [Transparenzregister](https://transparency-register.europa.eu/)
der EU-Institutionen: Organisationen, Firmen und akkreditierte
Vertreter:innen samt `Representation`-Verknüpfung (wer vertritt wen). Das
Brüsseler Gegenstück zum Bundestags-Lobbyregister — viele Organisationen
stehen in beiden Registern, ideales Material für die `xref`-Stufe.

---

## Vergleichsdaten (OpenSanctions)

Bezugsquelle: [`data.opensanctions.org`](https://www.opensanctions.org). Diese
Datensätze dienen dem **Quervergleich**: Taucht dieselbe Person sowohl in den
AbgeordnetenWatch-Daten als auch in einer PEP- oder Laundromat-Liste auf? Genau
solche Treffer macht die `xref`/`dedupe`-Stufe sichtbar.

### `de_bundestag`
**Germany Members of the Bundestag** · 5.739 Entitäten ·
Quelle: [bundestag.de](https://www.bundestag.de/abgeordnete/biografien)

Aktuelle und jüngere Bundestagsabgeordnete als PEP-Liste (politisch exponierte
Personen). Überschneidet sich mit AbgeordnetenWatch — guter Dedup-Testfall.

### `de_bundesrat`
**Germany Members of the Bundesrat** · 359 Entitäten ·
Quelle: [bundesrat.de](https://www.bundesrat.de/)

Aktuelle Mitglieder des Bundesrats (Vertretung der 16 Länder) als PEP-Liste.

### `az_laundromat`
**Azerbaijani Laundromat** · 3.820 Entitäten ·
Quelle: [OCCRP](https://www.occrp.org/en/project/the-azerbaijani-laundromat)

Transaktionsdaten der Danske Bank zu aserbaidschanischer Geldwäsche und
Einflussnahme in der europäischen Politik. Der „Follow the Money“-Aufhänger:
verbindet Zahlungen mit Personen und Firmen über Ländergrenzen hinweg.
