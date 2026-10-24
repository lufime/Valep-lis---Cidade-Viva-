# PRE-FLIGHT — cobertura e lacunas conhecidas

Este documento descreve apenas a base isolada `expedicao/` e não declara o jogo completo como concluído. A execução do workflow e os seus logs são a fonte de verdade para qualquer resultado PASS/FAIL.

## Cobertura automatizada implementada

- Importação/análise do projeto Godot 4.5 e arranque headless.
- Carregamento direto da cena 3D e do menu.
- Botão de início e transição para a cena de expedição.
- Criação do jogador, câmara, movimento WASD, colisões e rotação matemática da vista.
- Passagem física de ida e volta pelas três portas (norte, este e sul), apoio do chão nos corredores e bloqueio das paredes.
- Criação e desligação de uma sala ENet local.
- Teste de integração com processos Godot separados: ligação, PING/PONG, posição e orientação do anfitrião replicadas para o cliente, posição do cliente recebida pelo anfitrião, criação do avatar remoto, rejeição de pedido de porta por cliente distante, pedido válido de abertura e fecho, e confirmação dos dois estados nos processos anfitrião e cliente.
- Preparação do modelo humanoide com clips CC0 e verificações de importação e seleção de animações idle/walk/locomoção rápida.

## Testes que continuam ignorados ou exigem ambiente gráfico

- Captura/libertação real do rato, ESC e clique esquerdo: o runner headless não valida o comportamento de dispositivo/estado gráfico.
- Aspeto visual real, deformação do esqueleto e qualidade do crossfade: a suite headless confirma clips e transições lógicas, não a qualidade renderizada em ecrã.

## Lacunas explícitas — não contar como PASS

A árvore atual desta base isolada contém apenas o menu, o cenário de teste, o jogador e os testes auxiliares. Não existe nesta base uma implementação testável dos seguintes sistemas:

- IA da criatura e comportamento de perseguição/ataque.
- Papel do traidor, comunicação secreta e objetivos privados.
- Sistema de missões e inventário.
- Exportação/assinatura Android e instalação num dispositivo real.
- Sincronização multijogador completa do mundo e das ações de jogo para além da posição/orientação dos avatares e do estado das portas.

Estas lacunas exigem implementação e testes próprios antes de poderem receber qualquer estado PASS. Não se deve inferir que estão implementadas porque o PRE-FLIGHT atual fica verde.
