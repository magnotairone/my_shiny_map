options(shinylive.cache = "C:/temp/shinylive_cache")

unlink("docs", recursive = TRUE, force = TRUE)

shinylive::export(
  appdir = "../my_shiny_map/",
  destdir = "docs/",
  overwrite = TRUE
)

