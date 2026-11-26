# Squareszn

A drag-and-drop block puzzle for iPhone, built with SwiftUI. Drop pieces on an 8×8 board, fill whole rows or columns to clear them, and keep going as long as there's room.

## Modes

- **Infinite:** endless play for a high score (shown with the crown).
- **Seasons:** 4 seasons (🌸 Spring, ☀️ Summer, 🍂 Autumn, ❄️ Winter) of 12 levels each, played in order. Levels start with grey stone blocks on the board.
  - **Score levels:** reach the target score.
  - **💎 levels** (every 3rd): clear the lines holding every gem.
  - **👑 Level 12** of each season is a tougher score level and finishing it pays a season bonus.

## Clearing the whole board changes the blocks

Every time you clear the board completely (+300 points, bonus gold), the run moves to a new block set, adds new piece shapes, and adds special blocks. It lasts until the game ends.

| Board clears | Block set | Added |
| --- | --- | --- |
| 0 | Your skin | Lines, squares, L, T, S and corner pieces |
| 1 | Crystal | Diagonal and plus pieces |
| 2 | Jelly | U and big corner pieces, 💣 Bomb blocks (blast the 3×3 around them when cleared) |
| 3 | Neon | 2×3 and stair pieces, ⭐ Star blocks (+5 gold when cleared) |
| 4 | Lava | Long T and H pieces, ⚡ Zap blocks (clear their whole row and column) |
| 5 | Gold | Specials show up more often |
| 6+ | Galaxy, then the sets repeat | Specials everywhere |

## Revive

When none of your pieces fit, you get a choice:

- **Revive with gold:** 150 gold, doubling each time in the same game (300, 600…).
- **Free revive: watch an ad:** optional, once per game.
- **No thanks:** end the game.

A revive clears the 3 fullest rows (gems stay) and deals 3 pieces that fit.

The ad is a **placeholder** (a 5-second countdown) so the flow works without an ad account. To show real ads, add an ad SDK such as Google Mobile Ads and hook it up in `Ads.swift`.

## Gold and skins

Gold is saved on the device. You start with 100.

| Earned by | Gold |
| --- | --- |
| Each line cleared | 2 |
| Combo (clears on back-to-back moves) | + combo number |
| ⭐ Star block cleared | 5 |
| Board clear | 25–50 (more in later block sets) |
| Season level, first clear | 40–85 (more in later seasons) |
| Finishing a season (level 12) | +210 on top |
| Replaying a cleared level | 10 |

**Block skins** change the base blocks (the ones you play with before the first board clear). Every piece gets a random animal or scene from the skin.

| Rarity | Price | Skins |
| --- | --- | --- |
| Common | 500 | Forest Friends, Farmyard, Pets, Mountains, Beach Day, Blossom |
| Rare | 800 | Ocean Life, Safari, Polar, Woodland, Desert, Night Sky |
| Epic | 1200 | Jungle, Dino Land, Sunset, Aurora |
| 🎁 Mystery | 450 | A random skin you don't own yet |

A decent Infinite game earns roughly 60–150 gold, so a common skin takes a few good games.

## Running it

Same as Halp: open `Squareszn.xcodeproj` in Xcode 15 or newer, pick a simulator or your iPhone, and press Run. For your own iPhone, set your Team under *Signing & Capabilities* and change the bundle ID `com.example.squareszn` if needed.

**Getting an IPA:** every push builds an unsigned `Squareszn.ipa` on GitHub Actions (*Build IPA* workflow, *Artifacts* section). Install it with Sideloadly or AltStore. The workflow also runs the engine tests.

## Code layout

| File | What's in it |
| --- | --- |
| `Squareszn/Engine.swift` | Board, piece shapes, scoring, gold, board-clear tiers, specials, Season levels, revive (no UI, tested by `Tests/main.swift`) |
| `Squareszn/GameController.swift` | Runs a game: moves, popups, revive/ad/game-over flow |
| `Squareszn/GameView.swift` | Board, tray, dragging, HUD, revive and result cards |
| `Squareszn/BlockView.swift` | How blocks look: skins, the block sets, specials |
| `Squareszn/Skins.swift` | Skin catalog and prices, colors, season themes |
| `Squareszn/PlayerStore.swift` | Saved gold, skins, best score, Season progress, level rewards |
| `Squareszn/MenuViews.swift` | Menu, Season map, skin shop |
| `Squareszn/Ads.swift` | Placeholder rewarded ad |

**Tuning:** skin prices are in `Rarity.price` and `SkinCatalog.mysteryPrice` (`Skins.swift`); revive price in `GameController.reviveCost`; gold and points per move in `GameState.place` (`Engine.swift`); level rewards in `PlayerStore.completeLevel`; level targets, gem counts and stone counts in `Seasons`.

**Run the engine tests on a Mac:** `swiftc Squareszn/Engine.swift Tests/main.swift -o enginetests && ./enginetests`
