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
- Replicação técnica de posições/orientações e estado das portas, com validação limitada de cadência/distância, spawn inicial imposto pelo anfitrião e testes ENet entre processos separados.
- Limpeza do avatar e do estado transitório quando um jogador se desconecta.
- Teste gráfico separado com eventos sintéticos para captura inicial do rato, ESC para libertar e clique esquerdo para recapturar.

Este é apenas um protótipo técnico. **Não é ainda uma versão jogável completa nem tem arte 3D final/realista.**

## Limitações e riscos conhecidos

- A rede é apenas uma base técnica: não existe sincronização completa de todas as ações, sistemas e estado do mundo, nem relay, matchmaking ou servidor dedicado.
- **Autoridade/segurança ainda incompleta:** o anfitrião ignora a posição inicial declarada pelo cliente e rejeita pacotes de movimento demasiado próximos ou com deslocação excessiva, mas continua a receber posições calculadas pelo cliente. Ainda não simula o movimento com `CharacterBody3D`, colisões e gravidade no servidor; um cliente modificado pode tentar atravessar paredes em pequenos passos. A mitigação não equivale a movimento plenamente autoritativo nem a proteção completa contra batota.
- Não existem ainda a criatura de jogo, IA da criatura, sistema do traidor, objetivos secretos, inventário ou missões funcionais.
- A criatura deve estar presente em todas as partidas e ser controlada exclusivamente pela IA.
- O traidor deve ser um jogador humano distinto, informado em privado e com objetivos secretos.
- A introdução pública não pode revelar a identidade do traidor nem a natureza da criatura.
- A permissão de Internet e as predefinições de exportação Android ainda precisam de ser verificadas antes de produzir e validar um APK.
- O teste de rato físico real permanece omitido no CI porque o runner não dispõe de um dispositivo físico. O teste gráfico usa eventos sintéticos e não substitui o ensaio num computador/dispositivo real.

## PRE-FLIGHT

O workflow `.github/workflows/expedicao-preflight.yml` executa Godot 4.5 e verifica importação/análise, arranque, cenas, portas e passagens, movimento, animações e testes ENet locais.

Consultar a execução mais recente de [GitHub Actions nesta branch](https://github.com/lufime/Valep-lis---Cidade-Viva-/actions/workflows/expedicao-preflight.yml?query=branch%3Arebuild%2Fa-ultima-expedicao-zero) e confirmar que o SHA testado corresponde ao HEAD. Cada contagem PASS/FAIL/SKIP só é válida para o commit e os logs dessa execução; uma alteração posterior exige uma nova execução verde.

O PRE-FLIGHT confirma apenas os testes efetivamente executados. Não confirma que os sistemas de jogo em falta estejam implementados, que a rede esteja segura contra clientes maliciosos, nem que o APK Android esteja pronto.
