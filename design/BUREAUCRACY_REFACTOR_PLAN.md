# Bureaucracy Deckbuilder Refactor Plan

This file is the session handoff for future chats.

## Repo choice

Use `Deck_Builder_Tutorial/deck_builder_tutorial` as the production base.

Do not migrate gameplay into `roguelike_deckbuilder`.

Why:
- `deck_builder_tutorial` already has the real game loop: map, battles, rewards, shop, relics, save/load, statuses, enemy flow.
- It already has the bureaucracy card pipeline: `design/cards_bureaucracy.json`, card gallery, ComfyUI generation, promotion into Godot assets, promoted card loading.
- `roguelike_deckbuilder` is useful as a reference for desktop-scale project settings and cleaner presentation direction, but not as the implementation base.

## Core findings

### 1. The source art was not the problem
Promoted card art was already high resolution.

Example:
- `art/promoted/card_icons/bureaucracy_audit.png` is 1216x824.

The in-game degradation came from the project render/stretch setup, not from low-resolution source files.

### 2. The main fidelity problem was project-wide pixel rendering
The old project settings were effectively treating the whole game like a pixel-art game:
- `window/size/viewport_width=256`
- `window/size/viewport_height=144`
- `window/stretch/mode="viewport"`
- nearest/default pixel texture filtering

That caused high-fidelity bureaucracy art to be rendered into a tiny framebuffer and then blown up.

### 3. The right fix is to modernize the current repo, not backtrack into another template
The best path is:
- keep the current repo as the runtime/gameplay base
- adopt desktop-friendly display/render behavior
- refactor presentation scene by scene
- keep battle logic and progression logic intact while visuals evolve

## Changes already landed

### Display and fidelity foundation
`project.godot`
- `window/stretch/mode` changed from `viewport` to `canvas_items`
- `window/stretch/aspect="keep"` added
- `textures/canvas_textures/default_texture_filter=1`

Effect:
- high-resolution card art now survives the trip to screen much better
- old tutorial art may look soft or inconsistent during the transition, which is acceptable

### Desktop layout baseline
`project.godot`
`scenes/run/run.tscn`
`scenes/map/map.gd`
`scenes/battle/battle.tscn`
- logical layout baseline moved to desktop scale (`1280x720`)
- top bar, map flow, battle board, and reward flow were re-authored for the larger space
- single-target drag/aim behavior was fixed after the layout move so battles still play correctly

### Full-card renderer groundwork
`scenes/ui/card_visuals_full.tscn`
`scenes/ui/card_visuals_full.gd`
- reusable full-card renderer based on `design/frame_bureaucracy.json`
- loads promoted art and bureaucracy metadata
- used by full-card preview / popup flows
- isolated from the legacy global pixel font theme

### Preview / tooltip groundwork
`scenes/dev/promoted_card_preview.tscn`
`scenes/dev/promoted_card_preview.gd`
`scenes/ui/card_tooltip_popup.gd`
- full-card preview exists for promoted cards
- tooltip popup uses the full-card renderer

### Runtime card metadata groundwork
`custom_resources/card.gd`
`custom_resources/card_pile.gd`
`global/promoted_cards.gd`
`scenes/event_rooms/helpful_boi_event.gd`
- added runtime instance fields like `instance_uid`, `upgrade_tier`, `reviewed_stacks`, `keywords`
- duplication paths now assign instance IDs

### Current browse behavior preference
Current desired behavior is:
- deck inspection / rewards / shop show compact small-card previews
- clicking a card opens the larger full-card view
- fidelity should remain high even in the compact preview, as much as current layouts allow

## Current status

What works now:
- promoted bureaucracy cards appear in rewards/shop/deck flow
- source art is rendering with much better fidelity than before
- compact browse previews remain the active interaction model for current scenes
- full-card popup / preview path exists
- the map, battle board, reward panel, and top bar now run on a desktop-sized authored layout
- single-target drag targeting still works after the desktop baseline change

What is still legacy:
- battle hand is still the old tutorial compact card system
- many scene assets are still temporary tutorial art in enlarged desktop slots
- the game is not yet fully re-authored as a modern desktop UI across every screen


## Overnight progress: first new mechanic

Implemented first-pass `Budget` support instead of `Archive`.

Reason:
- this codebase already has `exhausts`, which is close enough to the proposed Archive behavior for now
- `Budget` was the next-lowest-risk new mechanic to prove out

What landed on the mechanic branch:
- `custom_resources/run_stats.gd`
  - persistent run-level `budget`
  - `budget_changed` signal
  - spend/gain helpers
- `scenes/ui/budget_ui.tscn`
  - top-bar budget display using the existing coupon art
- `custom_resources/card.gd`
  - generic gameplay fields for `damage`, `block_amount`, `cards_to_draw`, `exposed_to_apply`, `budget_cost`, and `budget_gain`
  - default `apply_effects()` implementation for common simple cards
  - `can_play()` gate that respects both mana and budget
- `scenes/card_ui/card_ui.gd`
  - hand cards now refresh playability when budget changes

Scope note:
- this is a first-pass budget prototype only
- no deficit system yet
- no dual-mode budget toggle UI yet
- no dedicated budget cost iconography on the card face yet

New generated card batch:
- `Paper Cut` (control card using an existing simple attack effect)
- `Embezzlement` (gain budget)
- `Expense Account` (gain budget, draw)
- `Falsified Report` (spend budget to apply Exposed)
- `Hostile Takeover` (spend budget for a stronger all-enemies hit)


## Second mechanic progress: Chain of Approval

Implemented a first-pass `Chain of Approval` runtime.

What landed on the chain branch:
- `global/chain_tracker.gd`
  - battle-local chain progress tracker
  - supports same-turn or next-turn sequencing via a simple turn window
- `custom_resources/card.gd`
  - chain metadata fields (`chain_id`, `chain_step`, `chain_window_turns`)
  - generic chain bonus fields for damage, block, draw, and Exposed
- `project.godot`
  - `ChainTracker` autoload
- `scenes/battle/battle.gd`
  - resets chain state at battle start

Scope note:
- no chain-specific HUD feedback yet
- non-chain cards do not currently break the sequence
- this is a low-friction prototype meant to validate whether the sequencing feels good in actual play

New generated chain batch:
- `Stapler Jab` (control card)
- `Request Form` (Chain 1)
- `Approval Memo` (Chain 2)
- `Department Stamp` (Chain 3)
- `Final Authorization` (Chain 4)

## Recommended next steps

### Phase 1. Live-playtest the new Budget prototype
Goal:
- verify the first non-legacy bureaucracy mechanic in the real run loop

Checks:
- confirm budget persists across map nodes and battles in the same run
- confirm budget-gain cards update hand playability immediately
- confirm budget-cost cards stay disabled when unaffordable and become playable once budget is gained
- confirm rewards / shop can surface the new generated cards quickly enough for iteration

### Phase 2. Improve compact card previews without losing fidelity
Goal:
- small cards should feel like deliberate previews, not squeezed full posters

Options:
- tune the compact preview widget to crop/frame bureaucracy art better
- optionally create a dedicated bureaucracy compact-card preview scene that is not the old tutorial card shell
- keep click-to-expand full-card behavior

### Phase 3. Replace battle hand presentation
Goal:
- keep the gameplay logic, replace the hand presentation

Plan:
- introduce a new hand-card visual that is readable at desktop size
- likely use a medium-card presentation for hand cards instead of tiny tutorial cards
- keep targeting/dragging behavior intact while swapping visuals

### Phase 4. Expand data-driven promoted card runtime
Goal:
- promoted cards become genuinely playable content, not just visual entries

Plan:
- extend `cards_bureaucracy.json` with gameplay fields beyond the current first-pass fields
- add effect data / simple DSL for common effects
- keep script escape hatches for unusual cards

### Phase 5. Bureaucracy-specific systems
After Budget is validated, continue with:
- Backlog pile
- chain / approval mechanics
- photocopier / delayed copy behavior
- performance review / downgrade systems
- curse cards

## Implementation guidance

### Keep this rule
Do not rewrite the game into `roguelike_deckbuilder`.
Use it only as a reference for:
- desktop project settings
- cleaner baseline layout assumptions
- non-pixel presentation direction

### Treat legacy assets as disposable
It is acceptable if old tutorial art looks wrong during the transition.
The bureaucracy presentation direction matters more than preserving the tutorial art style.

### Prefer incremental playability
Each presentation refactor slice should leave the game runnable.

## Quick tests after future slices

### Fidelity check
- open deck view, reward, or shop
- compare a promoted bureaucracy card against its source artwork
- verify the source still looks materially similar in-game

### Compact preview check
- card previews remain small in deck/reward/shop
- clicking opens the larger full-card popup

### Regression check
- start a run
- complete a battle
- open rewards
- visit shop
- inspect deck
- confirm no crashes and promoted cards still appear

## Immediate next step for the next session

Playtest the new Budget batch in a real run.

Recommended targets:
- reward flow
- shop flow
- battle hand playability updates
- save/load persistence for budget

Goal of that slice:
- confirm the new mechanic works in the actual loop before adding a second new mechanic
- use the five overnight generated cards as the first real bureaucracy gameplay batch

## Workspace note

For future sessions, open the repo root directly at:
- `C:\Users\Lucas\Godot\Deck_Builder_Tutorial`

The repo was flattened, so this top-level folder is now the actual git root.
## Third mechanic progress: Backlog

Implemented a first-pass `Backlog` system based directly on `GAMEPLAY_MECHANICS.md`.

What landed on the backlog branch:
- `custom_resources/character_stats.gd`
  - added persistent `backlog: CardPile`
  - runtime pile initialization helper so old saves / old resources do not crash
- `custom_resources/card.gd`
  - added `file_to_backlog`
  - added `draw_from_backlog`
  - backlog draws now work as a generic card effect
- `scenes/player/player_handler.gd`
  - Backlog persists across battles
  - added the 3-mana battle action to draw the top hidden backlog card
  - cards tagged with `file_to_backlog` now go to Backlog instead of discard
  - added helper to inject a temporary nuisance card into Backlog
- `scenes/ui/battle_ui.gd`
  - added a dedicated Backlog battle button with count + 3-mana action text
- `scenes/battle/battle.tscn`
  - added the new Backlog action button to the battle HUD

Enemy-side backlog pressure:
- `common_cards/debuffs/bureaucracy_misfiled_notice.tres`
  - temporary nuisance card used to dirty the Backlog
- `enemies/common/bury_in_paperwork_action.gd`
  - shared enemy action that adds `Misfiled Notice` to the player's Backlog
- `enemies/crab/crab_enemy_ai.tscn`
- `enemies/bat/bat_enemy_ai.tscn`
  - both now have a light chance to use the new paperwork action

Scope note:
- Backlog contents remain hidden in battle
- there is currently no dedicated Backlog inspection view, by design
- the dedicated battle action costs 3 mana, matching the design doc
- Backlog draw via cards does not cost extra mana beyond the card itself

Generated backlog batch:
- `Case File`
- `Paper Trail`
- `Hold for Review`
- `Priority Retrieval`
- `Emergency Escalation`

## Gallery control progress: unpromote

Implemented an `Unpromote` flow in the local gallery so promoted cards can be removed from the Godot reward pool without manual file cleanup.

What landed:
- `tools/card_gallery/server.py`
  - added `/api/unpromote`
  - removes the promoted `.tres` and icon file
  - clears promote metadata from `design/cards_bureaucracy.json`
  - promotion now serializes newer gameplay fields like budget/backlog values instead of dropping them
- `tools/card_gallery/web/index.html`
- `tools/card_gallery/web/app.js`
  - added `Unpromote` button and editor-state wiring

Validation note:
- tested end-to-end by unpromoting and re-promoting `bureaucracy_case_file`
- confirmed the files disappeared on unpromote and were recreated on re-promote

## Art direction update: new house style

Updated the default bureaucracy generation style.

Files:
- `design/cards_bureaucracy.json`
- `design/CARD_PROMPTING_GUIDELINES.md`
- `tools/comfyui/workflows/card_art_inner.json`

Current defaults:
- positive: `graphic novel illustration, bold ink outlines, flat colors, limited color palette, high contrast, clean linework, strong silhouette, dramatic lighting, professional comic art`
- negative: `photorealistic, 3d render, anime, manga, soft gradients, painterly, watercolor, airbrush, neon colors, bright saturated colors, glowing effects, fantasy lighting, blur, bokeh, soft focus, watermark, logo, speech bubbles, text, letters, numbers, extra limbs, deformed hands, extra fingers, bad anatomy, duplicate figures, multiple people unless specified`

Workflow note:
- the ComfyUI workflow already matched the requested Lightning-style `8 steps / CFG 2.0`
- scheduler was updated to `sgm_uniform`

Prompting strategy now documented:
- lead with attitude, pose energy, environment, and lighting
- do not prompt literal card mechanics
- keep prompts short and single-subject
- object-only prompts should be used when `contains_people` is false

## New generated budget batch

Generated and promoted five new budget cards under the updated house style:
- `Expense Slush Fund`
- `Procurement Leak`
- `Budget Freeze`
- `Golden Parachute`
- `Black Budget`

## Current recommended test order

Tomorrow's best test order:
1. Start a debug run on the backlog branch.
2. Check that the newest promoted reward cards are the backlog batch.
3. Verify the Backlog button is visible in battle, shows a count, and disables correctly when empty / unaffordable.
4. Play `Case File`, `Paper Trail`, or `Hold for Review` and confirm they go to Backlog instead of discard.
5. Use the 3-mana Backlog button and confirm the top hidden card goes into hand.
6. Test `Priority Retrieval` and `Emergency Escalation` to confirm card-driven backlog draws work.
7. Watch crab / bat intents over a few fights and confirm they can add `Misfiled Notice` to the Backlog.
8. Open the gallery and verify `Unpromote` removes a card cleanly from the promoted pool.
9. After backlog checks, test the new budget batch as the second mechanic bucket.
