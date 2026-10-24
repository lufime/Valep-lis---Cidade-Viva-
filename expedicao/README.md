# A Última Expedição — nova base

Esta pasta é uma reconstrução isolada e inicial do projeto. Não substitui nem apaga o projeto antigo.

## Requisitos

- Godot Engine 4.5
- Projeto em `project.godot`

## Estado inicial

Inclui uma cena inicial e um protótipo de interface para criar uma sala ENet ou tentar entrar numa sala por endereço IP. Isto **não** representa ainda o multijogador completo nem uma versão jogável.

## Limitações conhecidas

- ENet usa UDP. Para jogadores em redes diferentes é necessário alojamento acessível e configuração de rede; este protótipo não fornece relay, matchmaking ou servidor dedicado.
- Ainda não existem mapa 3D, personagens finais, portas, criatura, IA de criatura, sistema do traidor, objetivos secretos, inventário, missões ou sincronização de ações de jogo.
- A permissão de Internet e as predefinições de exportação Android serão configuradas antes de produzir um APK.
- Nenhum teste é considerado aprovado até ser executado pelo workflow.

## Regras preservadas para a implementação

- O multijogador tem de permitir interação real entre jogadores.
- A criatura está presente em todas as partidas e é controlada exclusivamente pela IA.
- O traidor é um jogador humano distinto e recebe objetivos secretos.
- A introdução pública não revela a identidade do traidor nem a natureza da criatura.

## Validação da cena 3D

O PRE-FLIGHT testa o arranque do projeto e tenta abrir diretamente `res://scenes/expedition_3d.tscn` em modo headless. O resultado deste teste deve ser consultado no GitHub Actions antes de declarar a cena validada.
