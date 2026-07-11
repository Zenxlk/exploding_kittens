# Reglas del juego implementadas

Referencia de las reglas oficiales de *Exploding Kittens* (edición base)
y su estado de implementación en este proyecto.

> Las reglas completas del juego original están en el manual oficial de
> [explodingkittens.com](https://www.explodingkittens.com).

---

## Configuración inicial

| Regla | Implementada | Archivo |
|-------|-------------|---------|
| 2–5 jugadores | ✅ | `GameConstants`, `DeckBuilder` |
| Cada jugador recibe 7 cartas + 1 Defuse | ✅ | `DeckBuilder.build()` |
| Se insertan N-1 Exploding Kittens en el mazo | ✅ | `DeckBuilder.build()` |
| Los Defuse extra van al mazo barajado | ✅ | `DeckBuilder.build()` |
| El mazo se baraja antes de repartir | ✅ | `DeckBuilder` (Fisher-Yates) |

---

## Turno normal

| Regla | Implementada | Archivo |
|-------|-------------|---------|
| Jugar 0 o más cartas, luego robar | ✅ | `TurnModel`, `TurnPhase` |
| Robar siempre termina el turno | ✅ | `ActionProcessor._processDrawCard` |
| Rotación de turno en sentido horario | ✅ | `TurnRules.nextPlayerId` |

---

## Cartas

### Exploding Kitten
| Regla | Implementada |
|-------|-------------|
| Al robarla sin Defuse → eliminado | ✅ |
| Al robarla con Defuse → usar Defuse obligatoriamente | ✅ |
| No se puede jugar desde la mano | ✅ (`isPlayable = false`) |

### Defuse
| Regla | Implementada |
|-------|-------------|
| Cancela la explosión | ✅ |
| El jugador reinserta la bomba en cualquier posición del mazo | ✅ |
| No se puede jugar proactivamente | ✅ (`isPlayable = false`) |

### Nope
| Regla | Implementada |
|-------|-------------|
| Cancela cualquier carta excepto Exploding Kitten y Defuse | ✅ |
| Cualquier jugador puede jugar Nope durante la ventana de tiempo | ✅ |
| Nope-a-Nope reactiva la acción (cadena impar/par) | ✅ |
| Se puede encadenar indefinidamente | ✅ |
| Ventana de tiempo configurable (`GameConstants.nopeWindowMs`) | ✅ |

### Attack
| Regla | Implementada |
|-------|-------------|
| Termina el turno sin robar | ✅ |
| El siguiente jugador debe jugar 2 turnos | ✅ (`actionsLeft = 2`) |
| Si el atacado también juega Attack, el siguiente juega 4 turnos | ✅ (chain acumulativo) |

### Skip
| Regla | Implementada |
|-------|-------------|
| Termina el turno sin robar | ✅ |
| Si tienes 2 turnos por Attack, Skip solo cancela uno | ✅ |

### Favor
| Regla | Implementada |
|-------|-------------|
| Elige un jugador → ese jugador te da una carta (él elige cuál) | ✅ |
| Requiere objetivo vivo distinto del jugador activo | ✅ |
| Si el objetivo no tiene cartas, no ocurre nada | ✅ |

### Shuffle
| Regla | Implementada |
|-------|-------------|
| Baraja el mazo de robo | ✅ |
| El orden del mazo se destruye (incluida la bomba) | ✅ |

### See the Future
| Regla | Implementada |
|-------|-------------|
| Mira las 3 cartas de arriba del mazo (privado) | ✅ |
| No cambia el orden del mazo | ✅ |
| El jugador activo es el único que ve las cartas | ✅ `GameState.seeTheFutureCards` sigue viajando compartido en la red (no hay canal privado por jugador todavía), pero `GameTableView` ahora solo muestra el overlay si es el turno del jugador local — cerrado el hallazgo de Fase 5 en `docs/VERIFICATION_LOG.md` |

### Cartas Gato (Tacocat, Rainbow Ralphing Cat, Bearded Dragon, Cattermelon, Hairy Potato Cat)
| Regla | Implementada |
|-------|-------------|
| Sin efecto jugadas solas | ✅ (`isCatCard` sin handler específico) |
| Par del mismo tipo → robar carta aleatoria de otro jugador | ✅ |
| Trío del mismo tipo → ver la mano del objetivo y elegir | ⚠️ Motor completo (`PlayCatTrioAction`), pero sin UI que lo dispare — elegir una carta concreta de la mano rival necesita su propio diseño (el actor no puede ver esa mano). No disponible para el jugador todavía |
| Par/trío se pueden nopear | ✅ |

---

## Eliminación y victoria

| Regla | Implementada |
|-------|-------------|
| Jugador eliminado descarta toda su mano | ✅ (`PlayerStatus.eliminated`) |
| Último jugador vivo gana | ✅ (`WinCondition.check`) |
| `GameResult` registra orden de eliminación y total de turnos | ✅ |

---

## Reglas pendientes de implementar

> Fases 1 a 5 están completas (ver `ROADMAP.md`); lo que queda pendiente de
> reglas es exclusivamente Fase 6 (expansiones) más el trío de gatos,
> señalado arriba con ⚠️.

| Regla | Fase | Notas |
|-------|------|-------|
| Ver 5 cartas (See the Future de Imploding Kittens) | Fase 6 (expansión) | |
| Barking Kittens (cooperativo 2 jugadores) | Fase 6 (expansión) | |
| Imploding Kitten (6 jugadores) | Fase 6 (expansión) | |
| Streaking Kittens | Fase 6 (expansión) | |

---

## Diferencias con el juego físico

| Aspecto | Juego físico | Esta implementación |
|---------|-------------|---------------------|
| Favor — quién elige la carta | El objetivo elige | El objetivo elige, vía `FavorTargetOverlay` |
| Ver el futuro — privacidad | El jugador lo ve en secreto | Filtrado por turno en el cliente; el dato en sí sigue viajando compartido en `GameState` (sin canal privado por jugador todavía) |
| Inserción de bomba | El jugador físicamente la mete | El jugador elige posición en `InsertBombOverlay` |
| Reconocimiento de cartas | Visual directo | Requiere trust en modo red (sin verificación criptográfica en MVP) |
