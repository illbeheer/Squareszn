import Foundation

// Pure game logic: no SwiftUI here, so it can be compiled and tested on its own
// (see Tests/main.swift and the CI workflow).

let boardSize = 8

struct GridPoint: Hashable, Codable {
    var r: Int
    var c: Int
}

/// Small, fast, seedable random generator (SplitMix64).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed ^ 0x5DEECE66D }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Blocks

enum Special: String, Codable {
    case none
    case bomb   // blasts the 3x3 around it when cleared
    case star   // worth extra gold when cleared
    case zap    // clears its whole row and column when cleared
    case gem    // Season goal: collect by clearing its line
}

struct Block: Codable, Equatable {
    /// Random numbers; the renderer picks a color/motif with `% count`.
    var color: Int
    var motif: Int
    /// Board-clear tier the block was made in. 0 = base blocks (drawn with the
    /// player's skin), 1+ = special block sets, -1 = stone (Season obstacles).
    var tier: Int
    var special: Special = .none
}

// MARK: - Shapes

struct PieceShape: Hashable {
    let cells: [GridPoint]
    let width: Int
    let height: Int

    init(cells raw: [GridPoint]) {
        let minR = raw.map(\.r).min() ?? 0
        let minC = raw.map(\.c).min() ?? 0
        let norm = raw
            .map { GridPoint(r: $0.r - minR, c: $0.c - minC) }
            .sorted { ($0.r, $0.c) < ($1.r, $1.c) }
        cells = norm
        width = (norm.map(\.c).max() ?? 0) + 1
        height = (norm.map(\.r).max() ?? 0) + 1
    }

    /// Build from rows of text, `X` = filled.
    init(_ rows: [String]) {
        var pts: [GridPoint] = []
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where ch == "X" {
                pts.append(GridPoint(r: r, c: c))
            }
        }
        self.init(cells: pts)
    }

    func rotated() -> PieceShape {
        PieceShape(cells: cells.map { GridPoint(r: $0.c, c: height - 1 - $0.r) })
    }

    func mirrored() -> PieceShape {
        PieceShape(cells: cells.map { GridPoint(r: $0.r, c: width - 1 - $0.c) })
    }

    func variants(rotate: Bool, mirror: Bool) -> [PieceShape] {
        var out: [PieceShape] = []
        var bases = [self]
        if mirror { bases.append(mirrored()) }
        for base in bases {
            var s = base
            for _ in 0..<(rotate ? 4 : 1) {
                if !out.contains(s) { out.append(s) }
                s = s.rotated()
            }
        }
        return out
    }
}

struct ShapeGroup {
    let name: String
    let minTier: Int
    let weight: Int
    let variants: [PieceShape]
}

enum ShapeCatalog {
    static let groups: [ShapeGroup] = [
        // Base set
        group("Single", 0, 3, ["X"]),
        group("Duo", 0, 5, ["XX"], rotate: true),
        group("Line 3", 0, 6, ["XXX"], rotate: true),
        group("Line 4", 0, 5, ["XXXX"], rotate: true),
        group("Line 5", 0, 3, ["XXXXX"], rotate: true),
        group("Square", 0, 6, ["XX", "XX"]),
        group("Big Square", 0, 3, ["XXX", "XXX", "XXX"]),
        group("Corner", 0, 6, ["X.", "XX"], rotate: true),
        group("L", 0, 6, ["X.", "X.", "XX"], rotate: true, mirror: true),
        group("T", 0, 5, ["XXX", ".X."], rotate: true),
        group("S", 0, 4, [".XX", "XX."], rotate: true, mirror: true),
        // Unlocked by the 1st board clear (Crystal)
        group("Diagonal 2", 1, 3, ["X.", ".X"], rotate: true),
        group("Diagonal 3", 1, 2, ["X..", ".X.", "..X"], rotate: true),
        group("Plus", 1, 3, [".X.", "XXX", ".X."]),
        // 2nd clear (Jelly)
        group("U", 2, 3, ["X.X", "XXX"], rotate: true),
        group("Big Corner", 2, 2, ["X..", "X..", "XXX"], rotate: true),
        // 3rd clear (Neon)
        group("Block 2x3", 3, 3, ["XXX", "XXX"], rotate: true),
        group("Stairs", 3, 2, ["X..", "XX.", ".XX"], rotate: true),
        // 4th clear (Lava)
        group("Long T", 4, 2, ["XXX", ".X.", ".X."], rotate: true),
        group("H", 4, 2, ["X.X", "XXX", "X.X"], rotate: true),
    ]

    static func group(_ name: String, _ tier: Int, _ weight: Int, _ rows: [String],
                      rotate: Bool = false, mirror: Bool = false) -> ShapeGroup {
        ShapeGroup(name: name, minTier: tier, weight: weight,
                   variants: PieceShape(rows).variants(rotate: rotate, mirror: mirror))
    }

    static func groups(forTier tier: Int) -> [ShapeGroup] {
        groups.filter { $0.minTier <= tier }
    }

    static func newGroupNames(atTier tier: Int) -> [String] {
        groups.filter { $0.minTier == tier }.map(\.name)
    }
}

// MARK: - Tiers (what changes each time the board is cleared)

struct TierInfo {
    let name: String
    let blurb: String
}

enum Tiers {
    static let list: [TierInfo] = [
        TierInfo(name: "Base", blurb: "Your skin"),
        TierInfo(name: "Crystal", blurb: "Diagonal and plus pieces join the mix"),
        TierInfo(name: "Jelly", blurb: "U and big corner pieces, and Bomb blocks 💣"),
        TierInfo(name: "Neon", blurb: "2×3 and stair pieces, and Star blocks ⭐ worth gold"),
        TierInfo(name: "Lava", blurb: "Long T and H pieces, and Zap blocks ⚡"),
        TierInfo(name: "Gold", blurb: "Special blocks show up more often"),
        TierInfo(name: "Galaxy", blurb: "Specials everywhere"),
    ]

    /// Visual style for a tier: 0 = skin, 1...6 = block sets, cycling after Galaxy.
    static func style(_ tier: Int) -> Int {
        tier <= 0 ? 0 : ((tier - 1) % 6) + 1
    }

    static func info(_ tier: Int) -> TierInfo { list[style(tier)] }
}

// MARK: - Pieces

struct Piece: Identifiable, Equatable {
    let id: UUID
    let shape: PieceShape
    var color: Int
    var motif: Int
    var tier: Int
    /// Special blocks inside the piece, keyed by index into `shape.cells`.
    var specials: [Int: Special]

    init(shape: PieceShape, color: Int, motif: Int, tier: Int, specials: [Int: Special] = [:]) {
        self.id = UUID()
        self.shape = shape
        self.color = color
        self.motif = motif
        self.tier = tier
        self.specials = specials
    }

    func block(_ i: Int) -> Block {
        Block(color: color, motif: motif, tier: tier, special: specials[i] ?? .none)
    }
}

// MARK: - Season mode

struct SeasonLevel: Hashable, Codable {
    let season: Int
    let index: Int
    let targetScore: Int
    let gems: Int

    var number: Int { season * Seasons.levelsPerSeason + index }
    var isGemGoal: Bool { gems > 0 }
    var isBoss: Bool { index == Seasons.levelsPerSeason - 1 }
}

enum Seasons {
    static let names = ["Spring", "Summer", "Autumn", "Winter"]
    static let icons = ["🌸", "☀️", "🍂", "❄️"]
    static let levelsPerSeason = 12
    static var count: Int { names.count }
    static var totalLevels: Int { count * levelsPerSeason }

    static func level(number: Int) -> SeasonLevel {
        let n = max(0, min(number, totalLevels - 1))
        return level(season: n / levelsPerSeason, index: n % levelsPerSeason)
    }

    static func level(season: Int, index: Int) -> SeasonLevel {
        let gemLevel = index % 3 == 2
        let gems = gemLevel ? 3 + index / 3 + season : 0
        var target = 500 + index * 200 + season * 350
        if index == levelsPerSeason - 1 { target = target * 13 / 10 }
        return SeasonLevel(season: season, index: index, targetScore: gemLevel ? 0 : target, gems: gems)
    }

    /// Starting board for a level: stone obstacles (some holding gems).
    /// Never leaves a full row or column, so nothing clears on its own.
    static func startingBoard(for level: SeasonLevel) -> [[Block?]] {
        var rng = SeededRNG(seed: UInt64(1000 + level.number * 7919))
        var board = [[Block?]](repeating: [Block?](repeating: nil, count: boardSize), count: boardSize)
        let stones = min(28, 4 + level.index * 2 + level.season * 3)
        let wanted = max(stones, level.gems)
        var placed: [GridPoint] = []
        var attempts = 0
        while placed.count < wanted && attempts < 2000 {
            attempts += 1
            let r = Int.random(in: 0..<boardSize, using: &rng)
            let c = Int.random(in: 0..<boardSize, using: &rng)
            guard board[r][c] == nil else { continue }
            let rowCount = board[r].compactMap { $0 }.count
            let colCount = (0..<boardSize).filter { board[$0][c] != nil }.count
            guard rowCount < boardSize - 2, colCount < boardSize - 2 else { continue }
            board[r][c] = Block(color: Int.random(in: 0..<1000, using: &rng),
                                motif: Int.random(in: 0..<1000, using: &rng), tier: -1)
            placed.append(GridPoint(r: r, c: c))
        }
        // Gems go on the first stones placed (random positions).
        for p in placed.prefix(level.gems) {
            board[p.r][p.c]?.special = .gem
        }
        return board
    }
}

// MARK: - Move result

struct MoveResult {
    var placedCells: [GridPoint] = []
    var clearedRows: [Int] = []
    var clearedCols: [Int] = []
    /// Every block removed this move (lines plus bomb/zap blasts), with what it was.
    var cleared: [(GridPoint, Block)] = []
    var points = 0
    var gold = 0
    var streak = 0
    var gemsCollected = 0
    var starsCollected = 0
    var blasts = 0
    var boardCleared = false
    var newTier = 0

    var lines: Int { clearedRows.count + clearedCols.count }
}

// MARK: - Game state

struct GameState {
    var board: [[Block?]]
    var tray: [Piece?] = [nil, nil, nil]
    var score = 0
    var goldEarned = 0
    var streak = 0
    var movesSinceClear = 0
    var tier = 0
    var boardClears = 0
    var gemsLeft = 0
    var goldRevivesUsed = 0
    var adReviveUsed = false
    let level: SeasonLevel?
    var rng: SeededRNG

    init(level: SeasonLevel?, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.level = level
        self.rng = SeededRNG(seed: seed)
        if let level {
            board = Seasons.startingBoard(for: level)
            gemsLeft = board.joined().filter { $0?.special == .gem }.count
        } else {
            board = [[Block?]](repeating: [Block?](repeating: nil, count: boardSize), count: boardSize)
        }
        refillTray()
    }

    // MARK: Queries

    func canPlace(_ shape: PieceShape, at o: GridPoint) -> Bool {
        for p in shape.cells {
            let r = o.r + p.r, c = o.c + p.c
            if r < 0 || c < 0 || r >= boardSize || c >= boardSize { return false }
            if board[r][c] != nil { return false }
        }
        return true
    }

    func fits(_ shape: PieceShape) -> Bool {
        if shape.height > boardSize || shape.width > boardSize { return false }
        for r in 0...(boardSize - shape.height) {
            for c in 0...(boardSize - shape.width) where canPlace(shape, at: GridPoint(r: r, c: c)) {
                return true
            }
        }
        return false
    }

    var isStuck: Bool {
        let remaining = tray.compactMap { $0 }
        return !remaining.isEmpty && !remaining.contains { fits($0.shape) }
    }

    var isWon: Bool {
        guard let level else { return false }
        return level.isGemGoal ? gemsLeft <= 0 : score >= level.targetScore
    }

    var isBoardEmpty: Bool { board.allSatisfy { row in row.allSatisfy { $0 == nil } } }

    /// Cells in the rows/columns that would clear if `shape` were dropped at `o`.
    func previewClears(_ shape: PieceShape, at o: GridPoint) -> Set<GridPoint> {
        guard canPlace(shape, at: o) else { return [] }
        var filled = Set<GridPoint>()
        for p in shape.cells { filled.insert(GridPoint(r: o.r + p.r, c: o.c + p.c)) }
        func isFull(_ r: Int, _ c: Int) -> Bool { board[r][c] != nil || filled.contains(GridPoint(r: r, c: c)) }
        var out = Set<GridPoint>()
        for r in 0..<boardSize where (0..<boardSize).allSatisfy({ isFull(r, $0) }) {
            for c in 0..<boardSize { out.insert(GridPoint(r: r, c: c)) }
        }
        for c in 0..<boardSize where (0..<boardSize).allSatisfy({ isFull($0, c) }) {
            for r in 0..<boardSize { out.insert(GridPoint(r: r, c: c)) }
        }
        return out
    }

    // MARK: Moves

    @discardableResult
    mutating func place(trayIndex: Int, at o: GridPoint) -> MoveResult? {
        guard tray.indices.contains(trayIndex), let piece = tray[trayIndex],
              canPlace(piece.shape, at: o) else { return nil }

        var result = MoveResult()
        for (i, p) in piece.shape.cells.enumerated() {
            let g = GridPoint(r: o.r + p.r, c: o.c + p.c)
            board[g.r][g.c] = piece.block(i)
            result.placedCells.append(g)
        }
        tray[trayIndex] = nil
        result.points = piece.shape.cells.count

        // Full lines
        for r in 0..<boardSize where board[r].allSatisfy({ $0 != nil }) { result.clearedRows.append(r) }
        for c in 0..<boardSize where (0..<boardSize).allSatisfy({ board[$0][c] != nil }) { result.clearedCols.append(c) }

        if result.lines > 0 {
            streak += 1
            movesSinceClear = 0
        } else {
            movesSinceClear += 1
            if movesSinceClear >= 3 { streak = 0 }
        }
        result.streak = streak

        if result.lines > 0 {
            var toClear = Set<GridPoint>()
            for r in result.clearedRows { for c in 0..<boardSize { toClear.insert(GridPoint(r: r, c: c)) } }
            for c in result.clearedCols { for r in 0..<boardSize { toClear.insert(GridPoint(r: r, c: c)) } }
            let lineCells = toClear

            // Specials chain: bombs and zaps can set off more specials.
            var queue = Array(toClear)
            var triggered = Set<GridPoint>()
            while let p = queue.popLast() {
                guard let b = board[p.r][p.c], !triggered.contains(p) else { continue }
                var extra: [GridPoint] = []
                switch b.special {
                case .bomb:
                    for dr in -1...1 { for dc in -1...1 { extra.append(GridPoint(r: p.r + dr, c: p.c + dc)) } }
                case .zap:
                    for i in 0..<boardSize {
                        extra.append(GridPoint(r: p.r, c: i))
                        extra.append(GridPoint(r: i, c: p.c))
                    }
                default:
                    break
                }
                guard !extra.isEmpty else { continue }
                triggered.insert(p)
                for e in extra where e.r >= 0 && e.c >= 0 && e.r < boardSize && e.c < boardSize {
                    if board[e.r][e.c] != nil && !toClear.contains(e) {
                        toClear.insert(e)
                        queue.append(e)
                    }
                }
            }

            for p in toClear.sorted(by: { ($0.r, $0.c) < ($1.r, $1.c) }) {
                guard let b = board[p.r][p.c] else { continue }
                result.cleared.append((p, b))
                if b.special == .gem { result.gemsCollected += 1 }
                if b.special == .star { result.starsCollected += 1 }
                board[p.r][p.c] = nil
            }
            result.blasts = toClear.subtracting(lineCells).count

            let l = result.lines
            result.points += 10 * l * (l + 1) / 2 * max(1, streak)
            result.points += result.blasts * 3
            result.gold += 2 * l + (streak >= 2 ? streak : 0) + 5 * result.starsCollected
            gemsLeft = max(0, gemsLeft - result.gemsCollected)

            if isBoardEmpty {
                result.boardCleared = true
                tier += 1
                boardClears += 1
                result.points += 300
                result.gold += 20 + 5 * min(tier, 6)
                // Pieces still waiting in the tray switch to the new block set.
                for i in tray.indices { tray[i]?.tier = tier }
            }
        }
        result.newTier = tier

        score += result.points
        goldEarned += result.gold

        if tray.allSatisfy({ $0 == nil }) { refillTray() }
        return result
    }

    // MARK: Pieces

    mutating func randomPiece(fitting: Bool = false) -> Piece {
        let groups = ShapeCatalog.groups(forTier: tier)
        let total = groups.reduce(0) { $0 + $1.weight }
        var shape = PieceShape(["X"])
        for _ in 0..<(fitting ? 60 : 1) {
            var roll = Int.random(in: 0..<total, using: &rng)
            var chosen = groups[0]
            for g in groups {
                if roll < g.weight { chosen = g; break }
                roll -= g.weight
            }
            shape = chosen.variants[Int.random(in: 0..<chosen.variants.count, using: &rng)]
            if !fitting || fits(shape) { break }
            shape = PieceShape(["X"])
        }

        var specials: [Int: Special] = [:]
        let boost = tier >= 6 ? 2.0 : (tier >= 5 ? 1.5 : 1.0)
        let options: [(Special, Int, Double)] = [(.bomb, 2, 0.10), (.star, 3, 0.10), (.zap, 4, 0.07)]
        for (kind, minTier, chance) in options where tier >= minTier {
            if Double.random(in: 0..<1, using: &rng) < chance * boost {
                let i = Int.random(in: 0..<shape.cells.count, using: &rng)
                if specials[i] == nil { specials[i] = kind }
            }
        }

        return Piece(shape: shape,
                     color: Int.random(in: 0..<1000, using: &rng),
                     motif: Int.random(in: 0..<1000, using: &rng),
                     tier: tier, specials: specials)
    }

    /// Deal 3 new pieces that can always all be placed: there is an order and
    /// a spot for each where all three fit, counting rows/columns that clear
    /// in between. Tries random sets first; if none is solvable, builds one
    /// piece by piece on a simulated board.
    mutating func refillTray() {
        tray = solvableSet().map { Optional($0) }
    }

    mutating func solvableSet() -> [Piece] {
        let start = BitBoard(board)
        for _ in 0..<40 {
            let set = [randomPiece(), randomPiece(), randomPiece()]
            if BitBoard.solvable(start, set.map(\.shape)) { return set }
        }
        // Build one: each piece is chosen to fit the board left by the last.
        var sim = start
        var set: [Piece] = []
        for _ in 0..<3 {
            var chosen: Piece?
            for _ in 0..<60 {
                let p = randomPiece()
                let spots = sim.placements(p.shape)
                if !spots.isEmpty {
                    chosen = p
                    sim = sim.placing(spots[Int.random(in: 0..<spots.count, using: &rng)])
                    break
                }
            }
            if chosen == nil {
                // Last resort: a single block in any empty cell.
                var single = randomPiece()
                single = Piece(shape: PieceShape(["X"]), color: single.color, motif: single.motif,
                               tier: single.tier, specials: [:])
                let spots = sim.placements(single.shape)
                if let spot = spots.first { sim = sim.placing(spot) }
                chosen = single
            }
            set.append(chosen!)
        }
        return set.shuffled(using: &rng)
    }

    /// True if the pieces in the tray can all still be placed.
    var traySolvable: Bool {
        BitBoard.solvable(BitBoard(board), tray.compactMap { $0?.shape })
    }

    // MARK: Revive

    /// Clears the three fullest rows (stones holding gems stay put) and deals
    /// a fresh set that can all be placed.
    mutating func revive(withAd: Bool) {
        if withAd { adReviveUsed = true } else { goldRevivesUsed += 1 }
        let counts = board.map { row in row.filter { $0 != nil }.count }
        let rows = (0..<boardSize).sorted { counts[$0] > counts[$1] }.prefix(3)
        for r in rows {
            for c in 0..<boardSize where board[r][c]?.special != .gem {
                board[r][c] = nil
            }
        }
        streak = 0
        movesSinceClear = 0
        refillTray()
    }
}

// MARK: - Solver

/// The board as 64 bits (bit r*8+c set = filled), for fast "can these pieces
/// all be placed?" checks.
struct BitBoard: Equatable {
    var bits: UInt64

    init(bits: UInt64) { self.bits = bits }

    init(_ board: [[Block?]]) {
        var b: UInt64 = 0
        for r in 0..<boardSize { for c in 0..<boardSize where board[r][c] != nil { b |= 1 << UInt64(r * 8 + c) } }
        bits = b
    }

    static func mask(_ shape: PieceShape) -> UInt64 {
        shape.cells.reduce(UInt64(0)) { $0 | (1 << UInt64($1.r * 8 + $1.c)) }
    }

    /// Every spot the shape fits, as the mask it would fill.
    func placements(_ shape: PieceShape) -> [UInt64] {
        guard shape.width <= boardSize, shape.height <= boardSize else { return [] }
        let base = BitBoard.mask(shape)
        var out: [UInt64] = []
        for r in 0...(boardSize - shape.height) {
            for c in 0...(boardSize - shape.width) {
                let m = base << UInt64(r * 8 + c)
                if bits & m == 0 { out.append(m) }
            }
        }
        return out
    }

    static let rowMasks: [UInt64] = (0..<8).map { UInt64(0xFF) << UInt64($0 * 8) }
    static let colMasks: [UInt64] = (0..<8).map { UInt64(0x0101010101010101) << UInt64($0) }

    /// Fill `m`, then clear any full rows and columns.
    func placing(_ m: UInt64) -> BitBoard {
        let b = bits | m
        var clear: UInt64 = 0
        for rm in BitBoard.rowMasks where b & rm == rm { clear |= rm }
        for cm in BitBoard.colMasks where b & cm == cm { clear |= cm }
        return BitBoard(bits: b & ~clear)
    }

    /// Can all `shapes` be placed, in some order? Gives up (returns false)
    /// after `budget` board positions so a deal never stalls the game.
    static func solvable(_ board: BitBoard, _ shapes: [PieceShape], budget: Int = 40_000) -> Bool {
        var left = budget
        return search(board, shapes, &left)
    }

    private static func search(_ board: BitBoard, _ shapes: [PieceShape], _ left: inout Int) -> Bool {
        if shapes.isEmpty { return true }
        var tried = Set<PieceShape>()
        for i in shapes.indices where !tried.contains(shapes[i]) {
            tried.insert(shapes[i])
            var rest = shapes
            rest.remove(at: i)
            for m in board.placements(shapes[i]) {
                left -= 1
                if left <= 0 { return false }
                if search(board.placing(m), rest, &left) { return true }
            }
        }
        return false
    }
}
