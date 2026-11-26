import SwiftUI

enum Screen: Equatable {
    case menu
    case seasons
    case skins
    case infinite
    case level(Int)
}

struct ContentView: View {
    @StateObject private var store = PlayerStore()
    @State private var screen: Screen = .menu
    @State private var runID = 0

    var body: some View {
        ZStack {
            switch screen {
            case .menu:
                MenuView(go: go)
            case .seasons:
                SeasonMapView(go: go)
            case .skins:
                SkinShopView(go: go)
            case .infinite:
                GameView(level: nil, store: store,
                         onExit: { go(.menu) },
                         onNextLevel: { _ in })
                    .id("infinite-\(runID)")
            case .level(let n):
                GameView(level: Seasons.level(number: n), store: store,
                         onExit: { go(.seasons) },
                         onNextLevel: { go(.level($0.number)) })
                    .id("level-\(n)-\(runID)")
            }
        }
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }

    private func go(_ s: Screen) {
        runID += 1
        withAnimation(.easeInOut(duration: 0.25)) { screen = s }
    }
}

// MARK: - Main menu

struct MenuView: View {
    @EnvironmentObject var store: PlayerStore
    let go: (Screen) -> Void
    @State private var bob = false

    init(go: @escaping (Screen) -> Void) { self.go = go }

    var body: some View {
        ZStack {
            LinearGradient(colors: SeasonTheme.infinite, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    GoldChip(amount: store.data.gold)
                }
                .padding(.horizontal)

                Spacer()

                logo
                    .offset(y: bob ? -6 : 6)
                    .animation(.easeInOut(duration: 1.6).repeatForever(), value: bob)

                Text("SQUARESZN")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFD93D), Color(hex: 0xFF5D73)],
                                                    startPoint: .leading, endPoint: .trailing))
                Text("Drag, drop, clear the lines")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                VStack(spacing: 12) {
                    BigButton(title: "Infinite", icon: "infinity", color: Color(hex: 0x4CD97B)) { go(.infinite) }
                    if store.data.bestScore > 0 {
                        Label("Best \(store.data.bestScore)", systemImage: "crown.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color(hex: 0xFFD93D))
                    }
                    BigButton(title: "Seasons", icon: "leaf.fill", color: Color(hex: 0xFF9F43)) { go(.seasons) }
                    Text(seasonProgressText)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                    BigButton(title: "Block Skins", icon: "paintpalette.fill", color: Color(hex: 0xB45DFF)) { go(.skins) }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear { bob = true }
    }

    private var seasonProgressText: String {
        let n = store.data.seasonCleared
        if n >= Seasons.totalLevels { return "All seasons complete!" }
        let next = Seasons.level(number: n)
        return "Next: \(Seasons.icons[next.season]) \(Seasons.names[next.season]) \(next.index + 1)"
    }

    private var logo: some View {
        let skin = store.skin
        let layout: [(Int, Int)] = [(0, 0), (0, 1), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)]
        return ZStack(alignment: .topLeading) {
            ForEach(0..<layout.count, id: \.self) { i in
                BlockView(block: Block(color: i, motif: i, tier: 0), size: 38, skin: skin)
                    .offset(x: CGFloat(layout[i].1) * 40, y: CGFloat(layout[i].0) * 40)
            }
        }
        .frame(width: 118, height: 118, alignment: .topLeading)
    }
}

// MARK: - Season map

struct SeasonMapView: View {
    @EnvironmentObject var store: PlayerStore
    let go: (Screen) -> Void

    init(go: @escaping (Screen) -> Void) { self.go = go }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            LinearGradient(colors: SeasonTheme.infinite, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header(title: "Seasons", go: go, gold: store.data.gold)
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(0..<Seasons.count, id: \.self) { s in
                            seasonCard(s)
                        }
                        Text("Score levels: reach the target score. 💎 levels: clear the lines holding every gem. Stone blocks are already on the board.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
        }
    }

    private func seasonCard(_ s: Int) -> some View {
        let first = Seasons.level(season: s, index: 0)
        let unlocked = store.isUnlocked(first)
        let cleared = (0..<Seasons.levelsPerSeason).filter {
            store.isCleared(Seasons.level(season: s, index: $0))
        }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(Seasons.icons[s]) \(Seasons.names[s])")
                    .font(.title2.bold())
                Spacer()
                Text("\(cleared)/\(Seasons.levelsPerSeason)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            if unlocked {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0..<Seasons.levelsPerSeason, id: \.self) { i in
                        levelButton(Seasons.level(season: s, index: i))
                    }
                }
            } else {
                Label("Finish \(Seasons.names[max(0, s - 1)]) to unlock", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .foregroundColor(.white)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: SeasonTheme.colors(s), startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .opacity(unlocked ? 1 : 0.6)
    }

    private func levelButton(_ level: SeasonLevel) -> some View {
        let unlocked = store.isUnlocked(level)
        let cleared = store.isCleared(level)
        let accent = SeasonTheme.accent(level.season)
        return Button {
            go(.level(level.number))
        } label: {
            VStack(spacing: 2) {
                if unlocked {
                    Text("\(level.index + 1)")
                        .font(.title3.bold())
                    Text(cleared ? "✓" : (level.isGemGoal ? "💎" : (level.isBoss ? "👑" : "")))
                        .font(.caption2)
                        .frame(height: 12)
                } else {
                    Image(systemName: "lock.fill")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cleared ? accent.opacity(0.85) : Color.black.opacity(unlocked ? 0.35 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(level.number == store.data.seasonCleared ? accent : Color.clear, lineWidth: 2)
            )
            .foregroundColor(cleared ? .black : .white)
        }
        .disabled(!unlocked)
    }
}

// MARK: - Skin shop

struct SkinShopView: View {
    @EnvironmentObject var store: PlayerStore
    let go: (Screen) -> Void

    @State private var pendingBuy: Skin?
    @State private var mysteryResult: Skin?
    @State private var confirmMystery = false

    init(go: @escaping (Screen) -> Void) { self.go = go }

    var body: some View {
        ZStack {
            LinearGradient(colors: SeasonTheme.infinite, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header(title: "Block Skins", go: go, gold: store.data.gold)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Skins change your base blocks: the ones you play with until you clear the whole board. Every board clear swaps in a new block set until the game ends. Earn gold by clearing lines, combos, board clears and Season levels.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))

                        mysteryCard

                        section(.animals)
                        section(.scenery)
                        section(.classic)
                    }
                    .padding()
                }
            }
        }
        .alert(item: $pendingBuy) { skin in
            Alert(title: Text("Buy \(skin.name)?"),
                  message: Text("Costs 🪙 \(skin.price). You have 🪙 \(store.data.gold)."),
                  primaryButton: .default(Text("Buy")) { _ = store.buy(skin) },
                  secondaryButton: .cancel())
        }
        .alert("Mystery skin", isPresented: $confirmMystery) {
            Button("Open for 🪙 \(SkinCatalog.mysteryPrice)") {
                mysteryResult = store.buyMystery()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Get a random animal or scenery skin you don't own yet. It could be Epic!")
        }
        .sheet(item: $mysteryResult) { skin in
            MysteryRevealView(skin: skin) { mysteryResult = nil }
        }
    }

    private var mysteryCard: some View {
        let left = store.unownedSkins.count
        let affordable = store.data.gold >= SkinCatalog.mysteryPrice
        return HStack(spacing: 14) {
            Text("🎁").font(.system(size: 44))
            VStack(alignment: .leading, spacing: 4) {
                Text("Mystery Skin").font(.headline)
                Text(left == 0 ? "You own every skin!" : "A random skin you don't have (\(left) left)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            if left > 0 {
                Button {
                    confirmMystery = true
                } label: {
                    Text("🪙 \(SkinCatalog.mysteryPrice)")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(affordable ? Color(hex: 0xF2A93B) : Color.gray.opacity(0.5), in: Capsule())
                }
                .disabled(!affordable)
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(
            LinearGradient(colors: [Color(hex: 0x6A3FA0), Color(hex: 0xC2507A)],
                           startPoint: .leading, endPoint: .trailing)))
    }

    private func section(_ kind: SkinKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.rawValue).font(.title3.bold()).foregroundColor(.white)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(SkinCatalog.all.filter { $0.kind == kind }) { skin in
                    skinCard(skin)
                }
            }
        }
    }

    private func skinCard(_ skin: Skin) -> some View {
        let owned = store.owns(skin)
        let selected = store.data.selectedSkin == skin.id
        let affordable = store.data.gold >= skin.price
        return VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<min(4, skin.motifs.count), id: \.self) { i in
                    BlockView(block: Block(color: i, motif: 0, tier: 0), size: 30, skin: skin)
                }
            }
            .frame(height: 34)
            Text(skin.name).font(.subheadline.bold())
            Text(skin.rarity.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundColor(skin.rarity.color)
            Button {
                if owned { store.select(skin) } else { pendingBuy = skin }
            } label: {
                Text(selected ? "In use" : (owned ? "Use" : "🪙 \(skin.price)"))
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(buttonColor(owned: owned, selected: selected, affordable: affordable),
                                in: Capsule())
            }
            .disabled(selected || (!owned && !affordable))
        }
        .foregroundColor(.white)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(selected ? Color(hex: 0x4CD97B) : skin.rarity.color.opacity(0.35), lineWidth: selected ? 2.5 : 1))
    }

    private func buttonColor(owned: Bool, selected: Bool, affordable: Bool) -> Color {
        if selected { return Color(hex: 0x4CD97B).opacity(0.6) }
        if owned { return Color(hex: 0x4D7CFF) }
        return affordable ? Color(hex: 0xF2A93B) : Color.gray.opacity(0.5)
    }
}

struct MysteryRevealView: View {
    let skin: Skin
    let onDone: () -> Void
    @State private var shown = false

    init(skin: Skin, onDone: @escaping () -> Void) {
        self.skin = skin
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A0F5A), Color(hex: 0x6A3FA0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Text("You got…").font(.title2).foregroundColor(.white.opacity(0.8))
                Text(skin.name)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(skin.rarity.rawValue)
                    .font(.headline)
                    .foregroundColor(skin.rarity.color)
                HStack(spacing: 6) {
                    ForEach(0..<skin.motifs.count, id: \.self) { i in
                        BlockView(block: Block(color: i, motif: 0, tier: 0), size: 54, skin: skin)
                    }
                }
                .scaleEffect(shown ? 1 : 0.2)
                .opacity(shown ? 1 : 0)
                Text("Equipped!").foregroundColor(.white.opacity(0.8))
                BigButton(title: "Nice!", action: onDone).padding(.horizontal, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { shown = true }
        }
    }
}

// MARK: - Shared header

func header(title: String, go: @escaping (Screen) -> Void, gold: Int) -> some View {
    HStack {
        Button {
            go(.menu)
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        Spacer()
        Text(title).font(.title2.bold()).foregroundColor(.white)
        Spacer()
        GoldChip(amount: gold)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
}
