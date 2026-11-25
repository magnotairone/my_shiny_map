TL;DR
- Visualização de fotos geolocalizadas em um mapa (Shiny + Leaflet).  
- Fotos amadoras que fiz durante minhas viagens.

# my_photo_map

Shiny app para mapear fotos geolocalizadas de viagens.

Objetivo
- Fornecer uma interface simples (Shiny + Leaflet) para visualizar fotos que possuem coordenadas EXIF em um mapa.
- Suportar duas fontes de imagens: URLs externas (ex.: Google Drive via CSV de metadados) ou arquivos locais (pasta `photos/`), com fallback automático entre elas.

Estrutura geral do repositório
- `app/` — o app Shiny (é só esta pasta que o shinylive empacota).
  - `app.R` — aplicação principal (mapa, popups e painel lateral).
  - `data/photos_data.rds` — metadados das fotos (coordenadas, data, local, bandeira, caminhos das imagens).
- `img/thumbs/`, `img/photos/` — miniaturas (240px) e fotos médias (1024px) em WebP, sem EXIF. Ficam **fora** de `app/` de propósito: assim não entram no bundle do shinylive e o navegador baixa cada imagem só quando ela é exibida.
- `photos/` — originais (Google Takeout) + JSONs de metadados; só os JSONs são versionados.
- `scripts/`
  - `process_photos.R` — lê `photos/`, gera `img/` e `app/data/photos_data.rds`.
  - `shinylive.R` — exporta `app/` para `docs/` e copia `img/` para `docs/img/`.
  - `upload_to_drive_and_index.R`, `extract_exif.R` — scripts auxiliares (opcionais).
- `.github/workflows/` — lint e checagens.
- `LICENSE` — Apache License 2.0.

Como rodar
- Local: `shiny::runApp("app")`
- Site estático: `source("scripts/shinylive.R")` e depois `httpuv::runStaticServer("docs")`

Linguagem principal
- R

Licença
- Apache-2.0