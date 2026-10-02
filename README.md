# w2f-multicharacter (Lation Modern UI — Emerald Edition)

Cinematic multicharacter selection for **Qbox** — character create / select / delete / spawn, with illenium-appearance, optional starter apartments and the official **Lation Modern UI Design System (Emerald Edition)**.

## 💎 Design System & UX (Emerald Edition)
- **Visual Identity:** Paleta oficial Lation (`#10b981`, `#6afe87`, `#1e1f24`), acento lateral `inset 3px 0 0 var(--accent)`, e tipografia técnica dupla (`Inter` para textos, `JetBrains Mono` para moedas e IDs).
- **Auto-Seleção Inteligente:** Ao entrar na tela, o sistema seleciona automaticamente o último personagem jogado ou o primeiro disponível, focando a câmera e exibindo a ficha do cidadão sem deixar o jogador travado.
- **Navegação Híbrida (Mouse & Teclado):**
  - **Teclas Numéricas (`1`, `2`, `3`...):** Seleciona diretamente o slot correspondente.
  - **Setas (`←`, `→` ou `A`, `D`):** Alterna suavemente entre os personagens da cena.
  - **Mouse:** Clique direto no Ped 3D in-game (com raycast ampliado e tolerante) OU na barra superior de pills.
  - **Enter / Espaço:** Confirma e entra na cidade com o personagem ativo.
  - **Delete:** Aciona a exclusão segura com protocolo de confirmação.
- **Docked Dossier Card:** Painel lateral direito translúcido com `backdrop-filter: blur(16px)` para leitura estável e sem tremores das métricas do personagem (dinheiro, banco, telefone, idade, tempo de jogo, última localização).
- **Cinematografia Orgânica:** Câmera com micro hand-shake orgânico ao inspecionar o personagem.
- **Slots Dinâmicos por Jogador:** Suporte a slots individuais configuráveis via comando `/setslot <id> <slots>` ou exports.
- **Phone Number Resolver Desacoplado:** Compatibilidade nativa com `lb-phone`, `qs-smartphone-pro`, `qs-smartphone`, `yseries` e fallback no DB.
- **Modal de Criação:** Validação reativa de nomes, campos de data e seleção de nacionalidade/gênero.
- **Deleção Segura:** Protocolo com exigência de digitação `DELETAR` e bloqueio anti-dupe / anti-spam.
- **Locales Nativos:** Tradução integral em português do Brasil (`locales/pt-br.json`).

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance) — required for new-character clothing
- [qbx_properties](https://github.com/Qbox-project/qbx_properties) — only if you use the default starter-apartment flow

## Install

### 1. Add the resource

Place the folder at:

```
resources/[w2f]/w2f-multicharacter/
```

### 2. Import the database (once)

Run this file against your server database (HeidiSQL, phpMyAdmin, etc.):

```
sql/install.sql
```

Skip this if you already have a working Qbox database with `players`, `users`, and illenium-appearance tables. The script is safe to re-run.

### 3. Enable external characters in Qbox

In `qbx_core/config/client.lua`:

```lua
characters = {
    useExternalCharacters = true,
    -- ...
}
```

If this stays `false`, qbx_core and w2f-multicharacter will both try to open character selection.

### 4. Configure this resource

In `config.lua`, confirm:

```lua
Config.UseExternalCharacters = true
Config.AutoOpen = true
```

**Apartments are fully optional.** The starter-apartment flow auto-detects whether an apartment system is running and degrades gracefully when one is not — no config change is required to run with or without apartments.

**Starter apartment flow (when available):** leave `Config.CharacterCreation.directToApartment = true` and ensure the apartment resource named by `Config.CharacterCreation.apartmentResource` (default `qbx_properties`) is running. Set `starterApartmentIndex` to match an entry in that resource's `config/shared.lua` (`apartmentOptions`). New characters are dropped directly into their starter apartment with the clothing editor opening inside.

**No apartments (standalone):** if the `apartmentResource` is not started (or you set `directToApartment = false`, or `apartmentResource = ''`), creation automatically uses the appearance-editor → spawn-picker flow. The spawn picker shows only the default `Config.Spawns` locations (no apartment cards), and no `properties` table is required.

### 5. Update server.cfg

Stop the default Qbox spawn resource and start w2f-multicharacter **after** its dependencies:

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure illenium-appearance
ensure qbx_properties   # only if using starter apartments

stop qbx_spawn          # required — conflicts with this spawn system

ensure [w2f]
ensure w2f-multicharacter
```

### 6. Restart and verify

1. Restart the server (or `ensure w2f-multicharacter`).
2. Connect — the cinematic character selector should open automatically.
3. Create a character, finish appearance, and spawn in.

If selection does not open, check the server console for missing-table warnings from `server/database.lua`.

## Optional config

| Setting | File | Purpose |
|---------|------|---------|
| `Config.General.MaxCharacters` | `config.lua` | Character slots per player (match `Config.Scene.pedSlots`) |
| `Config.Spawns` | `config.lua` | Spawn locations in the sky picker |
| `Config.CharacterCreation` | `config.lua` | Name/DOB limits, apartment vs spawn-picker flow |
| `Config.Debug` | `config.lua` | Dev commands (`/w2fmc_open`, `/w2fmc_state`, etc.) |

## License

MIT
