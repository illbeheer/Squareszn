import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

struct Motif {
    let emoji: String
    let top: Color
    let bottom: Color

    init(_ emoji: String, _ top: UInt32, _ bottom: UInt32) {
        self.emoji = emoji
        self.top = Color(hex: top)
        self.bottom = Color(hex: bottom)
    }
}

enum SkinKind: String {
    case classic = "Classic"
    case animals = "Animals"
    case scenery = "Scenery"
}

enum Rarity: String {
    case free = "Free"
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"

    var price: Int {
        switch self {
        case .free: return 0
        case .common: return 500
        case .rare: return 800
        case .epic: return 1200
        }
    }

    var color: Color {
        switch self {
        case .free: return .gray
        case .common: return Color(hex: 0x7FD67F)
        case .rare: return Color(hex: 0x5AB4FF)
        case .epic: return Color(hex: 0xC77DFF)
        }
    }
}

/// A skin changes how base blocks look (blocks made before the board has been
/// cleared). Each piece gets a random motif from the skin.
struct Skin: Identifiable {
    let id: String
    let name: String
    let kind: SkinKind
    let rarity: Rarity
    let motifs: [Motif]

    var price: Int { rarity.price }

    func motif(_ n: Int) -> Motif { motifs[abs(n) % motifs.count] }
}

enum SkinCatalog {
    /// Price of a random skin you don't own yet.
    static let mysteryPrice = 450

    static let all: [Skin] = [
        Skin(id: "classic", name: "Classic", kind: .classic, rarity: .free, motifs: [
            Motif("", 0xFF6B6B, 0xD63A3A), Motif("", 0xFFB45A, 0xE07B1A), Motif("", 0xFFE066, 0xE0B020),
            Motif("", 0x7BE07B, 0x2FA84F), Motif("", 0x5FE0E0, 0x1A9FB0), Motif("", 0x6BA8FF, 0x2F5FD6),
            Motif("", 0xC08BFF, 0x7B3FD6),
        ]),

        // Animals
        Skin(id: "forest", name: "Forest Friends", kind: .animals, rarity: .common, motifs: [
            Motif("🦊", 0xFFC58A, 0xF08A3C), Motif("🦉", 0xD9B99B, 0x9C7350), Motif("🐻", 0xE6C29F, 0xB0804F),
            Motif("🦔", 0xF2DDB6, 0xC9A66B), Motif("🐿️", 0xF7B78A, 0xC9703C),
        ]),
        Skin(id: "farm", name: "Farmyard", kind: .animals, rarity: .common, motifs: [
            Motif("🐮", 0xF5F5F5, 0xC9C9C9), Motif("🐷", 0xFFC9D6, 0xF58CA6), Motif("🐔", 0xFFF1B8, 0xF2C94C),
            Motif("🐑", 0xE8EEF5, 0xAEBCCC), Motif("🐴", 0xE0B68A, 0xA8733F),
        ]),
        Skin(id: "pets", name: "Pets", kind: .animals, rarity: .common, motifs: [
            Motif("🐶", 0xFFE0B3, 0xE8A75C), Motif("🐱", 0xFFD6A5, 0xF2994A), Motif("🐰", 0xFDE2F3, 0xE7A6CF),
            Motif("🐹", 0xFFEFD1, 0xE9C27C), Motif("🐦", 0xBDE4FF, 0x5AA9E6),
        ]),
        Skin(id: "ocean", name: "Ocean Life", kind: .animals, rarity: .rare, motifs: [
            Motif("🐙", 0xFFB3C1, 0xE0607E), Motif("🐠", 0x9FE7FF, 0x2FA4D9), Motif("🐬", 0xB8D8FF, 0x4F86E0),
            Motif("🐳", 0x9ED0F5, 0x2C6FB3), Motif("🦀", 0xFFB49A, 0xE0583A),
        ]),
        Skin(id: "safari", name: "Safari", kind: .animals, rarity: .rare, motifs: [
            Motif("🦁", 0xFFD98A, 0xE0A030), Motif("🐘", 0xD3D9E0, 0x8C99A6), Motif("🦒", 0xFFE3A3, 0xD9A440),
            Motif("🦓", 0xF0F0F0, 0x9A9A9A), Motif("🦛", 0xE3C8E6, 0xA67DB0),
        ]),
        Skin(id: "polar", name: "Polar", kind: .animals, rarity: .rare, motifs: [
            Motif("🐧", 0xDDEBFF, 0x7FA6D9), Motif("🐻‍❄️", 0xF2F8FF, 0xB7CCE6), Motif("🦭", 0xD6E2EA, 0x8FA7B8),
            Motif("🐺", 0xD0D7E0, 0x7D8A99), Motif("🦌", 0xE8CDB0, 0xAD7F55),
        ]),
        Skin(id: "jungle", name: "Jungle", kind: .animals, rarity: .epic, motifs: [
            Motif("🐒", 0xE8C49A, 0xA9733F), Motif("🦜", 0xFF9B8A, 0x2FB86A), Motif("🐯", 0xFFC27A, 0xF07B1F),
            Motif("🐸", 0xB4F0A0, 0x4FBF3A), Motif("🦥", 0xD9C7A8, 0x8F7A55),
        ]),
        Skin(id: "dino", name: "Dino Land", kind: .animals, rarity: .epic, motifs: [
            Motif("🦖", 0xB8F08A, 0x4CAF50), Motif("🦕", 0x9FE3D0, 0x2E9C8A), Motif("🐊", 0xC8E69A, 0x6E9E3A),
            Motif("🐢", 0xD6F0A8, 0x7DB04A), Motif("🦎", 0xE6F59A, 0x9EBF2A),
        ]),

        // Scenery
        Skin(id: "mountains", name: "Mountains", kind: .scenery, rarity: .common, motifs: [
            Motif("🏔️", 0xBFE3FF, 0x6FA8DC), Motif("⛰️", 0xCDE8C8, 0x6E9E6A), Motif("🌄", 0xFFD1A6, 0xE08A6A),
            Motif("🗻", 0xD6E6FF, 0x8FA9D9),
        ]),
        Skin(id: "beach", name: "Beach Day", kind: .scenery, rarity: .common, motifs: [
            Motif("🏖️", 0xFFF0C2, 0xF2C46A), Motif("🌊", 0x9FE7FF, 0x2F8FD9), Motif("🌴", 0xC9F2B8, 0x4FB86A),
            Motif("🐚", 0xFFE0E6, 0xF0A6B8),
        ]),
        Skin(id: "blossom", name: "Blossom", kind: .scenery, rarity: .common, motifs: [
            Motif("🌸", 0xFFE0EC, 0xF59AC0), Motif("🌷", 0xFFD1D9, 0xE8607E), Motif("🌼", 0xFFF6C2, 0xF2CF4A),
            Motif("🌺", 0xFFC9C0, 0xE85A4F),
        ]),
        Skin(id: "woodland", name: "Woodland", kind: .scenery, rarity: .rare, motifs: [
            Motif("🌲", 0xB8E6B0, 0x2F7D4A), Motif("🌳", 0xCDEFAA, 0x5A9E3A), Motif("🍄", 0xFFD6CC, 0xD9483A),
            Motif("🍁", 0xFFD39A, 0xE0702A),
        ]),
        Skin(id: "desert", name: "Desert", kind: .scenery, rarity: .rare, motifs: [
            Motif("🌵", 0xFFE8B8, 0xD9A55A), Motif("🏜️", 0xFFD6A0, 0xE09A4F), Motif("🐪", 0xFFE3C2, 0xC98F55),
            Motif("☀️", 0xFFF3A6, 0xF2B33D),
        ]),
        Skin(id: "nightsky", name: "Night Sky", kind: .scenery, rarity: .rare, motifs: [
            Motif("🌙", 0x5B6BB8, 0x1E2659), Motif("⭐", 0x4A5AA8, 0x1A1F4D), Motif("🌌", 0x6A4FA8, 0x23164D),
            Motif("🪐", 0x5A7FC2, 0x1C2E66),
        ]),
        Skin(id: "sunset", name: "Sunset", kind: .scenery, rarity: .epic, motifs: [
            Motif("🌅", 0xFFC27A, 0xE0507A), Motif("🌇", 0xFFA07A, 0x9A3FA0), Motif("🏝️", 0xFFD08A, 0xE0607A),
            Motif("🌆", 0xF58A8A, 0x6A3FA0),
        ]),
        Skin(id: "aurora", name: "Aurora", kind: .scenery, rarity: .epic, motifs: [
            Motif("🌌", 0x4FE0B0, 0x2A2F7A), Motif("❄️", 0x8AF0E0, 0x3A4FA0), Motif("🏔️", 0x9AE6FF, 0x5A3FA0),
            Motif("✨", 0x7AF0A0, 0x3F2F8A),
        ]),
    ]

    static func skin(_ id: String) -> Skin { all.first { $0.id == id } ?? all[0] }
}

/// Colors for the block sets unlocked by clearing the board.
enum TierPalette {
    static let colors: [Color] = [
        Color(hex: 0xFF5D73), Color(hex: 0xFF9F43), Color(hex: 0xFFD93D), Color(hex: 0x4CD97B),
        Color(hex: 0x3DD6F5), Color(hex: 0x4D7CFF), Color(hex: 0xB45DFF),
    ]

    static func color(_ n: Int) -> Color { colors[abs(n) % colors.count] }
}

enum SeasonTheme {
    static func colors(_ season: Int) -> [Color] {
        switch season {
        case 0: return [Color(hex: 0x3A1F4D), Color(hex: 0x7A3F6E)]
        case 1: return [Color(hex: 0x123A5A), Color(hex: 0x1E7A8C)]
        case 2: return [Color(hex: 0x3D2414), Color(hex: 0x8C4A1E)]
        default: return [Color(hex: 0x1A2A4D), Color(hex: 0x4D6A99)]
        }
    }

    static func accent(_ season: Int) -> Color {
        switch season {
        case 0: return Color(hex: 0xFF9FD0)
        case 1: return Color(hex: 0xFFD93D)
        case 2: return Color(hex: 0xFF9F43)
        default: return Color(hex: 0x9FE3FF)
        }
    }

    static let infinite = [Color(hex: 0x141A3A), Color(hex: 0x2A2F6A)]
}
