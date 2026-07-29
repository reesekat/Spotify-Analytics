DROP DATABASE spotify_analytics;
CREATE DATABASE spotify_analytics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE spotify_analytics;

CREATE TABLE dim_genre (
    genre_id INT PRIMARY KEY,
    genre_name TEXT
);

CREATE TABLE dim_artist (
    artist_id INT PRIMARY KEY,
    artist_name TEXT
);

CREATE TABLE fact_tracks (
    track_id VARCHAR(100) PRIMARY KEY,
    album_name TEXT,
    track_name TEXT,
    popularity INT,
    duration_ms INT,
    explicit BOOLEAN,
    danceability FLOAT,
    energy FLOAT,
    musical_key INT,
    loudness FLOAT,
    mode INT,
    speechiness FLOAT,
    acousticness FLOAT,
    instrumentalness FLOAT,
    liveness FLOAT,
    valence FLOAT,
    tempo FLOAT,
    time_signature INT,
    genre_id INT,
    FOREIGN KEY (genre_id) REFERENCES dim_genre(genre_id)
);

CREATE TABLE bridge_track_artist (
    track_id VARCHAR(100),
    artist_id INT,
    FOREIGN KEY (track_id) REFERENCES fact_tracks(track_id),
    FOREIGN KEY (artist_id) REFERENCES dim_artist(artist_id)
);

SELECT COUNT(*) FROM dim_genre;
SELECT COUNT(*) FROM dim_artist;
SELECT COUNT(*) FROM fact_tracks;
SELECT COUNT(*) FROM bridge_track_artist;


-- Query 1: Top 5 genres by average popularity
-- Business question: Which genres have the highest average popularity on Spotify?
SELECT d.genre_name, ROUND(AVG(f.popularity), 2) AS avg_popularity
FROM fact_tracks f
INNER JOIN dim_genre d ON f.genre_id = d.genre_id
GROUP BY d.genre_name
ORDER BY avg_popularity DESC
LIMIT 10;


DESCRIBE dim_artist;   -- artist id,artist name
DESCRIBE bridge_track_artist; -- trackid,artist id
describe dim_genre;
describe fact_tracks;

select d.artist_name,count(b.track_id) as number_of_tracks from dim_artist d 
inner join bridge_track_artist b on d.artist_id=b.artist_id 
group by d.artist_name order by number_of_tracks desc limit 10;

-- ##########################################################
-- DATA QUALITY NOTE (discovered while executing this analysis)
-- ##########################################################
-- fact_tracks has 114,000 rows but only ~89,741 DISTINCT track_id
-- values. The same physical track is repeated once per genre it
-- is tagged with (this is inherited from the source Kaggle
-- dataset, not introduced by the normalization). track_id is
-- therefore NOT a true primary key at the row-grain level.
--
-- Practical effect: any join that fans out through track_id
-- (collaboration self-joins, artist track counts, album track
-- counts) can inflate counts for artists/tracks that span many
-- genres. This does not invalidate the analysis, but counts
-- should be read as "genre-tagged appearances" rather than
-- strictly "unique tracks" unless de-duplicated first. Called
-- out explicitly wherever it materially affects an inference
-- below.
-- ##########################################################


-- ##########################################################
-- BUSINESS INTELLIGENCE ANALYSIS
-- Built on the normalized star schema (fact_tracks, dim_genre,
-- dim_artist, bridge_track_artist)
--
-- This section moves beyond the exploratory audio-feature
-- analysis already completed in Python and focuses on
-- relational, business-driven questions that the star schema
-- is specifically designed to answer: artist performance,
-- collaboration patterns, genre benchmarking, and catalog depth.
-- ##########################################################


-- ==========================================================
-- CHAPTER 1: ARTIST PERFORMANCE ANALYSIS
-- ==========================================================

-- ==========================================================
-- BUSINESS QUESTION 1
-- Who are the top 10 highest-performing artists by average
-- popularity, among artists with a meaningful catalog size?
--
-- Analysis:
-- Raw popularity averages can be misleading for artists with
-- only one or two tracks. Applying a minimum track-count filter
-- (HAVING) surfaces artists who are consistently popular rather
-- than artists who got lucky with a single hit. This helps
-- identify reliable roster talent for playlist placement.
-- ==========================================================
SELECT
    a.artist_name,
    COUNT(b.track_id) AS track_count,
    ROUND(AVG(f.popularity), 2) AS avg_popularity
FROM dim_artist a
INNER JOIN bridge_track_artist b ON a.artist_id = b.artist_id
INNER JOIN fact_tracks f ON b.track_id = f.track_id
GROUP BY a.artist_id, a.artist_name
HAVING COUNT(b.track_id) >= 5
ORDER BY avg_popularity DESC
LIMIT 10;
-- Inference:
-- Luar La L (90.50) and Bomba Estéreo (90.17) lead, followed by
-- Olivia Rodrigo, BYOR, Måneskin and Lil Nas X, all averaging
-- 80+ across 5-32 tracks. Unlike the raw "most popular track"
-- lists, this ranking rewards artists whose ENTIRE catalog
-- performs well, not just a single breakout single -- useful
-- for identifying reliably strong roster talent.


-- ==========================================================
-- BUSINESS QUESTION 2
-- Which prolific artists (10+ tracks) are the most CONSISTENT
-- performers, as opposed to artists whose popularity is driven
-- by a small number of outlier hits?
--
-- Analysis:
-- A low standard deviation of popularity alongside a solid
-- average indicates an artist whose entire catalog performs
-- reliably well — valuable for long-term partnership and
-- catalog licensing decisions, versus artists who are "hit or
-- miss".
-- ==========================================================
SELECT
    a.artist_name,
    COUNT(b.track_id) AS track_count,
    ROUND(AVG(f.popularity), 2) AS avg_popularity,
    ROUND(STDDEV(f.popularity), 2) AS popularity_stddev
FROM dim_artist a
INNER JOIN bridge_track_artist b ON a.artist_id = b.artist_id
INNER JOIN fact_tracks f ON b.track_id = f.track_id
GROUP BY a.artist_id, a.artist_name
HAVING COUNT(b.track_id) >= 10
ORDER BY popularity_stddev ASC, avg_popularity DESC
LIMIT 10;
-- Inference:
-- Every artist in the top 10 shows a popularity_stddev of
-- EXACTLY 0.0 (e.g. BYOR: 16 tracks, all popularity=87). This
-- is not genuine consistency -- it is the track_id duplication
-- issue flagged above: the same track is being counted once per
-- genre tag, so "16 tracks" is really 1-2 unique songs repeated
-- across genre categories. Genuine consistency analysis would
-- need to de-duplicate on track_id first before aggregating.


-- ==========================================================
-- BUSINESS QUESTION 3
-- How can artists be segmented into "One-Hit Wonders",
-- "Consistent Performers", and "Underperformers" based on the
-- gap between their best track and their average track?
--
-- Analysis:
-- CASE-based segmentation turns raw statistics into an
-- actionable artist classification. This kind of tiering is
-- typically used to decide marketing spend: one-hit wonders
-- may warrant single-track promotion, while consistent
-- performers justify full-catalog investment.
-- ==========================================================
WITH artist_stats AS (
    SELECT
        a.artist_id,
        a.artist_name,
        COUNT(b.track_id) AS track_count,
        ROUND(AVG(f.popularity), 2) AS avg_popularity,
        MAX(f.popularity) AS max_popularity
    FROM dim_artist a
    INNER JOIN bridge_track_artist b ON a.artist_id = b.artist_id
    INNER JOIN fact_tracks f ON b.track_id = f.track_id
    GROUP BY a.artist_id, a.artist_name
    HAVING COUNT(b.track_id) >= 3
)
SELECT
    artist_name,
    track_count,
    avg_popularity,
    max_popularity,
    (max_popularity - avg_popularity) AS popularity_gap,
    CASE
        WHEN (max_popularity - avg_popularity) >= 30 THEN 'One-Hit Wonder'
        WHEN avg_popularity >= 50 THEN 'Consistent Performer'
        ELSE 'Underperformer'
    END AS artist_segment
FROM artist_stats
ORDER BY popularity_gap DESC
LIMIT 20;
-- Inference:
-- Across artists with 3+ tracks, the split is 8,741
-- Underperformers, 2,999 Consistent Performers, and 1,305
-- One-Hit Wonders. The largest gaps belong to major reggaeton/
-- Latin acts (Feid: 1,568 "tracks", avg 6.36 vs a max of 89;
-- Jhayco: 1,045 "tracks", avg 4.73 vs a max of 91). These huge
-- track_count values are inflated by the genre-duplication issue
-- noted above -- these artists are tagged across many genres, so
-- the "gap" is partly a data artifact rather than pure one-hit
-- behavior. The classification logic is sound; the inputs need
-- de-duplication to be fully trustworthy at the individual-
-- artist level.


-- ==========================================================
-- BUSINESS QUESTION 4
-- Within each genre, who is the #1 ranked artist by average
-- popularity?
--
-- Analysis:
-- A single global artist ranking hides genre-specific talent.
-- Using a window function partitioned by genre identifies the
-- leading artist inside every genre simultaneously — directly
-- useful for building "Genre Spotlight" playlists.
-- ==========================================================
WITH artist_genre_stats AS (
    SELECT
        d.genre_name,
        a.artist_name,
        COUNT(f.track_id) AS track_count,
        ROUND(AVG(f.popularity), 2) AS avg_popularity,
        RANK() OVER (
            PARTITION BY d.genre_name
            ORDER BY AVG(f.popularity) DESC
        ) AS genre_rank
    FROM fact_tracks f
    INNER JOIN dim_genre d ON f.genre_id = d.genre_id
    INNER JOIN bridge_track_artist b ON f.track_id = b.track_id
    INNER JOIN dim_artist a ON b.artist_id = a.artist_id
    GROUP BY d.genre_name, a.artist_id, a.artist_name
    HAVING COUNT(f.track_id) >= 2
)
SELECT genre_name, artist_name, track_count, avg_popularity
FROM artist_genre_stats
WHERE genre_rank = 1
ORDER BY avg_popularity DESC
LIMIT 20;
-- Inference:
-- Kim Petras tops "pop" with a perfect 100 (on just 2 tracks),
-- and Bomba Estéreo sweeps four separate genre leaderboards at
-- once: latin, latino, reggae, and reggaeton (all 95/94). That
-- repetition is a real finding, not noise -- it shows this
-- dataset's genre taxonomy is granular and overlapping (latin
-- vs. latino vs. reggaeton are treated as distinct genres even
-- though they describe overlapping music), which is worth
-- calling out if this schema were used for genre-based curation.


-- ==========================================================
-- CHAPTER 2: COLLABORATION ANALYSIS
-- ==========================================================

-- ==========================================================
-- BUSINESS QUESTION 5
-- What share of the catalog consists of multi-artist
-- collaborations versus solo tracks, and how prevalent is
-- collaboration overall?
--
-- Analysis:
-- The bridge table only reveals its full value once we count
-- artists per track. Quantifying the collaboration share of the
-- catalog sets the baseline for the deeper collaboration
-- questions that follow.
-- ==========================================================
WITH track_artist_counts AS (
    SELECT track_id, COUNT(artist_id) AS artist_count
    FROM bridge_track_artist
    GROUP BY track_id
)
SELECT
    CASE
        WHEN artist_count = 1 THEN 'Solo Track'
        ELSE 'Collaboration'
    END AS track_type,
    COUNT(*) AS track_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_catalog
FROM track_artist_counts
GROUP BY track_type;
-- Inference:
-- 61.89% of tracks (55,541) are solo releases and 38.11%
-- (34,200) involve two or more credited artists. Collaboration
-- is common but not the majority pattern -- roughly 2 in 5
-- tracks on the platform are a joint effort.


-- ==========================================================
-- BUSINESS QUESTION 6
-- Do collaborative tracks (2+ artists) achieve higher average
-- popularity than solo tracks?
--
-- Analysis:
-- This directly informs A&R and marketing strategy: if
-- collaborations systematically outperform solo releases,
-- Spotify/label partners have a data-backed reason to encourage
-- more featured-artist releases.
-- ==========================================================
WITH track_artist_counts AS (
    SELECT track_id, COUNT(artist_id) AS artist_count
    FROM bridge_track_artist
    GROUP BY track_id
)
SELECT
    CASE
        WHEN t.artist_count = 1 THEN 'Solo Track'
        ELSE 'Collaboration'
    END AS track_type,
    COUNT(f.track_id) AS track_count,
    ROUND(AVG(f.popularity), 2) AS avg_popularity
FROM fact_tracks f
INNER JOIN track_artist_counts t ON f.track_id = t.track_id
GROUP BY track_type
ORDER BY avg_popularity DESC;
-- Inference:
-- Collaborations average 34.25 popularity vs. 32.17 for solo
-- tracks -- about a 2-point edge. The gap is real but modest,
-- so "add a feature" is a mild tailwind at best, not a
-- guaranteed popularity boost; other factors (artist reach,
-- genre, timing) likely matter far more than headcount alone.


-- ==========================================================
-- BUSINESS QUESTION 7
-- Which pairs of artists have collaborated most frequently,
-- and how well do their joint tracks perform?
--
-- Analysis:
-- A self-join on the bridge table surfaces recurring creative
-- partnerships. Identifying high-performing, repeat
-- collaborators helps A&R teams prioritize future pairings that
-- have a proven track record together.
-- ==========================================================
SELECT
    a1.artist_name AS artist_1,
    a2.artist_name AS artist_2,
    COUNT(*) AS joint_track_count,
    ROUND(AVG(f.popularity), 2) AS avg_popularity
FROM bridge_track_artist b1
INNER JOIN bridge_track_artist b2
    ON b1.track_id = b2.track_id
    AND b1.artist_id < b2.artist_id
INNER JOIN dim_artist a1 ON b1.artist_id = a1.artist_id
INNER JOIN dim_artist a2 ON b2.artist_id = a2.artist_id
INNER JOIN fact_tracks f ON b1.track_id = f.track_id
GROUP BY a1.artist_id, a1.artist_name, a2.artist_id, a2.artist_name
HAVING COUNT(*) >= 2
ORDER BY joint_track_count DESC, avg_popularity DESC
LIMIT 15;
-- Inference:
-- Bad Bunny/Daddy Yankee and J Balvin/Bad Bunny top the list --
-- but with "2,086" and "1,889" joint tracks respectively, these
-- counts are dominated by the track_id duplication artifact
-- (the same collab track counted once per genre tag), not 2,000+
-- genuinely distinct songs. The RANKING of who collaborates most
-- often is still directionally credible (major reggaeton pairings
-- dominate), but the raw counts should be de-duplicated on
-- track_id before being quoted as a real number.


-- ==========================================================
-- CHAPTER 3: GENRE BENCHMARKING
-- ==========================================================

-- ==========================================================
-- BUSINESS QUESTION 8
-- How does each genre's average popularity compare to the
-- overall catalog average — which genres are above or below
-- benchmark, and by how much?
--
-- Analysis:
-- A subquery-derived global benchmark turns a simple genre
-- average into a relative performance score. This is the kind
-- of "genre vs. platform average" metric a content strategy
-- team would use to decide where to invest curation effort.
-- ==========================================================
SELECT
    d.genre_name,
    ROUND(AVG(f.popularity), 2) AS genre_avg_popularity,
    (SELECT ROUND(AVG(popularity), 2) FROM fact_tracks) AS overall_avg_popularity,
    ROUND(
        AVG(f.popularity) - (SELECT AVG(popularity) FROM fact_tracks), 2
    ) AS variance_from_overall_avg
FROM fact_tracks f
INNER JOIN dim_genre d ON f.genre_id = d.genre_id
GROUP BY d.genre_name
ORDER BY variance_from_overall_avg DESC
LIMIT 15;
-- Inference:
-- pop-film (+26.04) and k-pop (+23.66) sit far above the overall
-- 33.24 average, consistent with the Python EDA findings. At the
-- opposite extreme, iranian (2.21), romance (3.25) and latin
-- (8.30) sit 25-31 points BELOW average -- a much larger downside
-- spread than the upside, meaning a handful of niche/underexposed
-- genres are dragging harder on the platform average than the
-- top genres are lifting it.


-- ==========================================================
-- BUSINESS QUESTION 9
-- Which genres over-index on explicit content relative to the
-- platform-wide explicit rate?
--
-- Analysis:
-- Benchmarking each genre's explicit-content share against the
-- global rate (rather than looking at raw counts) highlights
-- genres where explicit content is a defining characteristic
-- versus an exception — relevant for content moderation and
-- age-gating policy decisions.
-- ==========================================================
WITH genre_explicit_rate AS (
    SELECT
        d.genre_name,
        COUNT(*) AS total_tracks,
        SUM(CASE WHEN f.explicit = TRUE THEN 1 ELSE 0 END) AS explicit_tracks,
        ROUND(SUM(CASE WHEN f.explicit = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS explicit_pct
    FROM fact_tracks f
    INNER JOIN dim_genre d ON f.genre_id = d.genre_id
    GROUP BY d.genre_name
),
overall_rate AS (
    SELECT ROUND(SUM(CASE WHEN explicit = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS overall_explicit_pct
    FROM fact_tracks
)
SELECT
    g.genre_name,
    g.total_tracks,
    g.explicit_pct,
    o.overall_explicit_pct,
    ROUND(g.explicit_pct - o.overall_explicit_pct, 2) AS pct_above_overall
FROM genre_explicit_rate g
CROSS JOIN overall_rate o
ORDER BY pct_above_overall DESC
LIMIT 10;
-- Inference:
-- comedy is the extreme outlier: 65.6% explicit vs. an 8.55%
-- platform-wide rate (+57 points). emo and sad follow at
-- roughly +37 and +36 points. Notably, hip-hop -- the genre most
-- stereotypically associated with explicit content -- only ranks
-- 6th (+23.35 points), well behind comedy, emo and sad. This
-- reframes "explicit content" as more of a spoken-word/mature-
-- humor and emotionally raw genre pattern than a hip-hop-specific
-- one.


-- ==========================================================
-- BUSINESS QUESTION 10
-- Which genres have the highest "artist saturation" — the
-- fewest tracks per unique contributing artist — versus genres
-- dominated by a small pool of prolific artists?
--
-- Analysis:
-- Combining fact, bridge, and dimension tables to compute a
-- tracks-per-artist ratio reveals genre structure: a low ratio
-- means many artists share a small footprint each (fragmented,
-- competitive genre), while a high ratio means a handful of
-- artists dominate the genre's catalog (concentrated genre).
-- ==========================================================
SELECT
    d.genre_name,
    COUNT(DISTINCT f.track_id) AS total_tracks,
    COUNT(DISTINCT b.artist_id) AS unique_artists,
    ROUND(COUNT(DISTINCT f.track_id) * 1.0 / COUNT(DISTINCT b.artist_id), 2) AS tracks_per_artist
FROM fact_tracks f
INNER JOIN dim_genre d ON f.genre_id = d.genre_id
INNER JOIN bridge_track_artist b ON f.track_id = b.track_id
GROUP BY d.genre_name
ORDER BY tracks_per_artist DESC
LIMIT 15;
-- Inference:
-- honky-tonk is the most concentrated genre (11.82 tracks per
-- artist -- a small pool of artists dominate its 981 tracks),
-- while deep-house and show-tunes sit at the other extreme
-- (~1.15, essentially one track per artist across hundreds of
-- contributors). This maps genre "openness": deep-house looks
-- like a fragmented, low-barrier-to-entry genre on Spotify, while
-- honky-tonk is effectively gatekept by a handful of established
-- acts.


-- ==========================================================
-- CHAPTER 4: CATALOG ANALYSIS
-- ==========================================================

-- ==========================================================
-- BUSINESS QUESTION 11
-- Which albums carry the most tracks in the catalog, and how
-- does album depth relate to average track popularity?
--
-- Analysis:
-- Album-level aggregation (a grain not explored in the Python
-- EDA) shows whether "deep" albums with many tracks dilute
-- average popularity compared to tightly curated shorter
-- albums — informing release-strategy recommendations (full
-- album vs. EP vs. single).
-- ==========================================================
SELECT
    f.album_name,
    COUNT(f.track_id) AS track_count,
    ROUND(AVG(f.popularity), 2) AS avg_popularity,
    MAX(f.popularity) AS best_track_popularity
FROM fact_tracks f
GROUP BY f.album_name
HAVING COUNT(f.track_id) >= 8
ORDER BY track_count DESC
LIMIT 15;
-- Inference:
-- The average album in the catalog has only ~2.45 tracks, so
-- true multi-track albums are rare -- most "albums" are
-- effectively singles. The handful of very deep entries (195,
-- 184, 143 tracks) are almost all seasonal/mood compilation
-- playlists mislabeled as albums in the source data (e.g.
-- "Alternative Christmas 2022", "Halloween Party 2022"), and
-- they perform terribly: several show an avg_popularity of
-- 0.00. This confirms a clear pattern -- catalog depth here
-- correlates with LOW popularity, not high, because the deepest
-- "albums" are generic compilations rather than curated artist
-- releases.


-- ==========================================================
-- BUSINESS QUESTION 12
-- Which tracks are "hidden gems" — performing above their
-- genre's average popularity despite coming from low-visibility
-- artists (small overall catalogs)?
--
-- Analysis:
-- This closes the analytical story by combining genre
-- benchmarking (Chapter 3) with artist performance (Chapter 1):
-- a CTE computes each genre's average popularity, a window
-- function computes each artist's total track count, and the
-- final query surfaces tracks that outperform their genre
-- despite an artist with a thin catalog — strong candidates for
-- editorial playlist discovery features.
-- ==========================================================
WITH genre_avg AS (
    SELECT genre_id, AVG(popularity) AS genre_avg_popularity
    FROM fact_tracks
    GROUP BY genre_id
),
artist_catalog_size AS (
    SELECT
        b.track_id,
        b.artist_id,
        COUNT(*) OVER (PARTITION BY b.artist_id) AS artist_total_tracks
    FROM bridge_track_artist b
)
SELECT
    f.track_name,
    a.artist_name,
    d.genre_name,
    f.popularity,
    ROUND(g.genre_avg_popularity, 2) AS genre_avg_popularity,
    acs.artist_total_tracks
FROM fact_tracks f
INNER JOIN dim_genre d ON f.genre_id = d.genre_id
INNER JOIN genre_avg g ON f.genre_id = g.genre_id
INNER JOIN artist_catalog_size acs ON f.track_id = acs.track_id
INNER JOIN dim_artist a ON acs.artist_id = a.artist_id
WHERE f.popularity > g.genre_avg_popularity + 15
  AND acs.artist_total_tracks <= 3
ORDER BY f.popularity DESC
LIMIT 20;
-- Inference:
-- 7,309 tracks qualify as "hidden gems" catalog-wide. The
-- standouts are genuinely compelling: "Quevedo: Bzrp Music
-- Sessions, Vol. 52" (popularity 99 vs. a hip-hop genre average
-- of 37.76) from an artist with only 1 tagged track, and "As It
-- Was" by Harry Styles (95 vs. a pop average of 47.58). As with
-- Q3/Q7, treat artist_total_tracks with some caution -- it is
-- counted from the un-deduplicated bridge/fact join, so a
-- reported "3 tracks" could partly reflect genre-tag repetition
-- rather than 3 fully distinct songs. The overall pattern
-- (breakout tracks from otherwise low-visibility artists) still
-- holds and is a strong candidate list for playlist discovery
-- features.