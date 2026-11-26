import SwiftUI

/// Everything saved on the device: gold, skins, best score, Season progress.
struct SaveData: Codable {
    var gold = 100
    var bestScore = 0
    var ownedSkins: Set<String> = ["classic"]
    var selectedSkin = "classic"
    /// Number of Season levels cleared, in order. Level N is open when N <= this.
    var seasonCleared = 0
    var totalBoardClears = 0
}

final class PlayerStore: ObservableObject {
    @Published var data: SaveData {
        didSet { save() }
    }

    private static let key = "squareszn.save.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = decoded
        } else {
            data = SaveData()
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: Self.key)
        }
    }

    var skin: Skin { SkinCatalog.skin(data.selectedSkin) }

    func addGold(_ amount: Int) {
        guard amount != 0 else { return }
        data.gold += amount
    }

    func spend(_ amount: Int) -> Bool {
        guard data.gold >= amount else { return false }
        data.gold -= amount
        return true
    }

    // MARK: Skins

    func owns(_ skin: Skin) -> Bool { data.ownedSkins.contains(skin.id) }

    func buy(_ skin: Skin) -> Bool {
        guard !owns(skin), spend(skin.price) else { return false }
        data.ownedSkins.insert(skin.id)
        data.selectedSkin = skin.id
        return true
    }

    var unownedSkins: [Skin] { SkinCatalog.all.filter { !owns($0) } }

    /// Buys a random skin you don't own yet. Returns it, or nil if not affordable.
    func buyMystery() -> Skin? {
        guard let pick = unownedSkins.randomElement(), spend(SkinCatalog.mysteryPrice) else { return nil }
        data.ownedSkins.insert(pick.id)
        data.selectedSkin = pick.id
        return pick
    }

    func select(_ skin: Skin) {
        if owns(skin) { data.selectedSkin = skin.id }
    }

    // MARK: Results

    /// Records an Infinite score. Returns true for a new best.
    func recordScore(_ score: Int) -> Bool {
        if score > data.bestScore {
            data.bestScore = score
            return true
        }
        return false
    }

    func isUnlocked(_ level: SeasonLevel) -> Bool { level.number <= data.seasonCleared }
    func isCleared(_ level: SeasonLevel) -> Bool { level.number < data.seasonCleared }

    /// Pays out a cleared Season level. First clears pay well (more in later
    /// seasons, plus a bonus for finishing a season); replays pay a little.
    func completeLevel(_ level: SeasonLevel) -> Int {
        var reward: Int
        if level.number == data.seasonCleared {
            reward = 40 + 15 * level.season + (level.isBoss ? 60 : 0)
            if level.isBoss { reward += 150 }
            data.seasonCleared += 1
        } else {
            reward = 10
        }
        addGold(reward)
        return reward
    }
}
