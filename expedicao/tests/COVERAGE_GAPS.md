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
- Criatura IA em protótipo: presença obrigatória na cena, controlador dedicado e transições testadas entre deteção/perseguição, estado de ataque e regresso à patrulha. O estado de ataque ainda não aplica dano nem efeitos de jogo.
- Teste de integração com três processos Godot separados (anfitrião e dois clientes simultâneos): ambos os clientes recebem o avatar e o estado do outro cliente; a suite também verifica PING/PONG, posição/orientação, spawn validado, portas, limites de movimento, teletransporte, percurso contra colisões e limpeza após desconexão.
- Verificação de que o projeto declara um ícone de aplicação existente e carregável.
- Preparação do modelo humanoide com clips CC0 e verificações de importação e seleção de animações idle/walk/locomoção rápida.
- Teste gráfico separado sob Xvfb para as transições de captura inicial do rato, ESC para libertar e clique esquerdo para recapturar; este teste usa eventos sintéticos, não um dispositivo físico.

## Testes que continuam ignorados ou exigem ambiente gráfico

- Captura/libertação real com rato físico: o teste gráfico valida os caminhos de código com eventos sintéticos sob Xvfb, mas não substitui a verificação manual de um rato num dispositivo real.
- Aspeto visual real, deformação do esqueleto e qualidade do crossfade: a suite headless confirma clips e transições lógicas, não a qualidade renderizada em ecrã.

## Lacunas explícitas — não contar como PASS

Esta base continua a ser um protótipo técnico, não um jogo completo. Os seguintes sistemas continuam ausentes ou incompletos:

- IA da criatura em estado de protótipo: faltam efeitos reais de ataque/dano, navegação avançada, animações próprias e replicação do estado da criatura entre clientes.
- Papel do traidor, comunicação secreta e objetivos privados.
- Sistema de missões e inventário.
- Instalação e arranque do APK Android num dispositivo físico. A exportação/assinatura de depuração passou no CI, mas isso não comprova a instalação real.
- Sincronização multijogador completa do mundo e das ações de jogo para além da posição/orientação dos avatares e do estado das portas.

Além disso, a posição do jogador remoto continua a ser submetida pelo cliente. O anfitrião agora valida a cadência, a distância e o percurso da cápsula contra a geometria física, e o teste ENet confirmou a rejeição de passos falsificados através de uma porta fechada. Ainda não existe simulação autoritativa do movimento com `CharacterBody3D`, aceleração, gravidade e estado de chão; esta validação não é proteção completa contra batota. O teste atual cobre dois clientes simultâneos, mas faltam testes sob latência/perda de pacotes, com mais clientes e de reconexão após uma desconexão. A limpeza está testada num percurso específico, não em todos os estados do jogo.

Estas lacunas exigem implementação e testes próprios antes de poderem receber qualquer estado PASS. Não se deve inferir que estão implementadas porque o PRE-FLIGHT atual fica verde.
