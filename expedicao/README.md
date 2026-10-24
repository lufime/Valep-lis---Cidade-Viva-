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
- Criatura controlada exclusivamente pela IA, em protótipo: patrulha, deteção por proximidade e estados de perseguição/ataque. O estado de ataque ainda não aplica dano nem efeitos de jogo.
- Modelo humanoide GLB com esqueleto e clips de repouso, caminhada e corrida para representações remotas.
- Replicação técnica de posições/orientações e estado das portas; o anfitrião impõe o spawn, limita cadência/distância e valida a trajetória com varrimento da cápsula física do jogador contra as colisões do mapa.
- Teste ENet com três processos reais (anfitrião e dois clientes simultâneos), verificando que ambos recebem avatares/estado remoto, além de portas, rejeição de movimento falsificado e limpeza após desconexão.
- Ícone vetorial da aplicação definido no projeto e verificado pela suite.
- Teste gráfico separado com eventos sintéticos para captura inicial do rato, ESC para libertar e clique esquerdo para recapturar.

Este é apenas um protótipo técnico. **Não é ainda uma versão jogável completa nem tem arte 3D final/realista.**

## Limitações e riscos conhecidos

- A rede é apenas uma base técnica: não existe sincronização completa de todas as ações, sistemas e estado do mundo, nem relay, matchmaking ou servidor dedicado.
- **Autoridade/segurança ainda incompleta:** o anfitrião ignora a posição inicial declarada pelo cliente, limita cadência/distância e verifica cada segmento recebido com um varrimento da cápsula contra paredes e portas. O teste ENet entre dois processos confirmou a rejeição de teletransporte e de passos falsificados através de uma porta fechada. Mesmo assim, o cliente continua a enviar posições; o servidor ainda não simula o movimento com `CharacterBody3D`, aceleração, gravidade e estado de chão. A validação atual é uma mitigação, não movimento plenamente autoritativo nem proteção completa contra batota; faltam ensaios sob latência/perda de pacotes e com vários clientes.
- A criatura está apenas em protótipo: ainda faltam dano/efeitos de ataque, navegação avançada, animações próprias e sincronização do estado da criatura entre clientes. O sistema do traidor, objetivos secretos, inventário e missões funcionais continuam ausentes.
- A criatura deve estar presente em todas as partidas e ser controlada exclusivamente pela IA.
- O traidor deve ser um jogador humano distinto, informado em privado e com objetivos secretos.
- A introdução pública não pode revelar a identidade do traidor nem a natureza da criatura.
- O CI já exporta, assina com chave de depuração e valida a estrutura do APK Android. A instalação e o arranque ainda não foram confirmados num dispositivo físico; o APK de depuração não é uma versão de distribuição.
- O teste de rato físico real permanece omitido no CI porque o runner não dispõe de um dispositivo físico. O teste gráfico usa eventos sintéticos e não substitui o ensaio num computador/dispositivo real.

## PRE-FLIGHT

O workflow `.github/workflows/expedicao-preflight.yml` executa Godot 4.5 e verifica importação/análise, arranque, cenas, portas e passagens, movimento, estados básicos da IA da criatura, animações e integração ENet com dois clientes simultâneos.

Consultar a execução mais recente de [GitHub Actions nesta branch](https://github.com/lufime/Valep-lis---Cidade-Viva-/actions/workflows/expedicao-preflight.yml?query=branch%3Arebuild%2Fa-ultima-expedicao-zero) e confirmar que o SHA testado corresponde ao HEAD. Cada contagem PASS/FAIL/SKIP só é válida para o commit e os logs dessa execução; uma alteração posterior exige uma nova execução verde.

O PRE-FLIGHT confirma apenas os testes efetivamente executados. Não confirma que os sistemas de jogo em falta estejam implementados, que a rede esteja segura contra clientes maliciosos, nem que o APK Android esteja pronto.
