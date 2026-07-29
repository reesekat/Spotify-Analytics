# Spotify Music Analytics — End-to-End Data Analytics Project

**Author:** Srilakshmi N P | [GitHub](https://github.com/reesekat)

---

## Project Overview
An end-to-end data analytics project analyzing 114,000 Spotify tracks to uncover
what drives music popularity, how audio features relate to listener behavior,
and where Spotify's biggest content opportunities lie.

Built as a portfolio project modelled on industry-standard analytical deliverables,
the project moves through the full pipeline: raw data → cleaning → relational
modeling → exploratory analysis (Python) → business intelligence analysis (SQL).

---

## Business Questions Answered

### Python EDA
- Which genres dominate Spotify in terms of popularity?
- Does explicit content affect track performance?
- What audio features define a popular track?
- Which genres make listeners feel the most positive?
- Do high-energy tracks perform better than calm ones?
- What is the optimal track duration for mainstream success?
- How do audio features correlate with each other and with popularity?

### SQL Business Intelligence Analysis
- Which artists perform consistently well versus rely on a single hit?
- Do collaborations outperform solo tracks?
- Who are an artist's most frequent, best-performing collaborators?
- How does each genre benchmark against the platform-wide average?
- Which genres over-index on explicit content?
- Which genres are dominated by a few artists versus wide open?
- Which low-visibility artists are producing breakout "hidden gem" tracks?

*(Full list of 12 SQL business questions below.)*

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
The raw dataset was normalized into a proper relational schema:

- **fact_tracks** — 114,000 track-genre rows with audio features and popularity metrics
- **dim_genre** — 114 unique genres
- **dim_artist** — 29,859 unique artists
- **bridge_track_artist** — many-to-many relationship between tracks and artists (158,293 rows)

### Data Quality Note
`track_id` is **not unique** at the row level in `fact_tracks`: 114,000 rows map
to only ~89,741 distinct `track_id` values. This is inherited from the source
dataset — the same physical track appears once per genre it is tagged with
(e.g. a track tagged both "latin" and "reggaeton" appears as two rows). This
means any join that fans out through `track_id` (collaboration analysis,
artist track counts, album track counts) can inflate raw counts for artists
or tracks that span many genres. It doesn't invalidate the analysis, but
counts should be read as "genre-tagged appearances" rather than strictly
"unique tracks" unless de-duplicated first. This is called out explicitly
in the SQL notebook wherever it materially affects an inference.

---

## Part 1 — EDA Highlights (Python)

### Chart 4 — Explicit vs Non-Explicit Popularity
Explicit tracks average 36.45 popularity vs 32.94 for non-explicit.
Spotify's algorithm does not penalise explicit content in discovery.

### Chart 5 — Energy vs Popularity
Sweet spot is moderate-to-high energy (0.50–0.75). Very high energy drops off
due to niche metal audiences limiting mainstream reach.

### Chart 6 — Happiest Genres by Valence
Salsa, forro and samba lead — culturally rooted genres with growing global
appeal among Gen Z dance communities.

### Chart 7 — Audio Feature Correlation Heatmap
No single feature strongly predicts popularity. Energy and acousticness
are near-perfect opposites (-0.73). Danceability and valence move together (0.49).

### Chart 8 — Track Duration Sweet Spot
3–5 minute tracks consistently outperform. Under 2 min fails to engage,
over 5 min loses listener attention.

### Chart 9 — Acoustic vs Energy Extremes
Classical and romance dominate acoustic. Death-metal and grindcore dominate energy.
"Happy" appearing in the energy top 10 is the standout anomaly.

---

## SQL Foundation (basic setup + initial queries, in `sql_analysis.sql`)

| Query | Business Question |
|-------|------------------|
| Query 1 | Top 10 genres by average popularity |
| Query 2 | Top 10 most prolific artists by track count |
| Query 3 | Explicit vs non-explicit — popularity, danceability, energy |
| Query 4 | Top 3 tracks per genre using RANK() window function |
| Query 5 | Audio feature profile of top 10 genres |

---

## Part 2 — SQL Business Intelligence Analysis
Built directly on the normalized star schema, this phase deliberately avoids
repeating the audio-feature EDA above and instead focuses on questions the
relational model is uniquely suited to answer: artist performance,
collaboration patterns, genre benchmarking, and catalog structure.

| # | Chapter | Query | Business Question |
|---|---------|-------|-------------------|
| 1 | Artist Performance | Top artists by avg. popularity | Who performs best with a meaningful catalog size? |
| 2 | Artist Performance | Consistency (STDDEV) | Which prolific artists are reliably consistent? |
| 3 | Artist Performance | One-Hit Wonder segmentation | Who is a one-hit wonder vs. a consistent performer? |
| 4 | Artist Performance | Top artist per genre (RANK) | Who leads each genre individually? |
| 5 | Collaboration | Solo vs. collaboration share | What % of the catalog is collaborative? |
| 6 | Collaboration | Collab vs. solo popularity | Do collaborations outperform solo tracks? |
| 7 | Collaboration | Top collaborator pairs (self-join) | Who collaborates most often, and how well do they perform together? |
| 8 | Genre Benchmarking | Genre vs. overall average | How does each genre compare to the platform average? |
| 9 | Genre Benchmarking | Explicit content over-index | Which genres over-index on explicit content? |
| 10 | Genre Benchmarking | Tracks-per-artist ratio | Which genres are concentrated vs. fragmented? |
| 11 | Catalog Analysis | Album depth vs. popularity | Do deeper albums perform better or worse? |
| 12 | Catalog Analysis | Hidden gems (multi-CTE) | Which low-visibility artists have breakout tracks? |

### Key SQL Findings
- **Comedy, not hip-hop, over-indexes hardest on explicit content** — 65.6% explicit vs. an 8.55% platform-wide rate (+57 points), well ahead of emo and sad.
- **Collaborations edge out solo tracks** — 34.25 avg popularity vs. 32.17, a modest but consistent ~2-point lift.
- **38.11% of the catalog is collaborative** (34,200 of 89,741 distinct tracks), 61.89% solo.
- **Deep "albums" are mostly mislabeled compilation playlists** — the highest track-count entries (e.g. "Alternative Christmas 2022," 195 tracks) are seasonal/mood playlists with near-zero average popularity, not curated artist releases. The true catalog average is only ~2.45 tracks per album.
- **Genre concentration varies widely** — honky-tonk is dominated by a small pool of artists (11.82 tracks/artist), while deep-house and show-tunes are highly fragmented (~1.15 tracks/artist).
- **7,309 tracks qualify as "hidden gems"** — popularity well above their genre average despite coming from artists with a thin catalog (e.g. "Quevedo: Bzrp Music Sessions, Vol. 52," 99 popularity vs. a hip-hop genre average of 37.76).
- **pop-film (+26.04) and k-pop (+23.66)** lead genre benchmarking against the platform average of 33.24; iranian, romance, and latin sit 25–31 points below it — the downside spread is larger than the upside.

---

## Key Findings
1. **K-pop and pop-film dominate popularity** — culturally driven genres outperform traditional ones
2. **Explicit tracks slightly outperform** — driven by hip-hop and rap dominance, though comedy is the genre most defined by explicit content
3. **No single audio feature predicts popularity** — it is multi-dimensional
4. **3–5 minutes is the optimal track length** for mainstream success
5. **Acoustic and energy are opposites** — two completely different listener worlds exist on Spotify
6. **Collaboration provides a modest but real popularity lift**, and the biggest, most frequent collaborator pairings cluster in reggaeton/Latin music
7. **Catalog depth does not equal quality** — the deepest "albums" in the dataset are generic compilation playlists that underperform, while true artist albums are shallow (~2.45 tracks on average)

## File Structure
├── spotify_eda.ipynb           # Main EDA notebook (Python)
├── sql_analysis.sql            # Database setup + initial SQL queries
├── sql_analysis_bi.sql         # SQL business intelligence analysis (12 queries, 4 chapters)
├── dim_genre.csv                # Genre dimension table
├── dim_artist.csv               # Artist dimension table
├── fact_tracks.csv              # Fact table
├── bridge_track_artist.csv      # Bridge table
└── README.md                    # This file


---

*Dataset: Spotify Tracks Dataset — 114,000 tracks across 114 genres*
