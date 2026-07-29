# Spotify Music Analytics — End-to-End Data Analytics Project

**Author:** Srilakshmi N P | [GitHub](https://github.com/reesekat)

---

## Project Overview
An end-to-end data analytics project analyzing 114,000 Spotify tracks to uncover
what drives music popularity, how audio features relate to listener behavior,
and where Spotify's biggest content opportunities lie.

The project moves through the full pipeline: raw data → cleaning → relational
modeling → exploratory analysis (Python) → business intelligence analysis (SQL).
This README is a map of the repo — for the full write-up of *why* things were
built this way, see `Spotify_Music_Analytics_Documentation.docx`. For the
data-driven inferences behind every SQL query, see the comments inside
`sql_analysis_bi.sql` — this file doesn't repeat them.

---

## File Guide
| File | What's in it |
|------|---------------|
| `spotify_eda.ipynb` | Cleaning, star-schema normalization, and exploratory analysis (Python) |
| `sql_analysis.sql` | Database/table setup + 2 foundational queries |
| `sql_analysis_bi.sql` | 12-query SQL business intelligence layer, with inferences written inline |
| `fact_tracks.csv` / `dim_genre.csv` / `dim_artist.csv` / `bridge_track_artist.csv` | The normalized star-schema exports |
| `Spotify_Music_Analytics_Documentation.docx` | Full solution design doc — background, architecture, data model rationale, and chapter-by-chapter analysis |

---

## Business Questions Answered

**Python EDA:** genre popularity, explicit-content effect, audio-feature drivers,
valence by genre, energy vs. popularity, optimal duration, feature correlations.

**SQL Business Intelligence** (12 questions across 4 chapters — see table below):
artist consistency, collaboration impact, genre benchmarking, and catalog structure.

---

## Tools & Technologies
| Tool | Purpose |
|------|---------|
| Python (pandas, seaborn, matplotlib) | Data cleaning, EDA, visualisation |
| MySQL | Relational database, SQL analysis |
| Jupyter Notebook | Analysis environment |
| DuckDB | Local validation of SQL queries against source CSVs |

---

## Data Model — Star Schema
- **fact_tracks** — 114,000 track-genre rows with audio features and popularity metrics
- **dim_genre** — 114 unique genres
- **dim_artist** — 29,859 unique artists
- **bridge_track_artist** — many-to-many relationship between tracks and artists (158,293 rows)

> **Note:** `track_id` is not unique at the row level — the same track can appear
> multiple times, once per genre it's tagged with. This is documented in full
> (cause, effect, and how it's handled) in the docx (§5.8) and flagged inline
> in `sql_analysis_bi.sql` wherever it changes how a result should be read.

---

## SQL Business Intelligence — Query Catalog
Built on the star schema; deliberately doesn't repeat the Python EDA above.

| # | Chapter | Business Question |
|---|---------|-------------------|
| 1 | Artist Performance | Top artists by avg. popularity |
| 2 | Artist Performance | Consistency (STDDEV) |
| 3 | Artist Performance | One-Hit Wonder segmentation |
| 4 | Artist Performance | Top artist per genre (RANK) |
| 5 | Collaboration | Solo vs. collaboration share |
| 6 | Collaboration | Collab vs. solo popularity |
| 7 | Collaboration | Top collaborator pairs (self-join) |
| 8 | Genre Benchmarking | Genre vs. overall average |
| 9 | Genre Benchmarking | Explicit content over-index |
| 10 | Genre Benchmarking | Tracks-per-artist ratio |
| 11 | Catalog Analysis | Album depth vs. popularity |
| 12 | Catalog Analysis | Hidden gems (multi-CTE) |

Every query's inference (with real numbers, run against the actual data) lives
as a comment directly beneath it in `sql_analysis_bi.sql`.

---

## Headline Numbers
A handful of standout stats, for a reader who just wants the gist. Full detail
and every other finding is in `sql_analysis_bi.sql` (SQL layer) and the docx
(EDA + narrative):

- Comedy over-indexes hardest on explicit content — not hip-hop.
- Collaborations edge out solo tracks by ~2 popularity points; 38% of the catalog is collaborative.
- 3–5 minute tracks and moderate-to-high energy (0.50–0.75) both correlate with higher popularity.
- 7,309 tracks qualify as data-driven "hidden gems" — high popularity from otherwise low-visibility artists.
- No single audio feature predicts popularity; it's multi-dimensional.

## File Structure
```
├── spotify_eda.ipynb
├── sql_analysis.sql
├── sql_analysis_bi.sql
├── dim_genre.csv
├── dim_artist.csv
├── fact_tracks.csv
├── bridge_track_artist.csv
├── Spotify_Music_Analytics_Documentation.docx
└── README.md
```

---

*Dataset: Spotify Tracks Dataset — 114,000 tracks across 114 genres*
