# Script: upload_to_drive_and_index.R
# Upload local photos (Google Takeout) to a Google Drive folder, make them shareable,
# extract EXIF (lat/lon/datetime) and write a CSV (data/photo_metadata_drive.csv).
#
# Usage:
#   - Interactive in RStudio: source("scripts/upload_to_drive_and_index.R")
#   - From shell: Rscript scripts/upload_to_drive_and_index.R
#
# Requirements:
#   install.packages(c("googledrive","exifr","dplyr","readr","purrr","fs"))
#
# Google API:
#   - The first run will open a browser for OAuth consent (googledrive::drive_auth()).
#   - If you want to use a Service Account, set the env var GARGLE_SERVICE_JSON and
#     adapt authentication (see googledrive docs). This script uses interactive OAuth by default.
#
# Environment variables (optional):
#   - GDRIVE_FOLDER_ID : if set, the script will use that folder ID instead of creating/finding by name.
#   - GDRIVE_FOLDER_NAME: folder name to create/find if GDRIVE_FOLDER_ID not provided (default: "my_shiny_map_photos")
#   - OVERWRITE : if "TRUE", existing files with same name in the folder will be overwritten (default: "FALSE")
#   - DRY_RUN : if "TRUE", does everything except actually upload/modify Drive (for testing)
#
# Output:
#   - data/photo_metadata_drive.csv  (created/overwritten)
#
# IMPORTANT: review results before committing the CSV if you have private photos.

library(googledrive)
library(exifr)
library(dplyr)
library(readr)
library(purrr)
library(fs)
library(glue)

# ---- Config ----
photos_dir <- "photos"                 # local folder with Google Takeout images
out_dir <- "data"
out_csv <- file.path(out_dir, "photo_metadata_drive.csv")

# Drive target
drive_folder_id_env <- Sys.getenv("GDRIVE_FOLDER_ID", unset = "")
drive_folder_name <- Sys.getenv("GDRIVE_FOLDER_NAME", unset = "my_shiny_map_photos")
overwrite_flag <- identical(toupper(Sys.getenv("OVERWRITE", unset = "FALSE")), "TRUE")
dry_run <- identical(toupper(Sys.getenv("DRY_RUN", unset = "FALSE")), "TRUE")

# file types to include
img_globs <- c("*.jpg","*.jpeg","*.png","*.JPG","*.JPEG","*.PNG")

# ---- Helpers ----
stop_if_missing_photos <- function() {
  if (!dir_exists(photos_dir)) {
    stop(glue("Photos directory not found: '{photos_dir}'. Place your Takeout images there."), call. = FALSE)
  }
}

list_image_files <- function(dir) {
  # recursive listing using fs::dir_ls with multiple globs
  files <- unlist(lapply(img_globs, function(g) {
    tryCatch(dir_ls(dir, recurse = TRUE, glob = g), error = function(e) character(0))
  }), use.names = FALSE)
  # make unique and keep stable order
  unique(files)
}

# ---- Authenticate ----
message("Authenticating with Google Drive (interactive)...")
# This will open a browser to grant access the first time.
# If you prefer using a service account, set GARGLE_SERVICE_JSON before running.
drive_auth()  # interactive by default

# ---- Ensure output folder ----
dir_create(out_dir, recurse = TRUE)

# ---- Ensure photos exist ----
stop_if_missing_photos()
img_files <- list_image_files(photos_dir)
if (length(img_files) == 0) {
  stop("No image files found under '", photos_dir, "'. Supported extensions: jpg/jpeg/png.", call. = FALSE)
}
message(glue("Found {length(img_files)} image files under '{photos_dir}'."))

# ---- Find or create Drive folder ----
if (nzchar(drive_folder_id_env)) {
  target_folder <- as_id(drive_folder_id_env)
  message(glue("Using provided Drive folder ID: {drive_folder_id_env}"))
} else {
  # try to find folder by name in My Drive (non-recursive)
  existing <- drive_find(q = glue("mimeType = 'application/vnd.google-apps.folder' and name = '{drive_folder_name}'"), n_max = 10)
  if (nrow(existing) > 0) {
    # pick the first match
    target_folder <- existing$id[1]
    message(glue("Found existing folder '{drive_folder_name}' with id: {target_folder}"))
  } else {
    if (dry_run) {
      message(glue("[DRY RUN] Would create folder '{drive_folder_name}' in Drive"))
      target_folder <- NA
    } else {
      f <- drive_mkdir(drive_folder_name)
      target_folder <- f$id
      message(glue("Created Drive folder '{drive_folder_name}' (id: {target_folder})"))
    }
  }
}

# list existing files in folder (names -> ids)
existing_in_folder <- tibble()
if (!is.na(target_folder)) {
  # drive_ls with as_id requires folder id or path
  existing_in_folder <- tryCatch({
    drive_ls(as_id(target_folder))
  }, error = function(e) {
    message("Warning: could not list existing files in target folder: ", e$message)
    tibble()
  })
}

existing_names <- if (nrow(existing_in_folder) > 0) existing_in_folder$name else character(0)

# ---- Process files ----
result_rows <- vector("list", length(img_files))

for (i in seq_along(img_files)) {
  local_path <- as.character(img_files[i])
  file_name <- path_file(local_path)
  message(glue("[{i}/{length(img_files)}] Processing: {file_name}"))

  # Extract EXIF locally (so we have lat/lon even if upload fails)
  exif_info <- tryCatch({
    exifr::read_exif(local_path, tags = c("SourceFile","GPSLatitude","GPSLongitude","DateTimeOriginal"))
  }, error = function(e) {
    warning("EXIF read error for ", local_path, ": ", e$message)
    data.frame(SourceFile = local_path, GPSLatitude = NA, GPSLongitude = NA, DateTimeOriginal = NA, stringsAsFactors = FALSE)
  })
  lat <- if ("GPSLatitude" %in% names(exif_info)) exif_info$GPSLatitude[1] else NA
  lon <- if ("GPSLongitude" %in% names(exif_info)) exif_info$GPSLongitude[1] else NA
  dt <- if ("DateTimeOriginal" %in% names(exif_info)) exif_info$DateTimeOriginal[1] else NA

  # Skip upload if file with same name exists and overwrite_flag == FALSE
  already_exists <- file_name %in% existing_names

  drive_id <- NA_character_
  drive_url <- NA_character_
  uploaded <- FALSE

  if (dry_run) {
    message(glue("[DRY RUN] would upload: {file_name}; exists: {already_exists}"))
  } else {
    if (already_exists && !overwrite_flag) {
      # find the existing entry
      existing_entry <- existing_in_folder %>% filter(name == file_name) %>% slice(1)
      drive_id <- existing_entry$id[1]
      message(glue("Skipping upload (exists and OVERWRITE=FALSE): {file_name} (id: {drive_id})"))
    } else {
      # If exists and overwrite flag, remove first then upload
      if (already_exists && overwrite_flag) {
        message(glue("Overwriting existing file in Drive: {file_name}"))
        existing_entry <- existing_in_folder %>% filter(name == file_name) %>% slice(1)
        tryCatch({
          drive_rm(as_id(existing_entry$id[1]))
          # update existing_names to reflect removal
          existing_names <- setdiff(existing_names, file_name)
        }, error = function(e) {
          warning("Could not remove existing file: ", e$message)
        })
      }

      # Upload
      message(glue("Uploading {file_name} ..."))
      up <- tryCatch({
        drive_upload(media = local_path, path = as_id(target_folder), name = file_name)
      }, error = function(e) {
        warning("Upload failed for ", file_name, ": ", e$message)
        NULL
      })

      if (!is.null(up)) {
        uploaded <- TRUE
        drive_id <- up$id
        # Make shareable (anyone with link can read)
        tryCatch({
          drive_share(as_id(drive_id), role = "reader", type = "anyone")
        }, error = function(e) {
          warning("Could not set sharing permission for ", file_name, ": ", e$message)
        })
        # Refresh metadata to get webViewLink or webContentLink
        meta <- tryCatch({
          drive_get(as_id(drive_id))
        }, error = function(e) {
          warning("Could not retrieve metadata after upload for ", file_name, ": ", e$message)
          NULL
        })
        if (!is.null(meta) && length(meta$drive_resource) > 0) {
          wv <- meta$drive_resource$webViewLink
          wc <- meta$drive_resource$webContentLink
          # Prefer webContentLink if present, otherwise webViewLink, otherwise use uc?id=...
          if (!is.null(wc) && nzchar(wc)) {
            drive_url <- wc
          } else if (!is.null(wv) && nzchar(wv)) {
            drive_url <- wv
          } else {
            drive_url <- glue("https://drive.google.com/uc?export=view&id={drive_id}")
          }
        } else {
          drive_url <- glue("https://drive.google.com/uc?export=view&id={drive_id}")
        }
        # update existing_names and existing_in_folder to include this new file
        existing_names <- c(existing_names, file_name)
        existing_in_folder <- bind_rows(existing_in_folder, tibble(name = file_name, id = drive_id))
      }
    }
  }

  result_rows[[i]] <- tibble::tibble(
    SourceFile = local_path,
    FileName = file_name,
    DriveId = ifelse(is.na(drive_id), NA_character_, as.character(drive_id)),
    DriveURL = ifelse(is.na(drive_url), NA_character_, as.character(drive_url)),
    lat = ifelse(is.null(lat) || is.na(lat), NA_real_, as.numeric(lat)),
    lon = ifelse(is.null(lon) || is.na(lon), NA_real_, as.numeric(lon)),
    DateTimeOriginal = ifelse(is.null(dt) || is.na(dt), NA_character_, as.character(dt)),
    Uploaded = uploaded
  )

  # small sleep to avoid quota throttling
  Sys.sleep(0.2)
}

# ---- Combine and write CSV ----
df_out <- bind_rows(result_rows)

# Optionally, filter to only rows that have coordinates (if app expects that)
# df_out_coords <- df_out %>% filter(!is.na(lat) & !is.na(lon))

write_csv(df_out, out_csv)
message(glue("Wrote metadata CSV to: {out_csv} (rows: {nrow(df_out)})"))

message("Done. Review ", out_csv, " and commit it to the repository if desired.")
