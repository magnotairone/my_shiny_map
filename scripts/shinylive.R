options(shinylive.cache = "C:/temp/shinylive_cache")

shinylive::export(
  appdir = ".",
  destdir = paste0(getwd(), "/docs")
)
