library(ncdf4)
library(viridis)
library(maps)
library(mapdata)
library(fields)

# Színskála definiálása
custom_breaks <- c(
  "#FFFFFF",  # Fehér
  "#D3D3D3",  # Világosszürke
  "#90EE90",  # Világoszöld
  "#228B22",  # Sötétzöld
  "#FFD700",  # Arany/sárga
  "#FFA500",  # Narancs
  "#FF4500",  # Vöröses-narancs
  "#FF0000",  # Piros
  "#8B0000"   # Bordó
)
custom_cols <- colorRampPalette(custom_breaks)(100)
custom_cols_LR <- rev(custom_cols)  # Fordított skála LR_500700hPa-hez

# Változónevek és egységek
var_units <- c(
  MU_CAPE = "J/kg", MU_CIN = "J/kg", MU_LI = "K",
  SB_CAPE = "J/kg", SB_HGL_CAPE = "J/kg", ML_CAPE = "J/kg", ML_HGL_CAPE = "J/kg",
  LR_500700hPa = "K/km", FRZG_HGT = "m AGL", FRZG_wetbulb_HGT = "m AGL",
  PRCP_WATER = "mm", RH_14km = "%", BS_06km = "m/s", BS_36km = "m/s",
  BS_26km = "m/s", TIP = "dimensionless"
)

# ERA5 változónevek leképezése
var_mapping <- list(
  MU_CAPE = "MU_CAPE", MU_CIN = "MU_CIN", MU_LI = "MU_LI",
  SB_CAPE = "SB_CAPE", SB_HGL_CAPE = "SB_CAPE_HGL",
  ML_CAPE = "ML_CAPE", ML_HGL_CAPE = "ML_CAPE_HGL",
  LR_500700hPa = "LR_500700", FRZG_HGT = "HGT_ISO_0",
  FRZG_wetbulb_HGT = "HGT_ISO_0_wetbulb", PRCP_WATER = "PRCP_WATER",
  RH_14km = "RH_14km", BS_06km = "BS_06km"
)

# Layout lista
layout_list <- list(
  list(vars = c("LR_500700hPa", "RH_14km", "PRCP_WATER")),
  list(vars = c("MU_CAPE", "MU_CIN", "MU_LI")),
  list(vars = c("SB_CAPE", "SB_HGL_CAPE", "ML_CAPE", "ML_HGL_CAPE")),
  list(vars = c("FRZG_HGT", "FRZG_wetbulb_HGT")),
  list(vars = c("BS_06km"))
)

# Koordináták
lon_min <- -44.81; lon_max <- 65.19
lat_min <- 21.81; lat_max <- 72.69

# Modellek fájljainak beolvasása
model_files <- list.files(
  "/data8/climateattribution/thunder_analysis",
  pattern = "timmean_pctl.*\\.nc$",
  full.names = TRUE
)
parse_model_filename <- function(file) {
  fname <- basename(file)
  parts <- strsplit(fname, "_")[[1]]
  list(
    file = file,
    pctl = parts[2],
    gcm = parts[3],
    scenario = parts[4],
    rcm = sub("\\.nc$", "", parts[length(parts)])
  )
}
model_metadata <- do.call(rbind, lapply(model_files, function(f) as.data.frame(parse_model_filename(f), stringsAsFactors = FALSE)))
model_combos <- unique(model_metadata[c("pctl", "gcm", "scenario", "rcm")])

# ERA5 fájljainak beolvasása
era5_files <- list.files(
  "/data8/climateattribution/convective_parameters_calc_with_thunder/ERA5",
  pattern = "timmean_pctl.*\\.nc$",
  full.names = TRUE
)
parse_era5_filename <- function(file) {
  fname <- basename(file)
  parts <- strsplit(fname, "_")[[1]]
  list(
    file = file,
    pctl = parts[2],
    year = parts[3]
  )
}
era5_metadata <- do.call(rbind, lapply(era5_files, function(f) as.data.frame(parse_era5_filename(f), stringsAsFactors = FALSE)))
era5_combos <- unique(era5_metadata[c("pctl", "year")])

# Globális skálák kiszámítása (modellek + ERA5, ha létezik)
global_scaling <- list()
for (pctl in unique(c(model_metadata$pctl, era5_metadata$pctl))) {

  # BS_* változók
  bs_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      for (vn in c("BS_06km", "BS_36km", "BS_26km")) {
        if (vn %in% names(nc$var)) {
          val <- ncvar_get(nc, vn)
          if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
          bs_vals <- c(bs_vals, val[is.finite(val)])
        }
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      for (vn in names(var_mapping)) {
        if (var_mapping[[vn]] %in% c("BS_06km") && var_mapping[[vn]] %in% names(nc$var)) {
          val <- ncvar_get(nc, var_mapping[[vn]])
          if (length(dim(val)) == 2) bs_vals <- c(bs_vals, val[is.finite(val)])
        }
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_bs")]] <- if (length(bs_vals) > 0) range(bs_vals, na.rm = TRUE) else c(0, 30)

  # FRZG_* változók
  frzg_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      for (vn in c("FRZG_HGT", "FRZG_wetbulb_HGT")) {
        if (vn %in% names(nc$var)) {
          val <- ncvar_get(nc, vn)
          if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
          frzg_vals <- c(frzg_vals, val[is.finite(val)])
        }
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      for (vn in names(var_mapping)) {
        if (var_mapping[[vn]] %in% c("HGT_ISO_0", "HGT_ISO_0_wetbulb") && var_mapping[[vn]] %in% names(nc$var)) {
          val <- ncvar_get(nc, var_mapping[[vn]])
          if (length(dim(val)) == 2) frzg_vals <- c(frzg_vals, val[is.finite(val)])
        }
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_frzg")]] <- if (length(frzg_vals) > 0) range(frzg_vals, na.rm = TRUE) else c(0, 5000)

  # PRCP_WATER változó
  prcp_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("PRCP_WATER" %in% names(nc$var)) {
        val <- ncvar_get(nc, "PRCP_WATER")
        if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
        prcp_vals <- c(prcp_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("PRCP_WATER" %in% names(nc$var)) {
        val <- ncvar_get(nc, "PRCP_WATER")
        if (length(dim(val)) == 2) prcp_vals <- c(prcp_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_prcp")]] <- if (length(prcp_vals) > 0) range(prcp_vals, na.rm = TRUE) else c(0, 20)

  # MU_CIN változó
  cin_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("MU_CIN" %in% names(nc$var)) {
        val <- ncvar_get(nc, "MU_CIN")
        if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
        cin_vals <- c(cin_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("MU_CIN" %in% names(nc$var)) {
        val <- ncvar_get(nc, "MU_CIN")
        if (length(dim(val)) == 2) cin_vals <- c(cin_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_cin")]] <- if (length(cin_vals) > 0) range(cin_vals, na.rm = TRUE) else c(-200, 0)

  # LR_500700hPa változó
  lr_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("LR_500700hPa" %in% names(nc$var)) {
        val <- ncvar_get(nc, "LR_500700hPa")
        if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
        lr_vals <- c(lr_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("LR_500700" %in% names(nc$var)) {
        val <- ncvar_get(nc, "LR_500700")
        if (length(dim(val)) == 2) lr_vals <- c(lr_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_lr")]] <- if (length(lr_vals) > 0) range(lr_vals, na.rm = TRUE) else c(-8, -4)

  # RH_14km változó
  rh_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("RH_14km" %in% names(nc$var)) {
        val <- ncvar_get(nc, "RH_14km")
        if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
        rh_vals <- c(rh_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("RH_14km" %in% names(nc$var)) {
        val <- ncvar_get(nc, "RH_14km")
        if (length(dim(val)) == 2) rh_vals <- c(rh_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_rh")]] <- if (length(rh_vals) > 0) range(rh_vals, na.rm = TRUE) else c(0, 100)

  # TIP változó
  tip_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("TIP" %in% names(nc$var)) {
        val <- ncvar_get(nc, "TIP")
        if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
        tip_vals <- c(tip_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_tip")]] <- if (length(tip_vals) > 0) range(tip_vals, na.rm = TRUE) else c(0, 1)

  # MU_LI változó
  mu_li_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      if ("MU_LI" %in% names(nc$var)) {
        val <- ncvar_get(nc, "MU_LI")
        if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
        mu_li_vals <- c(mu_li_vals, val[is.finite(val)])
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_mu_li")]] <- if (length(mu_li_vals) > 0) range(mu_li_vals, na.rm = TRUE) else c(0, 10)

  # CAPE változók
  cape_vals <- c()
  for (file in model_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 4 && parts[2] == pctl) {
      nc <- nc_open(file)
      for (vn in c("MU_CAPE", "SB_CAPE", "SB_HGL_CAPE", "ML_CAPE", "ML_HGL_CAPE")) {
        if (vn %in% names(nc$var)) {
          val <- ncvar_get(nc, vn)
          if (length(dim(val)) == 3) val <- val[1, , , drop = TRUE]
          cape_vals <- c(cape_vals, val[is.finite(val)])
        }
      }
      nc_close(nc)
    }
  }
  for (file in era5_files) {
    parts <- strsplit(basename(file), "_")[[1]]
    if (length(parts) >= 3 && parts[2] == pctl) {
      nc <- nc_open(file)
      for (vn in names(var_mapping)) {
        if (var_mapping[[vn]] %in% c("MU_CAPE", "SB_CAPE", "SB_CAPE_HGL", "ML_CAPE", "ML_CAPE_HGL") && var_mapping[[vn]] %in% names(nc$var)) {
          val <- ncvar_get(nc, var_mapping[[vn]])
          if (length(dim(val)) == 2) cape_vals <- c(cape_vals, val[is.finite(val)])
        }
      }
      nc_close(nc)
    }
  }
  global_scaling[[paste0("pctl_", pctl, "_cape")]] <- if (length(cape_vals) > 0) range(cape_vals, na.rm = TRUE) else if (pctl == "pctl50") c(0, 50) else c(0, 1500)
}

# PDF könyvtár létrehozása
if (!dir.exists("plots")) dir.create("plots", recursive = TRUE)
if (!dir.exists("plots/png")) dir.create("plots/png", recursive = TRUE)

# Ábrázolási függvény (modellek)
plot_nc_map_models <- function(nc_file, varname, lon_min, lon_max, lat_min, lat_max, combo_pctl) {
  nc <- nc_open(nc_file)
  if (!(varname %in% names(nc$var))) {
    nc_close(nc)
    return(NULL)
  }
  vals <- ncvar_get(nc, varname)
  lon_raw <- ncvar_get(nc, "lon")
  lat_raw <- ncvar_get(nc, "lat")
  nc_close(nc)

  if (length(dim(vals)) == 3) vals <- vals[1, , , drop = TRUE]

  # Koordináták kezelése
  lon <- lon_raw
  lat <- lat_raw

  # Skála beállítása
  if (varname %in% c("MU_CAPE", "SB_CAPE", "SB_HGL_CAPE", "ML_CAPE", "ML_HGL_CAPE")) {
    zlim_key <- paste0("pctl_", combo_pctl, "_cape")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname %in% c("BS_06km", "BS_36km", "BS_26km")) {
    zlim_key <- paste0("pctl_", combo_pctl, "_bs")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname %in% c("FRZG_HGT", "FRZG_wetbulb_HGT")) {
    zlim_key <- paste0("pctl_", combo_pctl, "_frzg")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname == "LR_500700hPa") {
    zlim_key <- paste0("pctl_", combo_pctl, "_lr")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols_LR
  } else if (varname == "PRCP_WATER") {
    zlim_key <- paste0("pctl_", combo_pctl, "_prcp")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname %in% c("MU_CIN", "SB_CIN")) {
    zlim_key <- paste0("pctl_", combo_pctl, "_cin")
    zlim <- global_scaling[[zlim_key]]
    cols <- rev(custom_cols)
  } else if (varname == "RH_14km") {
    zlim_key <- paste0("pctl_", combo_pctl, "_rh")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname == "TIP") {
    zlim_key <- paste0("pctl_", combo_pctl, "_tip")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname == "MU_LI") {
    zlim_key <- paste0("pctl_", combo_pctl, "_mu_li")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else {
    zlim <- range(vals, na.rm = TRUE)
    cols <- custom_cols
  }

  # Ábrázolás
  title_txt <- if (!is.null(var_units[varname])) paste0(varname, " [", var_units[varname], "]") else varname
  nx <- ncol(vals); ny <- nrow(vals)
  quilt.plot(
    as.vector(lon), as.vector(lat), as.vector(vals),
    nx = nx, ny = ny,
    xlim = c(lon_min, lon_max), ylim = c(lat_min, lat_max),
    col = cols, zlim = zlim, breaks = sort(seq(zlim[1], zlim[2], length.out = 101)),
    xlab = "", ylab = "", main = title_txt, axes = TRUE,
    add.legend = FALSE
  )
  map("world", add = TRUE, col = "black", lwd = 1)
  image.plot(legend.only = TRUE, zlim = zlim, col = cols, breaks = sort(seq(zlim[1], zlim[2], length.out = 101)),
             legend.mar = 6, axis.args = list(cex.axis = 0.8))
}

# Ábrázolási függvény (ERA5)
plot_nc_map_era5 <- function(nc_file, varname, lon_min, lon_max, lat_min, lat_max, combo_pctl) {
  era5_varname <- var_mapping[[varname]]
  nc <- nc_open(nc_file)
  if (!(era5_varname %in% names(nc$var))) {
    nc_close(nc)
    return(NULL)
  }
  vals <- ncvar_get(nc, era5_varname)
  lon <- ncvar_get(nc, "longitude")
  lat <- ncvar_get(nc, "latitude")
  nc_close(nc)

  # Indexek kiválasztása koordináták alapján
  lon_idx <- which(lon >= lon_min & lon <= lon_max)
  lat_idx <- which(lat >= lat_min & lat <= lat_max)
  vals <- vals[lon_idx, lat_idx]
  lon <- lon[lon_idx]
  lat <- lat[lat_idx]

  # Latitude dimenzió visszafordítása, hogy ne legyen fejjel lefelé
  vals <- vals[, length(lat):1]
  lat <- rev(lat)

  # Skála beállítása
  if (varname %in% c("MU_CAPE", "SB_CAPE", "SB_HGL_CAPE", "ML_CAPE", "ML_HGL_CAPE")) {
    zlim_key <- paste0("pctl_", combo_pctl, "_cape")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname == "BS_06km") {
    zlim_key <- paste0("pctl_", combo_pctl, "_bs")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname %in% c("FRZG_HGT", "FRZG_wetbulb_HGT")) {
    zlim_key <- paste0("pctl_", combo_pctl, "_frzg")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname == "LR_500700hPa") {
    zlim_key <- paste0("pctl_", combo_pctl, "_lr")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols_LR
  } else if (varname == "PRCP_WATER") {
    zlim_key <- paste0("pctl_", combo_pctl, "_prcp")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else if (varname == "MU_CIN") {
    zlim_key <- paste0("pctl_", combo_pctl, "_cin")
    zlim <- global_scaling[[zlim_key]]
    cols <- rev(custom_cols)
  } else if (varname == "RH_14km") {
    zlim_key <- paste0("pctl_", combo_pctl, "_rh")
    zlim <- global_scaling[[zlim_key]]
    cols <- custom_cols
  } else {
    zlim <- range(vals, na.rm = TRUE)
    cols <- custom_cols
  }

  title_txt <- if (!is.null(var_units[varname])) paste0(varname, " [", var_units[varname], "]") else varname

  # Ábrázolás
  image.plot(lon, lat, vals, col = cols, zlim = zlim, xlab = "", ylab = "", main = title_txt, axes = TRUE, add.legend = FALSE)
  map("world", add = TRUE, col = "black", lwd = 1)
  image.plot(legend.only = TRUE, zlim = zlim, col = cols, legend.mar = 6, axis.args = list(cex.axis = 0.8))
}

# PDF létrehozása (modellek)
pdf("plots/climatology_maps_models.pdf", width = 11, height = 8.5, pointsize = 10, useDingbats = FALSE, compress = TRUE)
par(oma = c(3, 0, 3, 0))
for (i in seq_len(nrow(model_combos))) {
  combo <- model_combos[i, ]
  subset_meta <- subset(model_metadata,
                        pctl == combo$pctl &
                          gcm == combo$gcm &
                          scenario == combo$scenario &
                          rcm == combo$rcm)
  if (nrow(subset_meta) == 0) next
  nc_file <- subset_meta$file[1]
  for (layout_info in layout_list) {
    vars_page <- layout_info$vars
    nvars <- length(vars_page)
    layout(matrix(1:4, nrow = 2, byrow = TRUE))
    par(mar = c(3, 3, 2, 6))
    for (j in 1:4) {
      if (j > nvars) { plot.new(); next }
      plot_nc_map_models(nc_file, vars_page[j], lon_min, lon_max, lat_min, lat_max, combo$pctl)
    }
    mtext(paste("pctl:", combo$pctl, "| GCM:", combo$gcm, "| scenario:", combo$scenario, "| RCM:", combo$rcm),
          side = 3, line = 1, outer = TRUE, cex = 1.1, font = 2, adj = 0.5)
    # PNG mentés
    png_filename <- paste0("plots/png/", combo$pctl, "_", combo$gcm, "_", combo$scenario, "_", combo$rcm, "_", paste(vars_page, collapse = "_"), ".png")
    png(png_filename, width = 11, height = 8.5, units = "in", pointsize = 10, res = 300)
    layout(matrix(1:4, nrow = 2, byrow = TRUE))
    par(mar = c(3, 3, 2, 6))
    for (j in 1:4) {
      if (j > nvars) { plot.new(); next }
      plot_nc_map_models(nc_file, vars_page[j], lon_min, lon_max, lat_min, lat_max, combo$pctl)
    }
    mtext(paste("pctl:", combo$pctl, "| GCM:", combo$gcm, "| scenario:", combo$scenario, "| RCM:", combo$rcm),
          side = 3, line = 1, outer = TRUE, cex = 1.1, font = 2, adj = 0.5)
    dev.off()
  }
}
dev.off()

# PDF létrehozása (ERA5)
pdf("plots/climatology_maps_ERA5.pdf", width = 11, height = 8.5, pointsize = 10, useDingbats = FALSE, compress = TRUE)
par(oma = c(3, 0, 3, 0))
for (i in seq_len(nrow(era5_combos))) {
  combo <- era5_combos[i, ]
  subset_meta <- subset(era5_metadata, pctl == combo$pctl & year == combo$year)
  if (nrow(subset_meta) == 0) next
  nc_file <- subset_meta$file[1]
  for (layout_info in layout_list) {
    vars_page <- layout_info$vars
    nvars <- length(vars_page)
    layout(matrix(1:4, nrow = 2, byrow = TRUE))
    par(mar = c(3, 3, 2, 6))
    for (j in 1:4) {
      if (j > nvars) { plot.new(); next }
      plot_nc_map_era5(nc_file, vars_page[j], lon_min, lon_max, lat_min, lat_max, combo$pctl)
    }
    mtext(paste("pctl:", combo$pctl, "| Data: ERA5"),
          side = 3, line = 1, outer = TRUE, cex = 1.1, font = 2, adj = 0.5)
    # PNG mentés
    png_filename <- paste0("plots/png/", combo$pctl, "_ERA5_", paste(vars_page, collapse = "_"), ".png")
    png(png_filename, width = 11, height = 8.5, units = "in", pointsize = 10, res = 300)
    layout(matrix(1:4, nrow = 2, byrow = TRUE))
    par(mar = c(3, 3, 2, 6))
    for (j in 1:4) {
      if (j > nvars) { plot.new(); next }
      plot_nc_map_era5(nc_file, vars_page[j], lon_min, lon_max, lat_min, lat_max, combo$pctl)
    }
    mtext(paste("pctl:", combo$pctl, "| Data: ERA5"),
          side = 3, line = 1, outer = TRUE, cex = 1.1, font = 2, adj = 0.5)
    dev.off()
  }
}
dev.off()

