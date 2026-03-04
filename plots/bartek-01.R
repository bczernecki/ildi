library(terra)
library(giscoR) # official EU maps

# read netcdf:
files <- list.files(
  "~/Downloads/ildi/Bartek-test/",
  pattern = "timmean_pctl.*\\.nc$",
  full.names = TRUE
)

r = terra::rast("/Users/bartosz/Downloads/ildi/Bartek-test/timmean_pctl95_ERA5.nc")
new_crs = "EPSG:3035"
r_europe = project(r, new_crs, method = "bilinear")
plot(r_europe)

names(r)
plot(r_europe[["SB_CAPE"]])
# europe_map = gisco_get_countries(region = "Europe")
# europe_map_3035 = project(vect(europe_map), "EPSG:3035")
# saveRDS(europe_map_3035, "plots/europe_map_3035.rds")
europe_map_3035 = readRDS("plots/europe_map_3035.rds")
r_cropped = crop(r_europe, europe_map_3035)
r_masked = mask(r_cropped, europe_map_3035)

plot(r_masked[["SB_CAPE"]])
lines(europe_map_3035)

# island doesn't have data so, remove it:
europe_map_3035 = europe_map_3035[-24,]



# create t-map a-like object:
library(tmap)
library(sf)
eu_bbox <- st_bbox(c(xmin = 2600000, xmax = 6500000,
                     ymin = 1500000, ymax = 5400000),
                   crs = st_crs(3035))

p1 = tm_shape(r_masked[["SB_CAPE"]],
             bbox = eu_bbox) +
  tm_raster(palette = "meteo.precip3_16lev", # this one looks ok
            title = "SB CAPE [J/kg]",
            style = "quantile", n = 12,
            legend.is.portrait = FALSE) +

  # Warstwa wektorowa (kontury państw)
  tm_shape(europe_map_3035) +
  tm_borders(lwd = 0.5, col = "black") +
  tm_layout(
    inner.margins = c(0.02, 0.02, 0.02, 0.02), # Minimalne marginesy wewnątrz
    legend.outside = TRUE,            # Legenda poza ramką mapy
    legend.outside.position = "bottom", # Legenda POD mapą
    legend.frame = FALSE,
    frame = TRUE,                     # Ramka wokół samej mapy
    panel.label.size = 1,             # Rozmiar etykiety panelu (jeśli używasz)
    bg.color = "white"
  ) +
  tm_credits("SB CAPE [J/kg]",
             position = c("left", "top"),
             size = 1.2,
             fontface = "bold")

# combine plots for p1 and p into single plot:
tmap_arrange(p1, p, ncol = 2)

  # Dodatki estetyczne
  tm_layout(main.title = "Mapa Europy w projekcji LAEA",
            main.title.position = "center",
            frame = FALSE,
            bg.color = "lightblue", # Kolor "morza" w tle
            legend.outside = TRUE) +

  # Elementy kartograficzne
  tm_scale_bar(position = c("left", "bottom")) +
  tm_compass(type = "8star", position = c("right", "top"))

# 3. Wyświetlenie mapy
print(mapa_europy)
