# RLS CareerMP Compatibility Patch

Patch de compatibilidade para rodar o `RLS Career Overhaul 2.6.5.1` junto com `CareerMP` no BeamNG.drive.

Este repositório **nao redistribui o mod completo do RLS**. Ele inclui apenas os arquivos alterados por cima dos mods originais, mais um script para gerar os zips finais de uso no servidor e no cliente.

## Objetivo

Adaptar o RLS `2.6.5.1` para o fluxo de carreira online com `BeamMP + CareerMP`, preservando os recursos do overhaul e removendo os pontos que quebravam o multiplayer.

## Base usada

- `rls_career_overhaul_2.6.5.1.zip`
- `CareerMP.zip`
- `CareerMPBanking.zip`
- BeamNG.drive `0.38.5`
- BeamMP `3.9.x`

## O que este patch faz

- Mantem o `BeamMP` ativo quando o RLS inicializa.
- Restaura o sistema de `prop cargo` no RLS `2.6.5.1`.
- Faz o entrypoint `career_careerMP` reutilizar a carreira sobrescrita pelo RLS.
- Adiciona compatibilidade entre o menu do computador do RLS e os hooks usados pelo `CareerMP`.
- Corrige o empacotamento do `CareerMP.zip` para garantir que o `modScript.lua` carregue corretamente no BeamNG.
- Inclui um ajuste preventivo no `computer.lua` para evitar que o tether do computador feche telas de tuning/painting/part shopping ao trocar para o carro.

## Arquivos alterados

### RLS

- `lua/ge/extensions/overhaul/extensionManager.lua`
- `lua/ge/extensions/career/modules/delivery/propCargo.lua`
- `lua/ge/extensions/overrides/career/careerMP.lua`
- `lua/ge/extensions/overrides/career/modules/computer.lua`
- `lua/ge/extensions/overrides/career/modules/delivery/cargoCards.lua`
- `lua/ge/extensions/overrides/career/modules/delivery/cargoScreen.lua`
- `mod_info/RLSCO24/info.json`

### CareerMP

- `lua/ge/extensions/careerMPEnabler.lua`

## Como gerar os zips finais

1. Tenha os zips originais do `RLS` e do `CareerMP`.
2. Rode:

```bash
python scripts/build_release.py --rls-original "C:\\caminho\\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\\caminho\\CareerMP.zip" --out-dir ".\\built"
```

3. O script vai gerar:

- `built/rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- `built/CareerMP.zip`
- `built/checksums.txt`

## Como usar no servidor

Distribua estes mods:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

Nao distribua ao mesmo tempo:

- `RLS_2.6.4_MPv3.8.zip`
- `rls_career_overhaul_2.6.5.1.zip`

## Observacoes

- Este patch foi montado para o fluxo de carreira online, nao para single-player puro.
- O ajuste de oficina/computador foi incluído no patch, mas vale validar em jogo antes de chamar de definitivo em uma release estavel.
- Como o RLS original e um mod de terceiros, o formato de distribuicao recomendado e **patch + script de build**, nao o zip completo do mod.
