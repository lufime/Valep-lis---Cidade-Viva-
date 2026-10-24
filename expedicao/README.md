# A Última Expedição — nova base isolada

Esta pasta é uma reconstrução inicial e isolada do projeto. Não substitui nem apaga o projeto antigo. O trabalho desta base é feito exclusivamente na branch `rebuild/a-ultima-expedicao-zero`; não alterar `main`.

## Requisitos

- Godot Engine 4.5
- Projeto em `project.godot`

## O que existe nesta base

- Menu inicial com interface ENet para tentar criar uma sala ou ligar a um anfitrião por IP.
- Protótipo 3D de bloco cinzento com sala central e três zonas adjacentes: norte, este e sul.
- Jogador local em primeira pessoa, movimento por WASD e olhar pelo rato.
- Três portas com colisão física, interação por E e pivô colocado na extremidade para não bloquear a linha de passagem quando abertas.
- Testes automatizados para carregamento da cena, presença das zonas, deteção das portas, abertura/fecho, bloqueio quando fechadas e passagem física do corpo do jogador quando abertas.

Este é apenas um protótipo técnico. **Não é ainda uma versão jogável completa nem tem arte 3D realista.**

## Limitações conhecidas

- A interface ENet tenta estabelecer ligações e mostra contagem de ligações, mas não sincroniza ainda o cenário nem as ações de jogo entre jogadores.
- Não existem ainda modelos finais, animações, criatura, IA da criatura, sistema do traidor, objetivos secretos, inventário ou missões.
- A criatura deve estar presente em todas as partidas e ser controlada exclusivamente pela IA.
- O traidor deve ser um jogador humano distinto, informado em privado e com objetivos secretos.
- A introdução pública não pode revelar a identidade do traidor nem a natureza da criatura.
- Para jogar através da Internet, é necessário um anfitrião acessível e configuração de rede. Esta base não fornece relay, matchmaking ou servidor dedicado.
- A permissão de Internet e as predefinições de exportação Android ainda precisam de ser verificadas antes de produzir um APK.

## PRE-FLIGHT

O workflow `.github/workflows/expedicao-preflight.yml` executa Godot 4.5 em modo headless para:
1. importar e analisar o projeto;
2. verificar o arranque do projeto;
3. carregar diretamente a cena 3D;
4. executar os testes funcionais de portas e passagens.

Última execução verde verificada antes das alterações atuais: [40110891741](https://github.com/lufime/Valep-lis---Cidade-Viva-/actions/runs/40110891741), no commit `ce94254b990c3fa7f44c6d2fce30a79964c49587` (138 PASS, 0 FAIL, 2 SKIP). As alterações posteriores ainda precisam de uma nova execução verde. Este resultado confirma apenas os testes automatizados enumerados acima; não confirma a conclusão dos sistemas de jogo ainda ausentes.
