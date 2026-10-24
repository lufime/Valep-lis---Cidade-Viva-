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

A última execução verificada, no commit `fdd81a643ba029d227b7ba254d4ea76020847f07`, passou todos estes gates. Isso confirma apenas os testes automatizados enumerados acima; não confirma a conclusão dos sistemas de jogo ainda ausentes.
