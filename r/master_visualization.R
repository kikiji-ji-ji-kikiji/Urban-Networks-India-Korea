# ============================================================
# Master R Visualization Script
# OSM Urban Network Analysis — India & Korea
# ============================================================
# Run this script fresh at the start of every session.
# All sections are clearly labelled — run them in order.
# ============================================================

library(sf)
library(ggplot2)
library(dplyr)
library(stringr)
library(purrr)
library(tidyr)
library(patchwork)

# Run this script from the repository root (e.g. open the .Rproj or set
# your working directory to the repo folder before sourcing this script).
DATA_DIR <- "data"
country_colors <- c("India" = "#E07B39", "Korea" = "#3A7DC9")

# ============================================================
# SECTION 1: LOAD DATA
# ============================================================

# stats
stats <- read.csv(file.path(DATA_DIR, "city_stats.csv"), stringsAsFactors = FALSE)
amenity_stats <- read.csv(file.path(DATA_DIR, "amenity_stats.csv"), stringsAsFactors = FALSE)
cat("Stats loaded:", nrow(stats), "cities\n")

# street networks (exclude amenity files)
gpkg_files <- list.files(DATA_DIR, pattern = "\\.gpkg$", full.names = TRUE)
gpkg_files <- gpkg_files[!grepl("amenity_", gpkg_files)]
networks <- map(gpkg_files, ~tryCatch(st_read(.x, quiet = TRUE), error = function(e) NULL))
names(networks) <- gpkg_files %>% basename() %>% str_remove("\\.gpkg$") %>% str_replace_all("_", " ")
networks <- compact(networks)
cat("Networks loaded:", length(networks), "\n")

# amenity point files
amenity_files <- list.files(DATA_DIR, pattern = "^amenity_.*\\.gpkg$", full.names = TRUE)
amenities <- map(amenity_files, ~tryCatch(st_read(.x, quiet = TRUE), error = function(e) NULL))
names(amenities) <- amenity_files %>% basename() %>%
  str_remove("^amenity_") %>% str_remove("\\.gpkg$") %>% str_replace_all("_", " ")
amenities <- compact(amenities)
cat("Amenity files loaded:", length(amenities), "\n")

# summary tables
summary_table <- stats %>%
  select(any_of(c("city","country","n","m","k_avg","circuity_avg",
                  "street_length_avg"))) %>%
  arrange(country, city) %>%
  mutate(city_label = str_remove(city, ",.*$") %>% str_trim())

country_summary <- stats %>%
  group_by(country) %>%
  summarise(n_cities = n(),
            mean_circuity = mean(circuity_avg, na.rm = TRUE),
            mean_k_avg = mean(k_avg, na.rm = TRUE),
            mean_street_length = mean(street_length_avg, na.rm = TRUE),
            .groups = "drop")

amenity_stats <- amenity_stats %>%
  mutate(city_label = str_remove(city, ",.*$") %>% str_trim())

city_names_all <- intersect(names(networks), names(amenities))
cat("Matching cities:", length(city_names_all), "\n")

# ============================================================
# SECTION 2: NETWORK STATS PLOTS
# ============================================================

# 2a. Average street length
p1 <- ggplot(summary_table, aes(x = reorder(city_label, street_length_avg),
                                y = street_length_avg, fill = country)) +
  geom_col() + scale_fill_manual(values = country_colors) + coord_flip() +
  labs(title = "Average Street Length by City", x = NULL, y = "Avg Street Length (m)", fill = "Country") +
  theme_minimal(base_size = 11)

# 2b. Node degree
p2 <- ggplot(summary_table, aes(x = reorder(city_label, k_avg),
                                y = k_avg, fill = country)) +
  geom_col() + scale_fill_manual(values = country_colors) + coord_flip() +
  labs(title = "Average Node Degree (k_avg) by City", x = NULL, y = "k_avg", fill = "Country") +
  theme_minimal(base_size = 11)

# 2c. Circuity
p3 <- ggplot(summary_table, aes(x = reorder(city_label, circuity_avg),
                                y = circuity_avg, fill = country)) +
  geom_col() + scale_fill_manual(values = country_colors) + coord_flip() +
  labs(title = "Street Circuity by City", x = NULL, y = "Circuity (1.0 = perfectly straight)", fill = "Country") +
  theme_minimal(base_size = 11)

# 2d. Country comparison
country_long <- country_summary %>%
  pivot_longer(cols = c(mean_circuity, mean_k_avg, mean_street_length),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
    "mean_circuity" = "Circuity",
    "mean_k_avg" = "Node Degree (k_avg)",
    "mean_street_length" = "Avg Street Length (m)"))

p4 <- ggplot(country_long, aes(x = metric, y = value, fill = country)) +
  geom_col(position = "dodge") + scale_fill_manual(values = country_colors) +
  labs(title = "India vs Korea — Network Metrics", x = NULL, y = "Value", fill = "Country") +
  theme_minimal(base_size = 11)

dev.new(); print(p1)
dev.new(); print(p2)
dev.new(); print(p3)
dev.new(); print(p4)

# ============================================================
# SECTION 3: AMENITY PLOTS
# ============================================================

# 3a. Total amenities
a1 <- ggplot(amenity_stats, aes(x = reorder(city_label, total_amenities),
                                y = total_amenities, fill = country)) +
  geom_col() + scale_fill_manual(values = country_colors) + coord_flip() +
  labs(title = "Total OSM Amenities by City", x = NULL, y = "Total Amenities", fill = "Country") +
  theme_minimal(base_size = 11)

# 3b. Unique amenity types
a2 <- ggplot(amenity_stats, aes(x = reorder(city_label, unique_types),
                                y = unique_types, fill = country)) +
  geom_col() + scale_fill_manual(values = country_colors) + coord_flip() +
  labs(title = "Unique Amenity Types by City", x = NULL, y = "Unique Types", fill = "Country") +
  theme_minimal(base_size = 11)

# 3c. Top amenity type per city
a3 <- ggplot(amenity_stats, aes(x = reorder(city_label, total_amenities),
                                y = top1_count, fill = country)) +
  geom_col() +
  geom_text(aes(label = top1_type), hjust = -0.1, size = 3) +
  scale_fill_manual(values = country_colors) +
  coord_flip(clip = "off") +
  labs(title = "Most Common Amenity Type per City", x = NULL, y = "Count", fill = "Country") +
  theme_minimal(base_size = 11) +
  theme(plot.margin = margin(5, 80, 5, 5))

dev.new(); print(a1)
dev.new(); print(a2)
dev.new(); print(a3)

# ============================================================
# SECTION 4: INDIVIDUAL CITY NETWORK MAPS (view + save)
# ============================================================

dir.create("city_maps", showWarnings = FALSE)

iwalk(networks, function(edges_sf, city_name) {
  p <- ggplot(edges_sf) +
    geom_sf(color = "grey20", linewidth = 0.15) +
    ggtitle(city_name) +
    theme_void() +
    theme(plot.title = element_text(size = 14, hjust = 0.5, face = "bold"),
          plot.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(10, 10, 10, 10))
  fname <- paste0("city_maps/", str_replace_all(city_name, " ", "_"), ".png")
  ggsave(fname, p, width = 10, height = 10, dpi = 300)
  cat("Saved:", fname, "\n")
})

# ============================================================
# SECTION 5: AMENITY OVERLAY ON STREET NETWORKS
# ============================================================

plot_city_overlay <- function(city_name) {
  net <- networks[[city_name]]
  amen <- amenities[[city_name]]
  if (is.null(net) || is.null(amen) || nrow(amen) == 0) { message("Skipping: ", city_name); return(NULL) }
  amen <- amen[st_geometry_type(amen) == "POINT", ]
  if (nrow(amen) == 0) { message("No points: ", city_name); return(NULL) }
  amen <- st_transform(amen, st_crs(net))
  ggplot() +
    geom_sf(data = net, color = "grey30", linewidth = 0.1) +
    geom_sf(data = amen, aes(color = amenity), size = 0.8, alpha = 0.6, show.legend = FALSE) +
    ggtitle(city_name) +
    theme_void() +
    theme(plot.title = element_text(size = 13, hjust = 0.5, face = "bold"),
          plot.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(10, 10, 10, 10))
}

dir.create("city_maps/overlays", showWarnings = FALSE, recursive = TRUE)

for (city in city_names_all) {
  p <- plot_city_overlay(city)
  if (!is.null(p)) {
    fname <- paste0("city_maps/overlays/", str_replace_all(city, " ", "_"), "_overlay.png")
    ggsave(fname, p, width = 10, height = 10, dpi = 300)
    cat("Saved:", fname, "\n")
  }
}

# ============================================================
# SECTION 6: AMENITY DENSITY (normalize by city area)
# ============================================================

# compute area of each network's bounding box as a proxy for city area
network_areas <- imap_dfr(networks, function(edges_sf, city_name) {
  bbox <- st_bbox(edges_sf)
  area_km2 <- as.numeric((bbox["xmax"] - bbox["xmin"]) * (bbox["ymax"] - bbox["ymin"])) / 1e6
  tibble(city = city_name, bbox_area_km2 = area_km2)
})

amenity_density <- amenity_stats %>%
  mutate(city_key = str_replace_all(city, ",", "") %>% str_replace_all("  ", " ") %>% str_trim()) %>%
  left_join(network_areas %>% rename(city_key = city), by = "city_key") %>%
  mutate(amenity_density = total_amenities / bbox_area_km2)

ad1 <- ggplot(amenity_density, aes(x = reorder(city_label, amenity_density),
                                    y = amenity_density, fill = country)) +
  geom_col() + scale_fill_manual(values = country_colors) + coord_flip() +
  labs(title = "Amenity Density by City (per km²)",
       x = NULL, y = "Amenities per km²", fill = "Country") +
  theme_minimal(base_size = 11)

dev.new(); print(ad1)

cat("\nAll done.\n")
