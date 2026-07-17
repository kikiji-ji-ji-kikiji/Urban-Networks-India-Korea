"""
OSM Amenity / POI Download Pipeline
=====================================
Downloads amenity POIs for all 23 cities using OSMnx features API.
Uses the same city list, fallback logic, and checkpointing as osm_pipeline.py.

Outputs:
  data/amenity_<city_safe_name>.gpkg  -- POI points per city
  data/amenity_stats.csv              -- amenity counts and top types per city
"""

import os
import time
import traceback

import osmnx as ox
import pandas as pd
import geopandas as gpd

OUTPUT_DIR = "data"
AMENITY_STATS_CSV = os.path.join(OUTPUT_DIR, "amenity_stats.csv")

# amenity tags to pull - covers the most common and well-tagged categories
TAGS = {"amenity": True}  # True = pull all amenity values

MAX_RETRIES = 3
RETRY_DELAY_SEC = 10
BBOX_FALLBACK_DIST_M = 8000

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
    # India - tier 2
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


def safe_name(city_name):
    return city_name.replace(",", "").replace(" ", "_")


def download_amenities(city_name, lat, lon):
    """Try place boundary first, fall back to point+bbox."""
    last_err = None

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            gdf = ox.features_from_place(city_name, tags=TAGS)
            return gdf, "place"
        except Exception as e:
            last_err = e
            print(f"  [place attempt {attempt}/{MAX_RETRIES}] failed: {e}")
            time.sleep(RETRY_DELAY_SEC)

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            gdf = ox.features_from_point((lat, lon), tags=TAGS, dist=BBOX_FALLBACK_DIST_M)
            return gdf, "bbox_fallback"
        except Exception as e:
            last_err = e
            print(f"  [bbox attempt {attempt}/{MAX_RETRIES}] failed: {e}")
            time.sleep(RETRY_DELAY_SEC)

    raise RuntimeError(f"All attempts failed for {city_name}: {last_err}")


def process_city(city_name, country, lat, lon):
    fname = safe_name(city_name)
    gpkg_path = os.path.join(OUTPUT_DIR, f"amenity_{fname}.gpkg")

    if os.path.exists(gpkg_path):
        print(f"[skip] {city_name} already processed")
        return None, None

    print(f"[run] {city_name}")
    try:
        gdf, method = download_amenities(city_name, lat, lon)
    except Exception as e:
        print(f"[FAIL] {city_name}: {e}")
        return None, {"city": city_name, "country": country, "error": str(e)}

    try:
        # keep only point geometries and useful columns
        cols_keep = [c for c in ["amenity", "name", "geometry"] if c in gdf.columns]
        gdf = gdf[cols_keep].copy()
        # convert to points only (drop polygons/lines for simplicity)
        gdf = gdf[gdf.geometry.geom_type == "Point"].copy()

        gdf.to_file(gpkg_path, driver="GPKG")

        # build stats row
        amenity_counts = gdf["amenity"].value_counts() if "amenity" in gdf.columns else pd.Series()
        top5 = amenity_counts.head(5).to_dict()

        row = {
            "city": city_name,
            "country": country,
            "total_amenities": len(gdf),
            "unique_types": gdf["amenity"].nunique() if "amenity" in gdf.columns else 0,
            "download_method": method,
            "top1_type": list(top5.keys())[0] if len(top5) > 0 else "",
            "top1_count": list(top5.values())[0] if len(top5) > 0 else 0,
            "top2_type": list(top5.keys())[1] if len(top5) > 1 else "",
            "top2_count": list(top5.values())[1] if len(top5) > 1 else 0,
            "top3_type": list(top5.keys())[2] if len(top5) > 2 else "",
            "top3_count": list(top5.values())[2] if len(top5) > 2 else 0,
        }
        return row, None

    except Exception as e:
        print(f"[FAIL during processing] {city_name}: {e}")
        traceback.print_exc()
        return None, {"city": city_name, "country": country, "error": str(e)}


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    results = []
    failures = []

    for city_name, country, lat, lon in CITIES:
        row, failure = process_city(city_name, country, lat, lon)
        if row:
            results.append(row)
        if failure:
            failures.append(failure)

    if results:
        new_df = pd.DataFrame(results)
        if os.path.exists(AMENITY_STATS_CSV):
            old_df = pd.read_csv(AMENITY_STATS_CSV)
            combined = pd.concat([old_df, new_df], ignore_index=True)
            combined = combined.drop_duplicates(subset=["city"], keep="last")
        else:
            combined = new_df
        combined.to_csv(AMENITY_STATS_CSV, index=False)
        print(f"\nWrote amenity stats for {len(combined)} cities to {AMENITY_STATS_CSV}")

    if failures:
        pd.DataFrame(failures).to_csv(
            os.path.join(OUTPUT_DIR, "amenity_failed.csv"), index=False
        )
        print(f"Logged {len(failures)} failures to amenity_failed.csv")

    print("\nDone.")


if __name__ == "__main__":
    main()
