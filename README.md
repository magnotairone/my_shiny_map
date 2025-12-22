TL;DR
- Visualize fotos geolocalizadas em um mapa (Shiny + Leaflet).  
- Suporta duas fontes: CSV com URLs (Drive → CSV) ou fotos locais (fallback).  
- Estrutura simples: coloque CSV em `data/` ou fotos em `photos/` e rode o app.

# my_photo_map

Shiny app para mapear fotos geolocalizadas de viagens.

Objetivo
- Fornecer uma interface simples (Shiny + Leaflet) para visualizar fotos que possuem coordenadas EXIF em um mapa.
- Suportar duas fontes de imagens: URLs externas (ex.: Google Drive via CSV de metadados) ou arquivos locais (pasta `photos/`), com fallback automático entre elas.

Estrutura geral do repositório
- `app.R` — aplicação Shiny principal (lógica de leitura de metadados, geração de popups e mapa).
- `scripts/`
  - `upload_to_drive_and_index.R` — script para enviar fotos ao Google Drive e gerar `data/photo_metadata_drive.csv`.
  - `extract_exif.R` — script auxiliar para extrair EXIF localmente (opcional).
- `data/` — local para CSVs de metadados (ex.: `photo_metadata_drive.csv`).
- `www/photos/`, `www/thumbs/` — diretórios gerados pelo app em modo local para armazenar imagens médias e miniaturas.
- `.github/workflows/` — workflows (lint, checagens) usados no repositório.
- `LICENSE` — Apache License 2.0.

Linguagem principal
- R

Licença
- Apache-2.0

Descrição curta (para exibição)
- Aplicação Shiny para mapear e explorar fotos geolocalizadas, com suporte a fotos locais e a um fluxo Drive → CSV para manter o repositório leve.
