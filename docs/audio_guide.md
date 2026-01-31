# Guia de Audio - Cult of the Mask

Este documento descreve todos os arquivos de audio necessarios para o jogo e como obte-los.

## Estrutura de Pastas

```
audio/
├── bgm/           # Background Music
├── sfx/           # Sound Effects
└── ambient/       # Sons ambientes
```

## Formatos Suportados

- **OGG Vorbis** (.ogg) - Recomendado para musica (menor tamanho, boa qualidade)
- **WAV** (.wav) - Bom para SFX curtos
- **MP3** (.mp3) - Suportado, mas OGG e preferido

---

## Background Music (BGM)

### Arquivos Necessarios

| Arquivo | Contexto | Estilo | Duracao Sugerida |
|---------|----------|--------|------------------|
| `menu_ambient.ogg` | Menu Principal | Dark Ambient - drones baixos, orgao distante | 2-4 min (loop) |
| `intro_ceremonial.ogg` | Cutscene Intro | Coral Religioso Sombrio - orgao, coro sussurrado | 1-2 min |
| `phase_early_power.ogg` | Fases 2-3 | Ambient com pulso ritmico - cordas tensas, percussao tribal | 2-3 min (loop) |
| `phase_mid_transition.ogg` | Fase 4 | Transicao - mais tenso, dissonancia crescente | 2 min (loop) |
| `phase_late_isolation.ogg` | Fases 5-6 | Minimalista/Drone - vazio, solidao | 2-3 min (loop) |
| `sinner_melancholy.ogg` | Dialogo Mascarado | Melancolico - cordas tristes, humaniza vitimas | 1-2 min |
| `victory_empty.ogg` | Tela Vitoria | Ambiguo - nao celebrativo, sensacao de vazio | 1 min |
| `gameover_relief.ogg` | Game Over | Alivio perturbador - escapou de se tornar assassino | 30s-1 min |

### Caracteristicas por Fase

**Menu/Intro (Religioso Sombrio)**
- Instrumentos: Orgao de igreja, coro sussurrado, sinos
- Sensacao: Solene, opressivo, grandioso mas perturbador
- Referencias: Outlast 2, Bloodborne (temas de capela)

**Fases 2-3 (Euforia/Poder)**
- Instrumentos: Cordas tensas, percussao tribal distante, sintetizadores
- Sensacao: Energia crescente, poder, com dissonancia sutil
- O jogador ainda se sente no controle

**Fase 4 (Transicao)**
- Instrumentos: Mix de fases anteriores + elementos perturbadores
- Sensacao: Algo esta errado, desconforto crescente

**Fases 5-6 (Deterioracao/Isolamento)**
- Instrumentos: Cordas solo, ruidos industriais, muito silencio
- Sensacao: Vazio, solidao, desconforto
- Tecnica: Usar mais silencio que musica

---

## Sound Effects (SFX)

### UI

| Arquivo | Uso | Descricao |
|---------|-----|-----------|
| `ui_click.ogg` | Clique em botoes | Click suave, sutil |
| `ui_hover.ogg` | Mouse sobre elementos | Som muito sutil |
| `ui_back.ogg` | Voltar/Cancelar | Levemente diferente do click |

### Gameplay

| Arquivo | Uso | Descricao |
|---------|-----|-----------|
| `npc_select.ogg` | Selecionar NPC | Som de selecao - sutil mas audivel |
| `kill_visceral.ogg` | Eliminar alvo | Som "molhado"/visceral - impactante |
| `kill_innocent.ogg` | Matar inocente | Dissonancia - sensacao de erro terrivel |
| `item_collect.ogg` | Coletar item | Som de papel/tecido |
| `item_special.ogg` | Itens especiais | Metalico (monoculo, relogio) |

### Feedback/Tensao

| Arquivo | Uso | Descricao |
|---------|-----|-----------|
| `timer_tick.ogg` | Timer passando | Tick-tock sutil |
| `timer_warning.ogg` | Tempo baixo | Tick mais intenso/distorcido |
| `heartbeat.ogg` | Pressao (timer < 4s) | Batida cardiaca - aumenta tensao |
| `phase_complete.ogg` | Fase finalizada | Sino grave - transicao |

### Psicologicos (Fases Tardias)

| Arquivo | Uso | Descricao |
|---------|-----|-----------|
| `whisper.ogg` | Fases 5-6 | Sussurros incompreensiveis |
| `cry_distant.ogg` | Fases 5-6 | Choro distante |
| `laugh_muffled.ogg` | Alucinacao | Risadas abafadas |
| `footstep_echo.ogg` | Solidao | Eco de passos - voce esta sozinho |

---

## Sons Ambiente

| Arquivo | Uso | Descricao |
|---------|-----|-----------|
| `crowd_murmur.ogg` | Multidao | Murmurios de pessoas |
| `wind.ogg` | Transicoes | Vento - sensacao de solidao |
| `church_bells.ogg` | Intro/Transicoes | Sinos de igreja distantes |

---

## Onde Obter Audio

### Gratuitos

1. **Freesound.org** - SFX variados
   - Buscar: "horror ambient", "church bell", "heartbeat", "whisper"
   - Licencas: CC0 ou CC-BY

2. **OpenGameArt.org** - Musica e SFX para jogos
   - Categoria: Horror, Dark Ambient
   - Licencas: Geralmente permissivas

3. **itch.io** - Packs de audio
   - Buscar: "horror sound effects", "dark ambient music"
   - Muitos packs gratuitos ou pay-what-you-want

### Pagos/Profissionais

1. **Splice** - Samples e loops de alta qualidade
2. **Artlist** - Musica licenciada para jogos
3. **Epidemic Sound** - Trilhas e SFX

### Criacao Propria

Para criar audio proprio, considere:
- **Audacity** (gratuito) - Edicao de audio
- **LMMS** (gratuito) - Producao musical
- **FL Studio** / **Ableton** - DAWs profissionais

---

## Tecnicas de Sound Design

### 1. Silencio Estrategico
O silencio e tao importante quanto a musica. Nas fases tardias, use mais silencio que som.

### 2. Leitmotifs
Temas recorrentes que criam associacoes:
- **Tema do Culto**: Orgao, coral - menu/intro
- **Tema do Poder**: Cordas ascendentes - fases iniciais
- **Tema do Mascarado**: Melancolico - dialogo com alvos
- **Tema da Solidao**: Minimalista - fases tardias

### 3. Evolucao Sonora
A trilha deve evoluir com a narrativa:
1. Religiosa/Solene (intro)
2. Poderosa/Energica (fases 2-3)
3. Perturbadora (fase 4)
4. Vazia/Isolada (fases 5-6)
5. Silencio ou Caos (final)

---

## Configuracao no AudioManager

O AudioManager (`audio_manager.gd`) ja esta configurado para:
- Crossfade automatico entre BGMs
- Pool de SFX players (evita cortes)
- Heartbeat automatico quando timer baixo
- Sussurros aleatorios nas fases tardias
- Controle de volume por categoria

### Buses de Audio

O projeto usa 3 buses de audio:
- **Master** - Volume geral
- **Music** - Background music
- **SFX** - Sound effects
- **Ambient** - Sons ambientes

Configurados em `default_bus_layout.tres`.

---

## Referencias de Jogos

Para inspiracao, estude as trilhas de:
- **Outlast 2** - Horror psicologico religioso
- **Darkwood** - Uso magistral de silencio
- **Silent Hill 2** - Musica como personagem
- **Cry of Fear** - Dark ambient
- **CULTIC** - Tematica de culto
