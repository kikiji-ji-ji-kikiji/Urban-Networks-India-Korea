library(sf)
library(ggplot2)
library(dplyr)
library(stringr)
library(purrr)

setwd("/Users/keertiyadav/Downloads/Journals_on_process/Urban Networks with OSMnx")
DATA_DIR <- "data"

# load stats
stats <- read.csv(file.path(DATA_DIR, "city_stats.csv"), stringsAsFactors = FALSE)
cat("Loaded stats for", nrow(stats), "cities\n")

# load all gpkg files
gpkg_files <- list.files(DATA_DIR, pattern = "\\.gpkg$", full.names = TRUE)
networks <- map(gpkg_files, ~tryCatch(st_read(.x, quiet = TRUE), error = function(e) NULL))
names(networks) <- gpkg_files %>% basename() %>% str_remove("\\.gpkg$") %>% str_replace_all("_", " ")
networks <- compact(networks)
cat("Loaded", length(networks), "network files\n")

# single city plot
plot_city_network <- function(edges_sf, title = "") {
  ggplot(edges_sf) +
    geom_sf(color = "grey20", linewidth = 0.1) +
    ggtitle(title) +
    theme_void() +
    theme(plot.title = element_text(size = 7, hjust = 0.5),
          plot.background = element_rect(fill = "white", color = NA))
}

# comparison grid (all 23 cities)
library(patchwork)
# install.packages("patchwork") if not installed

plots <- imap(networks, ~plot_city_network(.x, title = .y))
grid <- wrap_plots(plots, ncol = 4)
ggsave("city_network_grid.png", grid, width = 20, height = 16, dpi = 150)
cat("Saved city_network_grid.png\n")

# create a folder for individual city maps
dir.create("city_maps", showWarnings = FALSE)

# view each city one by one in RStudio Plots panel
# AND save as high-res PNG
iwalk(networks, function(edges_sf, city_name) {
  
  p <- ggplot(edges_sf) +
    geom_sf(color = "grey20", linewidth = 0.15) +
    ggtitle(city_name) +
    theme_void() +
    theme(
      plot.title = element_text(size = 14, hjust = 0.5, face = "bold"),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(10, 10, 10, 10)
    )
  
  # print to RStudio Plots panel
  print(p)
  
  # save high-res PNG
  fname <- paste0("city_maps/", str_replace_all(city_name, " ", "_"), ".png")
  ggsave(fname, p, width = 10, height = 10, dpi = 300)
  cat("Saved:", fname, "\n")
  
  # pause briefly so RStudio renders each plot before moving on
  Sys.sleep(0.5)
})

cat("All individual city maps saved in city_maps/ folder.\n")


# summary table
summary_table <- stats %>%
  select(any_of(c("city","country","n","m","k_avg","circuity_avg",
                  "street_length_avg","intersection_density_km","street_density_km"))) %>%
  arrange(country, city)
print(summary_table)

country_summary <- stats %>%
  group_by(country) %>%
  summarise(
    n_cities = n(),
    mean_circuity = mean(circuity_avg, na.rm = TRUE),
    mean_k_avg = mean(k_avg, na.rm = TRUE),
    mean_street_length = mean(street_length_avg, na.rm = TRUE),
    .groups = "drop"
  )
print(country_summary)

write.csv(summary_table, file.path(DATA_DIR, "summary_table.csv"), row.names = FALSE)
write.csv(country_summary, file.path(DATA_DIR, "country_summary.csv"), row.names = FALSE)
cat("Done.\n")




library(ggplot2)
library(dplyr)
library(tidyr)

country_colors <- c("India" = "#E07B39", "Korea" = "#3A7DC9")

summary_table <- summary_table %>%
  mutate(city_label = str_remove(city, ",.*$") %>% str_trim())

# 1. Average street length by city
p1 <- ggplot(summary_table, aes(x = reorder(city_label, street_length_avg), 
                                y = street_length_avg, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Average Street Length by City",
       x = NULL, y = "Avg Street Length (m)", fill = "Country") +
  theme_minimal(base_size = 11)
print(p1)

# 2. Node degree
p2 <- ggplot(summary_table, aes(x = reorder(city_label, k_avg), 
                                y = k_avg, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Average Node Degree (k_avg) by City",
       x = NULL, y = "k_avg", fill = "Country") +
  theme_minimal(base_size = 11)
print(p2)

# 3. Circuity
p3 <- ggplot(summary_table, aes(x = reorder(city_label, circuity_avg), 
                                y = circuity_avg, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Street Circuity by City",
       x = NULL, y = "Circuity (1.0 = perfectly straight)", fill = "Country") +
  theme_minimal(base_size = 11)
print(p3)

# 4. Country comparison
country_long <- country_summary %>%
  pivot_longer(cols = c(mean_circuity, mean_k_avg, mean_street_length),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
                         "mean_circuity" = "Circuity",
                         "mean_k_avg" = "Node Degree (k_avg)",
                         "mean_street_length" = "Avg Street Length (m)"
  ))

p4 <- ggplot(country_long, aes(x = metric, y = value, fill = country)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = country_colors) +
  labs(title = "India vs Korea — Network Metrics Comparison",
       x = NULL, y = "Value", fill = "Country") +
  theme_minimal(base_size = 11)
print(p4)


country_colors <- c("India" = "#E07B39", "Korea" = "#3A7DC9")

summary_table <- summary_table %>%
  mutate(city_label = str_remove(city, ",.*$") %>% str_trim())

# 1. Average street length
p1 <- ggplot(summary_table, aes(x = reorder(city_label, street_length_avg), 
                                y = street_length_avg, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Average Street Length by City",
       x = NULL, y = "Avg Street Length (m)", fill = "Country") +
  theme_minimal(base_size = 11)
print(p1)

# 2. Node degree
p2 <- ggplot(summary_table, aes(x = reorder(city_label, k_avg), 
                                y = k_avg, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Average Node Degree (k_avg) by City",
       x = NULL, y = "k_avg", fill = "Country") +
  theme_minimal(base_size = 11)
print(p2)

# 3. Circuity
p3 <- ggplot(summary_table, aes(x = reorder(city_label, circuity_avg), 
                                y = circuity_avg, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Street Circuity by City",
       x = NULL, y = "Circuity (1.0 = perfectly straight)", fill = "Country") +
  theme_minimal(base_size = 11)
print(p3)

# 4. Country comparison
country_long <- country_summary %>%
  pivot_longer(cols = c(mean_circuity, mean_k_avg, mean_street_length),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
                         "mean_circuity" = "Circuity",
                         "mean_k_avg" = "Node Degree (k_avg)",
                         "mean_street_length" = "Avg Street Length (m)"
  ))

p4 <- ggplot(country_long, aes(x = metric, y = value, fill = country)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = country_colors) +
  labs(title = "India vs Korea — Network Metrics Comparison",
       x = NULL, y = "Value", fill = "Country") +
  theme_minimal(base_size = 11)
print(p4)



# load amenity stats
amenity_stats <- read.csv("data/amenity_stats.csv", stringsAsFactors = FALSE)

country_colors <- c("India" = "#E07B39", "Korea" = "#3A7DC9")

amenity_stats <- amenity_stats %>%
  mutate(city_label = str_remove(city, ",.*$") %>% str_trim())

# 1. Total amenities per city
p1 <- ggplot(amenity_stats, aes(x = reorder(city_label, total_amenities),
                                y = total_amenities, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Total OSM Amenities by City",
       x = NULL, y = "Total Amenities", fill = "Country") +
  theme_minimal(base_size = 11)
print(p1)

# 2. Unique amenity types per city
p2 <- ggplot(amenity_stats, aes(x = reorder(city_label, unique_types),
                                y = unique_types, fill = country)) +
  geom_col() +
  scale_fill_manual(values = country_colors) +
  coord_flip() +
  labs(title = "Unique Amenity Types by City",
       x = NULL, y = "Unique Types", fill = "Country") +
  theme_minimal(base_size = 11)
print(p2)

# 3. Country-level amenity comparison
country_amenity <- amenity_stats %>%
  group_by(country) %>%
  summarise(
    mean_amenities = mean(total_amenities, na.rm = TRUE),
    mean_types = mean(unique_types, na.rm = TRUE),
    .groups = "drop"
  )
print(country_amenity)

# 4. Top amenity type per city (dot plot)
p3 <- ggplot(amenity_stats, aes(x = reorder(city_label, total_amenities),
                                y = top1_count, fill = country)) +
  geom_col() +
  geom_text(aes(label = top1_type), hjust = -0.1, size = 3) +
  scale_fill_manual(values = country_colors) +
  coord_flip(clip = "off") +
  labs(title = "Most Common Amenity Type per City",
       x = NULL, y = "Count of Top Amenity", fill = "Country") +
  theme_minimal(base_size = 11) +
  theme(plot.margin = margin(5, 80, 5, 5))
print(p3)


# load all amenity gpkg files
amenity_files <- list.files(DATA_DIR, pattern = "^amenity_.*\\.gpkg$", full.names = TRUE)
amenities <- map(amenity_files, ~tryCatch(st_read(.x, quiet = TRUE), error = function(e) NULL))
names(amenities) <- amenity_files %>% basename() %>% 
  str_remove("^amenity_") %>% 
  str_remove("\\.gpkg$") %>% 
  str_replace_all("_", " ")
amenities <- compact(amenities)
cat("Loaded", length(amenities), "amenity files\n")

# overlay function: street network + amenity points
plot_city_overlay <- function(city_name) {
  net <- networks[[city_name]]
  amen <- amenities[[city_name]]
  
  if (is.null(net) || is.null(amen) || nrow(amen) == 0) {
    message("Skipping (no data): ", city_name)
    return(NULL)
  }
  
  # keep only point geometries
  amen <- amen[st_geometry_type(amen) == "POINT", ]
  
  if (nrow(amen) == 0) {
    message("Skipping (no points): ", city_name)
    return(NULL)
  }
  
  amen <- st_transform(amen, st_crs(net))
  
  ggplot() +
    geom_sf(data = net, color = "grey30", linewidth = 0.1) +
    geom_sf(data = amen, aes(color = amenity), size = 0.8, alpha = 0.6, show.legend = FALSE) +
    ggtitle(city_name) +
    theme_void() +
    theme(
      plot.title = element_text(size = 13, hjust = 0.5, face = "bold"),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(10, 10, 10, 10)
    )
}

dev.new()
for (city in city_names_all) {
  p <- plot_city_overlay(city)
  if (!is.null(p)) {
    print(p)
    Sys.sleep(0.5)
  }
}


# fix: load ONLY street network gpkg files (exclude amenity ones)
gpkg_files <- list.files(DATA_DIR, pattern = "\\.gpkg$", full.names = TRUE)
gpkg_files <- gpkg_files[!grepl("amenity_", gpkg_files)]
networks <- map(gpkg_files, ~tryCatch(st_read(.x, quiet = TRUE), error = function(e) NULL))
names(networks) <- gpkg_files %>% basename() %>% str_remove("\\.gpkg$") %>% str_replace_all("_", " ")
networks <- compact(networks)
cat("Loaded", length(networks), "networks\n")

# match cities that have both network and amenity data
city_names_all <- intersect(names(networks), names(amenities))
cat("Matching cities:", length(city_names_all), "\n")

# plot overlays one by one
dev.new()
for (city in city_names_all) {
  p <- plot_city_overlay(city)
  if (!is.null(p)) {
    print(p)
    Sys.sleep(0.5)
  }
}