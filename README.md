# AnimeFlix

App estilo Netflix para animes, em Flutter (Linux Mint + Android, mesma base de código).
Catálogo automático, biblioteca offline, downloads com retomada e autoplay.

## Instalar no Linux Mint
```bash
cd animeflix
bash scripts/install_linux.sh      # instala dependências + Flutter, compila e cria o atalho "AnimeFlix"
```

## Gerar o APK (Android)
```bash
bash scripts/build_apk.sh          # gera ./AnimeFlix.apk (baixa JDK 17 e Android SDK sozinho)
```
Alternativa sem instalar nada: suba o projeto no GitHub e rode a ação **Build APK** (`.github/workflows/apk.yml`); o APK sai como artefato.

## Como usar (importante para uso offline)
1. **Com internet, uma vez:** abra o app. O catálogo (capas, sinopses, categorias) é baixado e salvo no aparelho; atualiza sozinho a cada 6 h quando houver internet.
2. Abra um anime e traga os episódios por um destes caminhos:
   - **Importar arquivos** — seus próprios vídeos (backups das suas mídias). O app lê temporada/episódio do nome (`S01E03`, `EP03`, `- 03`), copia para a biblioteca e marca o idioma (Dublado / Legendado / Dub+Leg).
   - **Fontes legais** — busca no Internet Archive (apenas itens Creative Commons / domínio público); escolha os arquivos/qualidade e baixe.
   - **URL direta** — para arquivos que você tem autorização de baixar.
3. Em **Biblioteca / Downloads** acompanhe progresso, pause, continue, cancele. Tudo (banco, capas, vídeos) fica em disco e funciona sem internet.
4. O player salva onde você parou e, ao terminar, inicia o próximo episódio (contagem regressiva ajustável; cancelável; liga/desliga em Config. ou no player). Ao fim da temporada, vai para a próxima. Sem próximo baixado, avisa para baixar.

Atalhos (desktop): Espaço = play/pause, ←/→ = ∓10 s, F = tela cheia, Esc = sair da tela cheia.

## Limites conhecidos (leia)
- **Dublagem PT-BR:** não existe API gratuita e legal que diga quais episódios têm dublagem. O idioma de cada episódio vem do que você informa ao importar, dos metadados da fonte e da leitura das faixas de áudio do arquivo (o player detecta áudio/legenda em português e seleciona conforme sua preferência). Você pode corrigir a etiqueta no menu ⋮ do episódio. As fileiras “Animes dublados/legendados” mostram o que existe na **sua** biblioteca; o catálogo online (AniList) não informa dublagem.
- **Streamings pagos** (Crunchyroll, Netflix etc.) não permitem download fora dos apps oficiais, então não são fontes. Fontes livres de anime com dublagem PT-BR são raras.
- **Sincronização entre dispositivos:** sem servidor/conta; é feita por arquivo (Config. → Exportar/Importar lista e progresso).
- **Downloads em segundo plano no Android:** continuam enquanto o app está aberto/em memória; serviço em primeiro plano (que sobrevive ao app fechado) não está incluído.
- **Qualidade no player:** arquivos locais têm uma qualidade só; a escolha de qualidade acontece ao selecionar o arquivo na fonte.
- Não baixa nada sem sua ação; ao reabrir o app, downloads interrompidos ficam pausados.

## Estrutura
```
lib/core      modelos, banco SQLite, configurações
lib/services  AniList (catálogo), Internet Archive, downloader, importer, backup
lib/ui        telas (início, busca, detalhe, biblioteca, downloads, config, player)
scripts       install_linux.sh, build_apk.sh, patch_android.sh
```
Bibliotecas: media_kit (player, libmpv), dio, sqlite3, file_picker.

## Publicar no GitHub
```bash
git init -b main && git add . && git commit -m "AnimeFlix: versão inicial"
git remote add origin https://github.com/SEU_USUARIO/animeflix.git
git push -u origin main
```
Depois: aba **Actions → Build APK → Run workflow**; o APK sai em *Artifacts* (`AnimeFlix-apk`).
