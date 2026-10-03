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
- **Modal de Criação:** Validação reativa de nomes, campos de data, seleção de nacionalidade/gênero e escolha de história de chegada (Contêiner, Avião ou Já estava aqui).
- **Deleção Segura:** Protocolo com exigência de digitação `DELETAR` e bloqueio anti-dupe / anti-spam com cascata SQL defensiva.
- **Locales Nativos:** Tradução integral em português do Brasil (`locales/pt-br.json`).

## 🎬 Sistema de Histórias de Chegada & Prelúdio Cinematográfico

- **Prelúdio Cinematográfico (`Config.Prelude`):**
  - Close-up facial dramático com efeito sonoro de *Whoosh* (`1st_Person_Transition`).
  - Congelamento temporal (`SetTimeScale(0.1)`) com filtro clássico preto e branco (`HeistCelebPassBW`) e risco de vinil.
  - Cartão de identidade de cinema com entrada em impacto (*slam-in*) exibindo Nome, Idade e Nacionalidade.
  - Transição de capítulo em corte diagonal revelando local, horário in-game e nome do capítulo.
- **Contêiner do Coiote (`container`):**
  - Spawn em cais portuário realista com navios cargueiros e guindastes (`vec4(428.34, -3005.00, 5.90, 180.0)` em terra firme ampla).
  - Sequência 3D com penumbra interior no contêiner (`tr_prop_tr_container_01a`), som de metal rangendo e buzina de navio.
  - **Interação Dinâmica (Estilo MRI):** O coiote bate 3 vezes na porta de ferro pelo lado de fora (`BOSS_KNOCK`) e grita *"Ei! Chegamos a Los Santos! Empurrem a porta por dentro!"*.
  - **Prompt Interativo [E]:** Card Lation Emerald com tecla pulsante para o jogador forçar a porta. O ped executa animação de impacto/empurrão, a trava estoura com som metálico e as portas se abrem com clarão solar cegante e gaivotas.
  - **Economia & Inventário:** Dinheiro e banco zerados (R$ 0), sem documentos (sem RG/CNH), 5 cigarros e isqueiro garantidos, 20% de chance de celular contrabandeado.
- **Voo Comercial / Avião (`plane`):**
  - Cutscene do GTA Online ou travelling aéreo cinematográfico *in-engine* sobrevoando o Aeroporto Internacional LSIA com áudio nativo de turbinas e legendas sincronizadas.
  - **Economia & Inventário:** Dinheiro inicial padrão da cidade, smartphone garantido, RG (`id_card`) garantido, sem CNH, 40% chance de cigarros e isqueiro.
- **Saída da Prisão (`prison`):**
  - Sequência cinematográfica nos portões de metal de Bolingbroke Penitentiary com ônibus penitenciário (`pbus`), sirene distante e caminhada para a liberdade na Route 68 sob o sol do deserto.
  - **Economia & Inventário:** R$ 50 de auxílio-soltura do Estado, banco zerado, RG garantido, sem CNH, 5 cigarros e isqueiro.
- **Trem de Carga Clandestino (`train`):**
  - Chegada em vagão de carga no pátio ferroviário de Davis / South Los Santos, com buzina de trem (`TRAIN_HORN`), freios de aço e salto do vagão para os trilhos industriais.
  - **Economia & Inventário:** R$ 20 amarfanhados no bolso, banco zerado, garrafa de água, bandagem, 2 cigarros e sem documentos formais.
- **Já estava aqui (`none` / `default`):**
  - Sem cena inicial, libera o kit padrão nativo do servidor e abre diretamente a zona de desembarque (spawner).

## 🚒 Spawner Condicional por Profissão (`Config.Spawns`)

O seletor de spawn filtra as opções disponíveis na cidade conforme o emprego do personagem:
- **Polícia (`police`, `sheriff`, `state`):** Apenas *Última Localização* e *Departamento de Polícia*.
- **Paramédico / Médico (`ambulance`, `ems`, `doctor`):** Apenas *Última Localização* e *Hospital Central*.
- **Bombeiro (`firefighter`, `fire`):** Apenas *Última Localização* e *Corpo de Bombeiros*.
- **Civil / Demais Trabalhos:** Apenas *Última Localização* e *Centro da Cidade (Praça Central)*.

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
| `Config.UI.brandTitle` | `config.lua` | Nome/marca do servidor exibido no topo (default: 'Haze Studio') |
| `Config.UI.brandSubtitle` | `config.lua` | Subtítulo do topo (default: 'Seleção de Cidadão') |
| `Config.Spawns` | `config.lua` | Spawn locations in the sky picker |
| `Config.CharacterCreation` | `config.lua` | Name/DOB limits, apartment vs spawn-picker flow |
## Comandos Disponíveis

| Comando | Permissão | Descrição |
|---|---|---|
| `/relog` ou `/multichar` | Todos | Desconecta do personagem atual com segurança e reabre a tela de seleção |
| `/setslot <id> <slots>` | Admin | Define a quantidade máxima de slots de personagem de um jogador |
| `/w2fmc_diag` | Todos | Exibe diagnóstico de saúde e streaming do multicharacter no F8 |
| `/w2fmc_safemode` | Dev | Ativa perfil de modo de segurança para investigação de streaming |

## License

MIT
