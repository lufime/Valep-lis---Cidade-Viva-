# A Última Expedição — nova base isolada

Esta pasta é uma reconstrução inicial e isolada do projeto. Não substitui nem apaga o projeto antigo. O trabalho desta base é feito exclusivamente na branch `rebuild/a-ultima-expedicao-zero`; não alterar `main`.

## Requisitos

- Godot Engine 4.5
- Projeto em `project.godot`

## O que existe nesta base

- Menu inicial com opções para iniciar a expedição, criar uma sala ENet local, ligar a um anfitrião por IP e desligar.
- Protótipo 3D com sala central e três zonas adjacentes: norte, este e sul.
- Jogador local em primeira pessoa, movimento por WASD e olhar pelo rato.
- Três portas com colisão física, interação por E e passagem física testada quando abertas.
- Modelo humanoide GLB com esqueleto e clips de repouso, caminhada e corrida para representações remotas.
- Replicação técnica de posições/orientações e estado das portas, com teste ENet local de ligação e desconexão.
- Limpeza do avatar e do estado transitório quando um jogador se desconecta.
- Teste gráfico separado com eventos sintéticos para captura inicial do rato, ESC para libertar e clique esquerdo para recapturar.

Este é apenas um protótipo técnico. **Não é ainda uma versão jogável completa nem tem arte 3D final/realista.**

## Limitações e riscos conhecidos

- A rede é apenas uma base técnica: não existe sincronização completa de todas as ações, sistemas e estado do mundo, nem relay, matchmaking ou servidor dedicado.
- **Risco de autoridade/segurança por resolver:** o servidor recebe posição e orientação declaradas pelo cliente e usa a posição guardada para validar a proximidade de uma porta. Um cliente modificado pode tentar falsificar a sua posição; a validação de portas não deve ser considerada segura contra batota até existir movimento autoritativo no servidor e um teste específico contra falsificação.
- Não existem ainda a criatura de jogo, IA da criatura, sistema do traidor, objetivos secretos, inventário ou missões funcionais.
- A criatura deve estar presente em todas as partidas e ser controlada exclusivamente pela IA.
- O traidor deve ser um jogador humano distinto, informado em privado e com objetivos secretos.
- A introdução pública não pode revelar a identidade do traidor nem a natureza da criatura.
- A permissão de Internet e as predefinições de exportação Android ainda precisam de ser verificadas antes de produzir e validar um APK.
- O teste de rato físico real permanece omitido no CI porque o runner não dispõe de um dispositivo físico. O teste gráfico usa eventos sintéticos e não substitui o ensaio num computador/dispositivo real.

## PRE-FLIGHT

O workflow `.github/workflows/expedicao-preflight.yml` executa Godot 4.5 e verifica importação/análise, arranque, cenas, portas e passagens, movimento, animações e testes ENet locais.

Última execução verde verificada: [40113312370](https://github.com/lufime/Valep-lis---Cidade-Viva-/actions/runs/40113312370), no commit `18be1d3e80c4de367fd2820aadff6e04bc51410f`: **144 PASS, 0 FAIL, 1 SKIP**, repetido em três rondas de estabilidade. O teste gráfico separado confirmou `GUI_INPUT_PASS=3 GUI_INPUT_FAIL=0 RESULTADO=PASS`.

Este resultado confirma apenas os testes automatizados efetivamente executados. Não confirma que os sistemas de jogo em falta estejam implementados, que a rede esteja segura contra clientes maliciosos, nem que o APK Android esteja pronto.
