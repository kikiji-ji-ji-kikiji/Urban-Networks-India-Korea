"""
OSM Street Network Batch Pipeline
==================================
Downloads street networks for a list of cities, computes OSMnx basic_stats,
and exports edges as GeoPackage files for downstream visualization in R.

Outputs:
  data/<city_safe_name>.gpkg   -- street network edges (one per city)
  data/city_stats.csv          -- one row per city with network statistics
  data/failed_cities.csv       -- cities that failed even after fallback

Usage:
  python osm_pipeline.py
"""

import os
import time
import traceback

import osmnx as ox
import pandas as pd

# ----------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------
OUTPUT_DIR = "data"
STATS_CSV = os.path.join(OUTPUT_DIR, "city_stats.csv")
FAILED_CSV = os.path.join(OUTPUT_DIR, "failed_cities.csv")
NETWORK_TYPE = "drive"        # "drive", "walk", "bike", "all" etc.
MAX_RETRIES = 3
RETRY_DELAY_SEC = 10
BBOX_FALLBACK_DIST_M = 8000   # radius used if place-boundary lookup fails

# City list: (query_name, country, fallback_lat, fallback_lon)
# fallback_lat/lon used only if graph_from_place fails -> graph_from_point
CITIES = [
    # India - tier 1
    ("Mumbai, India",     "India", 19.0760, 72.8777),
    ("Delhi, India",      "India", 28.7041, 77.1025),
    ("Bangalore, India",  "India", 12.9716, 77.5946),
    ("Chennai, India",    "India", 13.0827, 80.2707),
    ("Kolkata, India",    "India", 22.5726, 88.3639),
    ("Hyderabad, India",  "India", 17.3850, 78.4867),
    ("Pune, India",       "India", 18.5204, 73.8567),
    ("Ahmedabad, India",  "India", 23.0225, 72.5714),
    # India - tier 2 (sample, extend as needed)
    ("Jaipur, India",     "India", 26.9124, 75.7873),
    ("Lucknow, India",    "India", 26.8467, 80.9462),
    ("Nagpur, India",     "India", 21.1458, 79.0882),
    ("Indore, India",     "India", 22.7196, 75.8577),
    ("Coimbatore, India", "India", 11.0168, 76.9558),
    # Korea - top 10
    ("Seoul, South Korea",   "Korea", 37.5665, 126.9780),
    ("Busan, South Korea",   "Korea", 35.1796, 129.0756),
    ("Incheon, South Korea", "Korea", 37.4563, 126.7052),
    ("Daegu, South Korea",   "Korea", 35.8714, 128.6014),
    ("Daejeon, South Korea", "Korea", 36.3504, 127.3845),
    ("Gwangju, South Korea", "Korea", 35.1595, 126.8526),
    ("Suwon, South Korea",   "Korea", 37.2636, 127.0286),
    ("Ulsan, South Korea",   "Korea", 35.5384, 129.3114),
    ("Goyang, South Korea",  "Korea", 37.6584, 126.8320),
    ("Yongin, South Korea",  "Korea", 37.2411, 127.1776),
]


def safe_name(city_name: str) -> str:
    return city_name.replace(",", "").replace(" ", "_")


def download_graph(city_name, lat, lon):
    """Try place-boundary download first, fall back to point+bbox."""
    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            G = ox.graph_from_place(city_name, network_type=NETWORK_TYPE)
            return G, "place"
        except Exception as e:
            last_err = e
            print(f"  [place attempt {attempt}/{MAX_RETRIES}] failed: {e}")
            time.sleep(RETRY_DELAY_SEC)

    # fallback: bbox around a known lat/lon
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            G = ox.graph_from_point(
                (lat, lon), dist=BBOX_FALLBACK_DIST_M, network_type=NETWORK_TYPE
            )
            return G, "bbox_fallback"
        except Exception as e:
            last_err = e
            print(f"  [bbox attempt {attempt}/{MAX_RETRIES}] failed: {e}")
            time.sleep(RETRY_DELAY_SEC)

    raise RuntimeError(f"All attempts failed for {city_name}: {last_err}")


def process_city(city_name, country, lat, lon, output_dir=OUTPUT_DIR):
    fname = safe_name(city_name)
    gpkg_path = os.path.join(output_dir, f"{fname}.gpkg")

    # checkpoint: skip if already done
    if os.path.exists(gpkg_path):
        print(f"[skip] {city_name} already processed")
        return None, None

    print(f"[run] {city_name}")
    try:
        G, method = download_graph(city_name, lat, lon)
    except Exception as e:
        print(f"[FAIL] {city_name}: {e}")
        return None, {"city": city_name, "country": country, "error": str(e)}

    try:
        G_proj = ox.project_graph(G)
        stats = ox.basic_stats(G_proj)
        flat_stats = {k: v for k, v in stats.items() if not isinstance(v, dict)}
        flat_stats["city"] = city_name
        flat_stats["country"] = country
        flat_stats["download_method"] = method

        edges = ox.graph_to_gdfs(G, nodes=False, edges=True)
        edges.to_file(gpkg_path, driver="GPKG")

        return flat_stats, None
    except Exception as e:
        print(f"[FAIL during stats/export] {city_name}: {e}")
        traceback.print_exc()
        return None, {"city": city_name, "country": country, "error": str(e)}


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    results = []
    failures = []

    for city_name, country, lat, lon in CITIES:
        stats, failure = process_city(city_name, country, lat, lon)
        if stats:
            results.append(stats)
        if failure:
            failures.append(failure)

    # merge with any existing stats csv (in case of resumed run)
    if results:
        new_df = pd.DataFrame(results)
        if os.path.exists(STATS_CSV):
            old_df = pd.read_csv(STATS_CSV)
            combined = pd.concat([old_df, new_df], ignore_index=True)
            combined = combined.drop_duplicates(subset=["city"], keep="last")
        else:
            combined = new_df
        combined.to_csv(STATS_CSV, index=False)
        print(f"\nWrote stats for {len(combined)} cities to {STATS_CSV}")

    if failures:
        pd.DataFrame(failures).to_csv(FAILED_CSV, index=False)
        print(f"Logged {len(failures)} failures to {FAILED_CSV}")

    print("\nDone.")


if __name__ == "__main__":
    main()
