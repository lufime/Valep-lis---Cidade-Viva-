# PRE-FLIGHT — cobertura e lacunas conhecidas

Este documento descreve apenas a base isolada `expedicao/` e não declara o jogo completo como concluído. A execução do workflow e os seus logs são a fonte de verdade para qualquer resultado PASS/FAIL.

## Cobertura automatizada implementada

- Importação/análise do projeto Godot 4.5 e arranque headless.
- Carregamento direto da cena 3D e do menu.
- Botão de início e transição para a cena de expedição.
- Criação do jogador, câmara, movimento WASD, colisões e rotação matemática da vista.
- Passagem física de ida e volta pelas três portas (norte, este e sul), apoio do chão nos corredores e bloqueio das paredes.
- Criação e desligação de uma sala ENet local.
- Validação física no anfitrião por varrimento da cápsula do jogador, incluindo movimento ao nível do chão, rejeição de paredes e teste de passagem com as portas norte, este e sul fechadas/abertas.
- Teste de integração com processos Godot separados: ligação, PING/PONG, posição e orientação do anfitrião replicadas para o cliente, imposição do spawn perante posição inicial falsificada, rejeição de posição falsificada usada para tentar abrir uma porta, posição do cliente recebida pelo anfitrião, criação do avatar remoto, rejeição de pedido de porta por cliente distante, abertura/fecho de porta, rejeição de atualizações de movimento demasiado próximas, teletransporte, tentativa de atravessar a porta este fechada através de passos pequenos falsificados e desconexão real do cliente com confirmação da remoção do avatar/estado no anfitrião.
- Preparação do modelo humanoide com clips CC0 e verificações de importação e seleção de animações idle/walk/locomoção rápida.
- Teste gráfico separado sob Xvfb para as transições de captura inicial do rato, ESC para libertar e clique esquerdo para recapturar; este teste usa eventos sintéticos, não um dispositivo físico.

## Testes que continuam ignorados ou exigem ambiente gráfico

- Captura/libertação real com rato físico: o teste gráfico valida os caminhos de código com eventos sintéticos sob Xvfb, mas não substitui a verificação manual de um rato num dispositivo real.
- Aspeto visual real, deformação do esqueleto e qualidade do crossfade: a suite headless confirma clips e transições lógicas, não a qualidade renderizada em ecrã.

## Lacunas explícitas — não contar como PASS

A árvore atual desta base isolada contém apenas o menu, o cenário de teste, o jogador e os testes auxiliares. Não existe nesta base uma implementação testável dos seguintes sistemas:

- IA da criatura e comportamento de perseguição/ataque.
- Papel do traidor, comunicação secreta e objetivos privados.
- Sistema de missões e inventário.
- Exportação/assinatura Android e instalação num dispositivo real.
- Sincronização multijogador completa do mundo e das ações de jogo para além da posição/orientação dos avatares e do estado das portas.

Além disso, a posição do jogador remoto continua a ser submetida pelo cliente. O anfitrião agora valida a cadência, a distância e o percurso da cápsula contra a geometria física, e o teste ENet confirmou a rejeição de passos falsificados através de uma porta fechada. Ainda não existe simulação autoritativa do movimento com `CharacterBody3D`, aceleração, gravidade e estado de chão; esta validação não é proteção completa contra batota. Faltam testes de integração sob latência/perda de pacotes, com vários clientes simultâneos e de reconexão após uma desconexão. O teste atual confirma a limpeza depois de o cliente concluir a sequência de interação; não valida reconexão nem desconexão em todos os estados do jogo.

Estas lacunas exigem implementação e testes próprios antes de poderem receber qualquer estado PASS. Não se deve inferir que estão implementadas porque o PRE-FLIGHT atual fica verde.
