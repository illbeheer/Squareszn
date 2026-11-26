import SwiftUI

private struct BoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

private struct DragInfo {
    var index: Int
    var location: CGPoint
}

private struct Preview {
    let piece: Piece
    let cells: [GridPoint: Int]
    let clears: Set<GridPoint>
}

struct GameView: View {
    @EnvironmentObject var store: PlayerStore
    @StateObject private var game: GameController
    let onExit: () -> Void
    let onNextLevel: (SeasonLevel) -> Void

    @State private var drag: DragInfo?
    @State private var boardFrame: CGRect = .zero

    init(level: SeasonLevel?, store: PlayerStore,
         onExit: @escaping () -> Void, onNextLevel: @escaping (SeasonLevel) -> Void) {
        _game = StateObject(wrappedValue: GameController(level: level, store: store))
        self.onExit = onExit
        self.onNextLevel = onNextLevel
    }

    private var skin: Skin { store.skin }
    private var state: GameState { game.state }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 24, geo.size.height * 0.56)
            let cell = side / CGFloat(boardSize)
            ZStack {
                VStack(spacing: 10) {
                    topBar
                    if let level = game.level { goalBar(level) }
                    statusRow
                    boardView(cell: cell)
                        .frame(width: side, height: side)
                        .background(GeometryReader { g in
                            Color.clear.preference(key: BoardFrameKey.self, value: g.frame(in: .named("game")))
                        })
                    trayView(cell: cell, width: side)
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)

                dragLayer(cell: cell)
                popupLayer(side: side)
                bannerLayer
                overlays
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "game")
            .onPreferenceChange(BoardFrameKey.self) { boardFrame = $0 }
        }
        .background(background.ignoresSafeArea())
    }

    // MARK: Background

    private var background: some View {
        let colors = game.level.map { SeasonTheme.colors($0.season) } ?? SeasonTheme.infinite
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                game.leave()
                onExit()
            } label: {
                Image(systemName: "house.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.12), in: Circle())
            }

            Spacer()

            VStack(spacing: 0) {
                if let level = game.level {
                    Text("\(Seasons.icons[level.season]) \(Seasons.names[level.season]) \(level.index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                } else {
                    Label("\(max(store.data.bestScore, state.score))", systemImage: "crown.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: 0xFFD93D))
                }
                Text("\(state.score)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: state.score)
            }

            Spacer()

            GoldChip(amount: store.data.gold)
                .frame(minWidth: 42, alignment: .trailing)
        }
        .padding(.horizontal, 14)
    }

    private func goalBar(_ level: SeasonLevel) -> some View {
        let accent = SeasonTheme.accent(level.season)
        return Group {
            if level.isGemGoal {
                HStack(spacing: 6) {
                    Text("Collect the gems:")
                    Text("💎 \(state.gemsLeft) left").bold()
                }
                .font(.subheadline)
                .foregroundColor(.white)
            } else {
                let frac = min(1, Double(state.score) / Double(max(1, level.targetScore)))
                VStack(spacing: 4) {
                    Text("Target \(level.targetScore)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(accent)
                                .frame(width: max(8, g.size.width * frac))
                                .animation(.easeOut(duration: 0.3), value: frac)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 40)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            let info = Tiers.info(state.tier)
            Text(state.tier == 0 ? "Blocks: \(skin.name)" : "Blocks: \(info.name)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
            if state.streak >= 2 {
                Text("🔥 Combo ×\(state.streak)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.35), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .foregroundColor(.white)
        .animation(.spring(), value: state.streak)
        .frame(height: 24)
    }

    // MARK: Board

    private func boardView(cell: CGFloat) -> some View {
        let preview = currentPreview(cell: cell)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.35))
                .padding(-4)
            ForEach(0..<(boardSize * boardSize), id: \.self) { i in
                cellView(r: i / boardSize, c: i % boardSize, cell: cell, preview: preview)
                    .position(x: (CGFloat(i % boardSize) + 0.5) * cell,
                              y: (CGFloat(i / boardSize) + 0.5) * cell)
            }
            ForEach(game.bursts) { b in
                BlockView(block: b.block, size: cell - 2, skin: skin)
                    .position(x: (CGFloat(b.point.c) + 0.5) * cell, y: (CGFloat(b.point.r) + 0.5) * cell)
                    .transition(.scale(scale: 1.7).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func cellView(r: Int, c: Int, cell: CGFloat, preview: Preview?) -> some View {
        let p = GridPoint(r: r, c: c)
        let size = cell - 2
        ZStack {
            RoundedRectangle(cornerRadius: cell * 0.16)
                .fill(Color.white.opacity(0.07))
                .frame(width: size, height: size)
            if let b = state.board[r][c] {
                if let pv = preview, pv.clears.contains(p) {
                    // Lines about to clear light up in the dragged piece's look.
                    BlockView(block: Block(color: pv.piece.color, motif: pv.piece.motif,
                                           tier: pv.piece.tier, special: b.special),
                              size: size, skin: skin)
                        .overlay(RoundedRectangle(cornerRadius: size * 0.18)
                            .stroke(Color.white.opacity(0.9), lineWidth: 2))
                } else {
                    BlockView(block: b, size: size, skin: skin)
                }
            } else if let pv = preview, let idx = pv.cells[p] {
                BlockView(block: pv.piece.block(idx), size: size, skin: skin)
                    .opacity(pv.clears.contains(p) ? 0.95 : 0.5)
            }
        }
        .frame(width: cell, height: cell)
    }

    // MARK: Tray and dragging

    private func trayCellSize(cell: CGFloat, width: CGFloat) -> CGFloat {
        min(cell * 0.55, (width / 3 - 8) / 5)
    }

    private func trayView(cell: CGFloat, width: CGFloat) -> some View {
        let slotW = width / 3
        let tc = trayCellSize(cell: cell, width: width)
        return HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    if let piece = state.tray[i], drag?.index != i {
                        PieceView(piece: piece, cell: tc, skin: skin, gap: 1.5)
                            .opacity(state.fits(piece.shape) ? 1 : 0.35)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: slotW, height: tc * 5 + 12)
                .contentShape(Rectangle())
                .gesture(dragGesture(index: i, cell: cell))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.tray.map { $0?.id })
        .padding(.top, 8)
    }

    private func dragGesture(index: Int, cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("game"))
            .onChanged { v in
                guard !game.inputLocked, state.tray[index] != nil else { return }
                drag = DragInfo(index: index, location: v.location)
            }
            .onEnded { v in
                defer { drag = nil }
                guard !game.inputLocked, let piece = state.tray[index] else { return }
                game.drop(trayIndex: index, at: origin(for: piece, at: v.location, cell: cell))
            }
    }

    /// The dragged piece floats above the finger so it stays visible.
    private func liftedCenter(_ loc: CGPoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: loc.x, y: loc.y - cell * 2.3)
    }

    private func origin(for piece: Piece, at loc: CGPoint, cell: CGFloat) -> GridPoint {
        let center = liftedCenter(loc, cell: cell)
        let x = center.x - CGFloat(piece.shape.width) * cell / 2 - boardFrame.minX
        let y = center.y - CGFloat(piece.shape.height) * cell / 2 - boardFrame.minY
        return GridPoint(r: Int((y / cell).rounded()), c: Int((x / cell).rounded()))
    }

    private func currentPreview(cell: CGFloat) -> Preview? {
        guard let drag, !game.inputLocked, let piece = state.tray[drag.index] else { return nil }
        let o = origin(for: piece, at: drag.location, cell: cell)
        guard state.canPlace(piece.shape, at: o) else { return nil }
        var cells: [GridPoint: Int] = [:]
        for (i, p) in piece.shape.cells.enumerated() {
            cells[GridPoint(r: o.r + p.r, c: o.c + p.c)] = i
        }
        return Preview(piece: piece, cells: cells, clears: state.previewClears(piece.shape, at: o))
    }

    @ViewBuilder
    private func dragLayer(cell: CGFloat) -> some View {
        if let drag, let piece = state.tray[drag.index] {
            PieceView(piece: piece, cell: cell, skin: skin)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 6)
                .position(liftedCenter(drag.location, cell: cell))
                .allowsHitTesting(false)
        }
    }

    // MARK: Popups and banners

    @ViewBuilder
    private func popupLayer(side: CGFloat) -> some View {
        if let p = game.popup {
            VStack(spacing: 2) {
                Text(p.text)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                if let d = p.detail {
                    Text(d).font(.headline)
                }
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 4)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Color.black.opacity(0.25), in: Capsule())
            .position(x: boardFrame.midX, y: boardFrame.minY + side * 0.3)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .id(p.id)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var bannerLayer: some View {
        if let tier = game.tierBanner {
            let info = Tiers.info(tier)
            let shapes = ShapeCatalog.newGroupNames(atTier: tier)
            VStack(spacing: 8) {
                Text("BOARD CLEARED!")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: 0xFFD93D))
                Text("+300")
                    .font(.title2.bold())
                Text("New blocks: \(info.name)")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        BlockView(block: Block(color: i, motif: i, tier: tier), size: 26, skin: skin)
                    }
                }
                Text(shapes.isEmpty ? info.blurb : "\(info.blurb)\nNew: \(shapes.joined(separator: ", "))")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
            }
            .foregroundColor(.white)
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.75)))
            .padding(30)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }

    // MARK: End-of-run overlays

    @ViewBuilder
    private var overlays: some View {
        switch game.phase {
        case .playing:
            EmptyView()
        case .revive:
            dim
            ReviveCard(score: state.score,
                       cost: game.reviveCost,
                       gold: store.data.gold,
                       adAvailable: !state.adReviveUsed,
                       onGold: { game.reviveWithGold() },
                       onAd: { game.watchAd() },
                       onGiveUp: { game.giveUp() })
                .transition(.scale.combined(with: .opacity))
        case .ad:
            RewardedAdView { rewarded in game.adFinished(rewarded: rewarded) }
                .transition(.opacity)
        case .over:
            dim
            ResultCard(title: game.level == nil ? "Game Over" : "Out of moves",
                       lines: resultLines(won: false),
                       primary: game.level == nil ? "Play again" : "Try again",
                       onPrimary: { game.restart() },
                       secondary: "Home",
                       onSecondary: onExit)
                .transition(.scale.combined(with: .opacity))
        case .won:
            dim
            ResultCard(title: "Level complete!",
                       lines: resultLines(won: true),
                       primary: nextLevel == nil ? "Seasons" : "Next level",
                       onPrimary: {
                           if let next = nextLevel { onNextLevel(next) } else { onExit() }
                       },
                       secondary: "Seasons",
                       onSecondary: onExit)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var nextLevel: SeasonLevel? {
        guard let level = game.level, level.number + 1 < Seasons.totalLevels else { return nil }
        return Seasons.level(number: level.number + 1)
    }

    private func resultLines(won: Bool) -> [String] {
        var out = ["Score \(state.score)"]
        if game.level == nil {
            out.append(game.newBest ? "🏆 New best!" : "Best \(store.data.bestScore)")
        }
        out.append("Gold earned 🪙 \(state.goldEarned + (won ? game.levelReward : 0))")
        if won, let level = game.level, level.isBoss, game.levelReward > 100 {
            out.append("\(Seasons.icons[level.season]) \(Seasons.names[level.season]) complete!")
        }
        if state.boardClears > 0 { out.append("Board clears: \(state.boardClears)") }
        return out
    }

    private var dim: some View {
        Color.black.opacity(0.55).ignoresSafeArea().transition(.opacity)
    }
}

// MARK: - Pieces of UI shared by several screens

struct GoldChip: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("🪙")
            Text("\(amount)")
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: amount)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.3), in: Capsule())
    }
}

struct BigButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Color(hex: 0x4CD97B)
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(enabled ? color : Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .foregroundColor(.white)
        }
        .disabled(!enabled)
    }
}

struct ReviveCard: View {
    let score: Int
    let cost: Int
    let gold: Int
    let adAvailable: Bool
    let onGold: () -> Void
    let onAd: () -> Void
    let onGiveUp: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("No space left!")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("Score \(score)")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
            Text("Revive to clear 3 rows and get pieces that fit.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.75))

            BigButton(title: "Revive  🪙 \(cost)", icon: "heart.fill",
                      color: Color(hex: 0xF2A93B), enabled: gold >= cost, action: onGold)
            if gold < cost {
                Text("You have 🪙 \(gold)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            if adAvailable {
                BigButton(title: "Free revive: watch an ad", icon: "play.rectangle.fill",
                          color: Color(hex: 0x4D7CFF), action: onAd)
                Text("Optional. One free revive per game.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Button("No thanks", action: onGiveUp)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 4)
        }
        .foregroundColor(.white)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x1E2350)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15)))
        .padding(28)
    }
}

struct ResultCard: View {
    let title: String
    let lines: [String]
    let primary: String
    let onPrimary: () -> Void
    let secondary: String
    let onSecondary: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            ForEach(lines, id: \.self) { line in
                Text(line).font(.title3.weight(.medium))
            }
            BigButton(title: primary, icon: "arrow.clockwise", action: onPrimary)
                .padding(.top, 8)
            BigButton(title: secondary, icon: "house.fill", color: Color.white.opacity(0.15), action: onSecondary)
        }
        .foregroundColor(.white)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x1E2350)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15)))
        .padding(28)
    }
}
