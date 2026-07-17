# Urban Street Network & Amenity Analysis - India & Korea

Comparative analysis of street network structure and urban amenities (POIs) across
23 cities in India and South Korea, using OpenStreetMap data via OSMnx (Python) and
visualized with `sf`/`ggplot2` (R).

## What this does

- Downloads street networks for each city (`drive` network type) and computes
  standard network metrics (average street length, node degree, circuity, etc.)
- Downloads OSM amenity/POI data for the same cities
- Produces comparative charts (India vs. Korea) and individual city network maps,
  plus amenity-overlay maps

## Repo structure

```
├── python/
│   ├── osm_pipeline.py        # Step 1: downloads street networks -> data/city_stats.csv, data/*.gpkg
│   └── amenity_pipeline.py    # Step 2: downloads amenity/POI data -> data/amenity_stats.csv, data/amenity_*.gpkg
├── r/
│   └── master_visualization.R # Step 3: generates all charts and maps from the data/ outputs
├── drafts/
│   └── visualize_networks.R   # earlier draft version, kept for reference only
├── data/                      # pipeline outputs (gitignored — see below)
├── figures/                   # exported map images
└── requirements.txt           # Python dependencies
```

## How to run

1. `pip install -r requirements.txt`
2. `python python/osm_pipeline.py`
3. `python python/amenity_pipeline.py`
4. Open `r/master_visualization.R` in RStudio (set your working directory to the
   repo root, or open it via an `.Rproj` file) and run top to bottom.

Each pipeline script checkpoints progress — if it's interrupted, re-running it will
skip cities that were already downloaded.

## Data

City-level outputs (`.gpkg`, `.csv`) are not tracked in this repo since they can be
regenerated from the scripts above and OSM data can be large. `figures/` holds the
exported map images used for write-ups and presentations.

## Notes

`drafts/visualize_networks.R` is an earlier, unconsolidated version of the analysis
in `r/master_visualization.R` — kept for reference but not the maintained script.
