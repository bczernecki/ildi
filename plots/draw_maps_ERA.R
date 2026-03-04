library(ncdf4)
library(viridis)
library(maps)
library(mapdata)
library(fields)

# Színskála definiálása
custom_breaks <- c("#FFFFFF","#D3D3D3","#90EE90","#228B22","#FFD700","#FFA500","#FF4500","#FF0000","#8B0000")
custom_cols <- colorRampPalette(custom_breaks)(100)
custom_cols_LR <- rev(custom_cols)

# ERA5 fájlok
files <- list.files(
  "/data8/climateattribution/convective_parameters_calc_with_thunder/ERA5",
  pattern = "timmean_pctl.*\\.nc$",
  full.names = TRUE
)

# Fájl nevek parse-olása
parse_filename <- function(file) {
  fname <- basename(file)
  parts <- strsplit(fname, "_")[[1]]
  list(file = file, pctl = parts[1], year = parts[2])
}

metadata <- do.call(rbind, lapply(files, function(f) as.data.frame(parse_filename(f), stringsAsFactors = FALSE)))
combos <- unique(metadata[c("pctl", "year")])

# Változónevek és egységek
var_mapping <- list(
  MU_CAPE="MU_CAPE", MU_CIN="MU_CIN", MU_LI="MU_LI",
  SB_CAPE="SB_CAPE", SB_HGL_CAPE="SB_CAPE_HGL",
  ML_CAPE="ML_CAPE", ML_HGL_CAPE="ML_CAPE_HGL",
  LR_500700hPa="LR_500700", FRZG_HGT="HGT_ISO_0", FRZG_wetbulb_HGT="HGT_ISO_0_wetbulb",
  PRCP_WATER="PRCP_WATER", RH_14km="RH_14km", BS_06km="BS_06km"
)

var_units <- c(
  MU_CAPE="J/kg", MU_CIN="J/kg", MU_LI="K",
  SB_CAPE="J/kg", SB_HGL_CAPE="J/kg", ML_CAPE="J/kg", ML_HGL_CAPE="J/kg",
  LR_500700hPa="K/km", FRZG_HGT="m AGL", FRZG_wetbulb_HGT="m AGL",
  PRCP_WATER="mm", RH_14km="%", BS_06km="m/s"
)

layout_list <- list(
  list(vars=c("LR_500700hPa","RH_14km","PRCP_WATER")),
  list(vars=c("MU_CAPE","MU_CIN","MU_LI")),
  list(vars=c("SB_CAPE","SB_HGL_CAPE","ML_CAPE","ML_HGL_CAPE")),
  list(vars=c("FRZG_HGT","FRZG_wetbulb_HGT")),
  list(vars=c("BS_06km"))
)

lon_min <- -44.81; lon_max <- 65.19
lat_min <- 21.81; lat_max <- 72.69

# Globális skálák (egyszerűsítve)
global_scaling <- list()
for (pctl in unique(combos$pctl)) {
  global_scaling[[paste0("pctl_", pctl, "_bs")]] <- c(0,30)
  global_scaling[[paste0("pctl_", pctl, "_frzg")]] <- c(0,5000)
  global_scaling[[paste0("pctl_", pctl, "_prcp")]] <- c(0,20)
  global_scaling[[paste0("pctl_", pctl, "_cin")]] <- c(-200,0)
  global_scaling[[paste0("pctl_", pctl, "_lr")]] <- c(-8,-4)
  global_scaling[[paste0("pctl_", pctl, "_rh")]] <- c(0,1)
  global_scaling[[paste0("pctl_", pctl, "_cape")]] <- if(pctl=="pctl50") c(0,50) else c(0,1500)
}

# Függvény az ábrázoláshoz
plot_nc_map <- function(nc_file, varname, lon_min, lon_max, lat_min, lat_max, combo_pctl, pdf=TRUE, png_path=NULL) {
  era5_varname <- var_mapping[[varname]]
  nc <- nc_open(nc_file)
  if (!(era5_varname %in% names(nc$var))) { nc_close(nc); return(NULL) }
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

  # Skála
  if (varname %in% c("MU_CAPE","SB_CAPE","SB_HGL_CAPE","ML_CAPE","ML_HGL_CAPE")) {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_cape")]]
    cols <- custom_cols
  } else if (varname=="BS_06km") {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_bs")]]
    cols <- custom_cols
  } else if (varname %in% c("FRZG_HGT","FRZG_wetbulb_HGT")) {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_frzg")]]
    cols <- custom_cols
  } else if (varname=="LR_500700hPa") {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_lr")]]
    cols <- custom_cols_LR
  } else if (varname=="PRCP_WATER") {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_prcp")]]
    cols <- custom_cols
  } else if (varname=="MU_CIN") {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_cin")]]
    cols <- rev(custom_cols)
  } else if (varname=="RH_14km") {
    zlim <- global_scaling[[paste0("pctl_", combo_pctl, "_rh")]]
    cols <- custom_cols
  } else {
    zlim <- range(vals, na.rm=TRUE)
    cols <- custom_cols
  }

  title_txt <- if(!is.null(var_units[varname])) paste0(varname," [",var_units[varname],"]") else varname

  # Ábrázolás
  image.plot(lon, lat, vals, col=cols, zlim=zlim, xlab="", ylab="", main=title_txt, axes=TRUE, add.legend=FALSE)
  map("world", add=TRUE, col="black", lwd=1)
  image.plot(legend.only=TRUE, zlim=zlim, col=cols, legend.mar=6, axis.args=list(cex.axis=0.8))
}

# PDF létrehozása
pdf("plots/climatology_maps_ERA5.pdf", width=11, height=8.5, pointsize=10, useDingbats=FALSE, compress=TRUE)
par(oma=c(3,0,3,0))

if (!dir.exists("plots/png")) dir.create("plots/png", recursive=TRUE)

# Plot loop
for (i in seq_len(nrow(combos))) {
  combo <- combos[i,]
  subset_meta <- subset(metadata, pctl==combo$pctl & year==combo$year)
  if (nrow(subset_meta)==0) next
  nc_file <- subset_meta$file[1]

  for (layout_info in layout_list) {
    vars_page <- layout_info$vars
    nvars <- length(vars_page)
    layout(matrix(1:4, nrow=2, byrow=TRUE))
    par(mar=c(3,3,2,6))

    for (j in 1:4) {
      if (j>nvars) { plot.new(); next }
      plot_nc_map(nc_file, vars_page[j], lon_min, lon_max, lat_min, lat_max, combo$pctl)
    }

    mtext(paste("pctl:",combo$pctl,"| Year:",combo$year), side=3, line=1, outer=TRUE, cex=1.1, font=2, adj=0.5)

    # PNG mentés
    png_filename <- paste0("plots/png/", combo$pctl,"_",combo$year,"_",paste(vars_page, collapse="_"),".png")
    png(png_filename, width=11, height=8.5, units="in", pointsize=10, res=300)
    layout(matrix(1:4, nrow=2, byrow=TRUE))
    par(mar=c(3,3,2,6))
    for (j in 1:4) {
      if (j>nvars) { plot.new(); next }
      plot_nc_map(nc_file, vars_page[j], lon_min, lon_max, lat_min, lat_max, combo$pctl)
    }
    mtext(paste("pctl:",combo$pctl,"| Year:",combo$year), side=3, line=1, outer=TRUE, cex=1.1, font=2, adj=0.5)
    dev.off()
  }
}

dev.off()

