# my_photo_map

Shiny app para mapear fotos geolocalizadas (minhas viagens).

Visão geral
- Baixe/extraia seu álbum do Google Photos (recomendado: Google Takeout).
- Coloque os arquivos de imagem extraídos em `photos/` no diretório do projeto (ex.: `my_photo_map/photos/`).
- Execute o app Shiny localmente; ele irá extrair EXIF (GPS), criar miniaturas e mostrar as fotos num mapa (leaflet).

Instalação
1. Instale dependências em R:
```
install.packages(c("shiny","leaflet","dplyr","htmltools","magick","exifr"))
```
Observação: `exifr` depende do `exiftool` (normalmente instala/usa automaticamente). Se houver problemas, instale `exiftool` no seu sistema (ex.: `brew install exiftool` no macOS/Homebrew, `sudo apt install libimage-exiftool-perl` em Debian/Ubuntu).

2. Estrutura esperada:
- app.R
- photos/                # coloque as fotos extraídas aqui (Download do Takeout)
- www/photos/            # gerado automaticamente (versões médias servidas pelo Shiny)
- www/thumbs/            # gerado automaticamente (miniaturas para popups)
- scripts/extract_exif.R # (opcional) extrai metadata para CSV

Como rodar
```
# no R
shiny::runApp("path/to/my_photo_map")
```

Observações
- O app mapeia apenas imagens que tenham coordenadas EXIF (GPSLatitude/GPSLongitude).
- Miniaturas e versões médias são criadas automaticamente em `www/thumbs/` e `www/photos/` para melhorar performance do navegador.
- Se preferir integração direta com Google Photos API (OAuth), eu posso fornecer o script R para autenticar e baixar as imagens automaticamente — isso exige configurar um projeto no Google Cloud e permitir scopes de leitura.

Descrição do repositório (para o GitHub): Shiny app para mapear fotos geolocalizadas que tirei durante minhas viagens.
