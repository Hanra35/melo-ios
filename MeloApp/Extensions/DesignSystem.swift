import SwiftUI

// MARK: - Design Tokens
extension Color {
    static let meloBg        = Color("MeloBg")
    static let meloCard      = Color("MeloCard")
    static let meloCard2     = Color("MeloCard2")
    static let meloAccent    = Color(hex: "#4DCFBF")
    static let meloOrange    = Color(hex: "#FF8A65")
    static let meloSub       = Color(hex: "#7A8799")
    static let meloText      = Color(hex: "#E6EAF4")
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(hue: Double) {
        self.init(hue: hue / 360.0, saturation: 0.55, brightness: 0.72)
    }
}

// MARK: - Track Art View
struct TrackArtView: View {
    let track: Track
    var size: CGFloat = 50
    var cornerRadius: CGFloat = 13

    var body: some View {
        Group {
            if let url = URL(string: track.imgUrl), !track.imgUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholderArt
                    }
                }
            } else {
                placeholderArt
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholderArt: some View {
        ZStack {
            Color(hue: track.hue)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Haptics
struct Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - View Modifiers
extension View {
    func cardStyle() -> some View {
        self
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
    }
}
