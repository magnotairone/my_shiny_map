# my_photo_map

Shiny app para mapear fotos geolocalizadas (minhas viagens).

Visão geral
- Baixe/extraia seu álbum do Google Photos (recomendado: Google Takeout).
- Coloque os arquivos de imagem extraídos em `photos/` no diretório do projeto (ex.: `my_photo_map/photos/`).
- Execute o app Shiny localmente; ele irá extrair EXIF (GPS), criar miniaturas e mostrar as fotos num mapa (leaflet).

Instalação
1. Instale dependências em R:
```
install.packages(c("shiny","leaflet","dplyr","htmltools","magick","exifr","readr"))
```
Observação: `exifr` depende do `exiftool` (normalmente instala/usa automaticamente). Se houver problemas, instale `exiftool` no seu sistema (ex.: `brew install exiftool` no macOS/Homebrew, `sudo apt install libimage-exiftool-perl` em Debian/Ubuntu).

2. Estrutura esperada:
- app.R
- photos/                # coloque as fotos extraídas aqui (Download do Takeout) — em geral esta pasta é ignorada no git
- data/                  # CSVs gerados com metadados (ex.: photo_metadata_drive.csv)
- www/photos/            # gerado automaticamente (versões médias servidas pelo Shiny quando usar fotos locais)
- www/thumbs/            # gerado automaticamente (miniaturas para popups)
- scripts/               # scripts auxiliares (upload para Google Drive, extração de EXIF, etc.)

Como rodar
```
# no R
shiny::runApp("path/to/my_photo_map")
```

Fluxo recomendado: Google Drive → CSV → app

Este projeto fornece um script que automatiza o upload das suas fotos (baixadas via Google Takeout) para uma pasta do Google Drive, torna os arquivos compartilháveis e gera um CSV com URLs públicas e metadados (lat, lon, datetime). O app Shiny foi atualizado para preferir esse CSV quando presente.

Passos resumidos:
1. Coloque suas fotos extraídas do Google Takeout em `photos/` (local).
2. Execute o script que faz upload e gera o CSV:
```
# instale dependências do script (uma vez)
install.packages(c("googledrive","exifr","dplyr","readr","purrr","fs","glue","tibble"))

# rode o script (abre o navegador para autenticação OAuth na primeira vez)
Rscript scripts/upload_to_drive_and_index.R
```
Opções via variáveis de ambiente (opcional):
- GDRIVE_FOLDER_ID — usar uma pasta Drive existente (ID) em vez de criar nova
- GDRIVE_FOLDER_NAME — nome da pasta a criar (padrão: my_shiny_map_photos)
- OVERWRITE=TRUE — sobrescrever arquivos com mesmo nome na pasta Drive
- DRY_RUN=TRUE — fazer simulação sem upload

3. O script irá criar `data/photo_metadata_drive.csv` contendo colunas como: SourceFile, FileName, DriveId, DriveURL, lat, lon, DateTimeOriginal, Uploaded.
4. Revise `data/photo_metadata_drive.csv`. Se estiver de acordo, commite-o no repositório (atenção à privacidade — o CSV contém URLs públicas se o script configurou compartilhamento):
```
git add data/photo_metadata_drive.csv
git commit -m "Add photo metadata CSV from Google Drive"
git push origin initial-scaffold
```
5. Rode o app Shiny: quando `data/photo_metadata_drive.csv` estiver presente, o app usará as URLs nela para exibir as imagens diretamente; caso contrário, o app usa o modo local (gera miniaturas em `www/thumbs/` e média em `www/photos/`).

Privacidade e avisos
- O script por padrão chama `drive_share(..., type = "anyone")` para tornar as imagens acessíveis via link. NÃO comite o CSV em um repositório público se você não quer que suas fotos fiquem publicamente acessíveis.
- Se preferir manter as fotos privadas, não execute `drive_share` ou use outra solução (bucket com URLs assinadas, servidor autenticado, ou manter fotos apenas localmente).

Alternativas
- Se quiser versionar imagens no repositório, use Git LFS (recomendado apenas se compreender limites e custos) ou commit apenas algumas imagens de exemplo em `sample_photos/`.
- Outra opção: fazer upload das miniaturas (thumbnails) para Drive no lugar das imagens originais, e apontar o CSV para thumbnails para reduzir largura de banda e tempo de carregamento do navegador.

Descrição do repositório (para o GitHub): Shiny app para mapear fotos geolocalizadas que tirei durante minhas viagens. O app suporta tanto fotos locais (pasta photos/) quanto um fluxo Drive→CSV para hospedar imagens externamente e manter o repositório leve.
