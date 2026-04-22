# Changelog

## v1.0.0-beta.1

### Adicionado

- Compatibilidade do entrypoint `career_careerMP` com a carreira sobrescrita do RLS.
- Reintroducao do modulo `propCargo.lua` no RLS `2.6.5.1`.
- Novo fluxo de cards de `prop cargo` no `cargoScreen.lua`.
- Filtro `propCargo` no `cargoCards.lua`.
- Script `build_release.py` para gerar os zips finais a partir dos mods originais.

### Alterado

- `extensionManager.lua` para nao desativar o `multiplayerbeammp`.
- `careerMPEnabler.lua` para responder tambem a `onComputerMenuOpened`.
- `computer.lua` para limpar o tether ao trocar de submenu e ao fechar o menu.
- `mod_info/RLSCO24/info.json` para identificar a variante compatível.

### Corrigido

- RLS carregando apenas no `career_career` e ignorando o `career_careerMP`.
- Falta do sistema de `prop cargo` no porte para `2.6.5.1`.
- `CareerMP.zip` empacotado de forma incorreta, impedindo o `modScript.lua` de carregar.
- Conflito entre hooks do menu do computador do RLS e o `CareerMP`.

### Pendente de validacao final

- Fluxo completo de `tuning` / `painting` / `part shopping` em sessao online apos o ajuste do tether do computador.
