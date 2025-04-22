library(ncdf4)
library(dplyr)
library(thunder)

if (length(commandArgs(trailingOnly = TRUE)) == 0) {
  stop("No input file provided. Please provide the path to the input file (/home/pr_thpi/pr_thunder_scratch/thunder_input/alt_split_*.nc).")
}

# Give input file name as argument (and list all and parallelize with slurm later on)
  alt_file <- commandArgs(trailingOnly = TRUE)[1]
  wd_file <- sub("alt_split", "wd_split", alt_file)
  ta_file <- sub("alt_split", "ta_split", alt_file)
  ws_file <- sub("alt_split", "ws_split", alt_file)
  td_file <- sub("alt_split", "td_split", alt_file)
  out_file <- sub("/home/pr_thpi/pr_thunder_scratch/thunder_input/alt_split", "/home/pr_thpi/pr_thunder_scratch/thunder_output/params_split", alt_file)

  file_paths <- c(alt_file, wd_file, ta_file, ws_file, td_file)

nc_data_list <- lapply(file_paths, nc_open)
nc_file <- nc_data_list[[1]]
dimension_names <- names(nc_file$dim)

source_attrs <- ncatt_get(nc_file, "alt") 
attributes_to_extract <- c("grid_mapping", "coordinates", "missing_value","_Storage", "_ChunkSizes", "_DeflateLevel", "_Shuffle", "_Endianness", "_NoFill")

plev <- ncvar_get(nc_file, "plev") / 100  # convert to hPa from Pa 

# Assign dimensions to axes
axis_attributes <- lapply(dimension_names, function(dim_name) ncatt_get(nc_file, dim_name, "axis"))
dim_indices <- sapply(axis_attributes, function(attr) attr$value)
nx <- nc_file$dim[[dimension_names[dim_indices == "X"][1]]]$len
ny <- nc_file$dim[[dimension_names[dim_indices == "Y"][1]]]$len
nz <- nc_file$dim[[dimension_names[dim_indices == "Z"][1]]]$len
nt <- nc_file$dim[[dimension_names[dim_indices == "T"][1]]]$len

plev_sorted <- sort(plev, decreasing = TRUE)

# Specify the parameters to write
file_path_params <- "/home/pr_thpi/pr_thunder_scratch/lists/conv-param-list-narrowed-16.txt"
params <- readLines(file_path_params)

# Create a list to store the arrays
arrays <- lapply(params, function(name) array(NA, dim = c(nx, ny, nt)))
names(arrays) <- params

for (t in 1:1) {
  for (y in 1:ny) {
    for (x in 1:nx) {
      alt_point <- ncvar_get(nc_data_list[[1]], "alt", start = c(x, y, 1, t), count = c(1, 1, nz, 1))
      wd_point <- ncvar_get(nc_data_list[[2]], "wd", start = c(x, y, 1, t), count = c(1, 1, nz, 1))
      ta_point <- ncvar_get(nc_data_list[[3]], "ta", start = c(x, y, 1, t), count = c(1, 1, nz, 1))
      ws_point <- ncvar_get(nc_data_list[[4]], "ws", start = c(x, y, 1, t), count = c(1, 1, nz, 1))
      td_point <- ncvar_get(nc_data_list[[5]], "td", start = c(x, y, 1, t), count = c(1, 1, nz, 1))

      # Sort variables in reverse order (by pressure levels)
      alt_point <- alt_point[nz:1]
      wd_point <- wd_point[nz:1]
      ta_point <- ta_point[nz:1]
      ws_point <- ws_point[nz:1]
      td_point <- td_point[nz:1]

      # Calculate atmospheric profiles
      profile <- sounding_compute(plev_sorted, alt_point, ta_point, td_point, wd_point, ws_point, 1)

      # Update the arrays in the list
      for (name in params) {
        arrays[[name]][x, y, t] <- profile[name]

      # Debugging: Print the profile values
#      cat("Conv.param. at (x, y, t) = (", x, ", ", y, ", ", t, "):\n")
#      print(arrays[[name]][x, y, t] )
      }
    }
  }
}

fill_value <- 1e+20

time_dim <- nc_file$dim[[dimension_names[dim_indices == "T"][1]]]
lat_dim <- nc_file$dim[[dimension_names[dim_indices == "Y"][1]]]
lon_dim <- nc_file$dim[[dimension_names[dim_indices == "X"][1]]]

lon <- ncvar_get(nc_file, "lon")
lat <- ncvar_get(nc_file, "lat")
rp_attrs <- ncatt_get(nc_file, "rotated_pole")

lon_var_def <- ncvar_def("lon", units = "degrees_east", dim = list(lon_dim,lat_dim), prec = "float", missval = fill_value)
lat_var_def <- ncvar_def("lat", units = "degrees_north", dim = list(lon_dim,lat_dim), prec = "float", missval = fill_value)
rotated_pole_var <- ncvar_def("rotated_pole", units = "", prec="char", list())

param_vars <- lapply(params, function(name) {
  ncvar_def(name = name, units = "", dim = list(lon_dim, lat_dim, time_dim), prec = "float", missval = fill_value, compression=4)
})

vars <- c(list(rotated_pole_var, lon_var_def, lat_var_def), param_vars)

# Now create the file using the list of ncvar objects
output <- nc_create(out_file, vars, force_v4 = TRUE)

ncvar_put(output, "lon", lon)
ncvar_put(output, "lat", lat)

for (att_name in names(rp_attrs)) {
  ncatt_put(output, "rotated_pole", att_name, rp_attrs[[att_name]])
}

# Write each variable's data
for (i in seq_along(params)) {
  name <- params[i]
  ncvar_put(output, name, arrays[[name]], start=c(1,1,1), count=c(-1,-1,-1))

  # Add attributes if present
  for (att_name in attributes_to_extract) {
    if (att_name %in% names(source_attrs) && att_name != "_FillValue") {
      att_value <- source_attrs[[att_name]]
      if (is.list(att_value) && !is.null(att_value$value)) {
        att_value <- att_value$value
      }
      ncatt_put(output, name, att_name, att_value)
    }
  }
}

lapply(nc_data_list, nc_close)
nc_close(output)

# Print the file being processed (for debugging purposes)
cat("Processing file:", alt_file, "\n")

