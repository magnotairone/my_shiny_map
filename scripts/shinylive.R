# Gera o site estatico (GitHub Pages) em docs/.
# Rodar a partir da raiz do repositorio: source("scripts/shinylive.R")
options(shinylive.cache = "C:/temp/shinylive_cache")

unlink("docs", recursive = TRUE, force = TRUE)

# Exporta SO a pasta app/ (app.R + data/). As imagens ficam de fora do
# bundle, senao o navegador precisaria baixar todas antes de abrir o app.
shinylive::export(
  appdir = "app",
  destdir = "docs",
  overwrite = TRUE
)

# Copia as imagens como arquivos estaticos normais: o navegador baixa cada
# uma sob demanda (e guarda em cache). O app as referencia como "../img/...".
dir.create(file.path("docs", "img"), recursive = TRUE, showWarnings = FALSE)
file.copy(
  file.path("img", c("thumbs", "photos")),
  file.path("docs", "img"),
  recursive = TRUE
)

# Para testar localmente:
# httpuv::runStaticServer("docs")
