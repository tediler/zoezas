// Zoëzas – Homescreen- und Sperrbildschirm-Widget (WidgetKit).
//
// Liest den Stand, den die Flutter-App über home_widget in die gemeinsame
// App Group schreibt (lib/platform/platform_integration.dart), und öffnet per
// Tipp direkt die Schnelleingabe: zoezas://add?type=expense&homeWidget
// (der Parameter „homeWidget“ ist nötig, damit home_widget den Link erkennt).
//
// Einrichtung in Xcode: siehe docs/IOS_WIDGET.md

import SwiftUI
import WidgetKit

private let appGroup = "group.de.hilsenbeck.zoezas"
private let expenseURL = URL(string: "zoezas://add?type=expense&homeWidget")!
private let incomeURL = URL(string: "zoezas://add?type=income&homeWidget")!

private extension Color {
    static let zBackground = Color(red: 0.976, green: 0.918, blue: 0.945)
    static let zText = Color(red: 0.161, green: 0.141, blue: 0.165)
    static let zSecondary = Color(red: 0.557, green: 0.522, blue: 0.545)
    static let zAccent = Color(red: 0.851, green: 0.537, blue: 0.745)
    static let zAccentDeep = Color(red: 0.769, green: 0.435, blue: 0.667)
    static let zAccentSoft = Color(red: 0.965, green: 0.882, blue: 0.933)
    static let zNegative = Color(red: 0.851, green: 0.439, blue: 0.494)
}

struct ZoezasEntry: TimelineEntry {
    let date: Date
    let available: String
    let forecast: String
    let negative: Bool
}

struct ZoezasProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZoezasEntry {
        ZoezasEntry(date: .now, available: "1.750,00 €", forecast: "Bis 31. Okt.: 620 €", negative: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZoezasEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZoezasEntry>) -> Void) {
        // Die App stößt Aktualisierungen selbst an (HomeWidget.updateWidget).
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> ZoezasEntry {
        let data = UserDefaults(suiteName: appGroup)
        return ZoezasEntry(
            date: .now,
            available: data?.string(forKey: "available") ?? "—",
            forecast: data?.string(forKey: "forecast") ?? "Öffne Zoëzas, um loszulegen",
            negative: data?.string(forKey: "negative") == "true"
        )
    }
}

struct ZoezasWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ZoezasEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
            }
            .widgetURL(expenseURL)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Verfügbar").font(.caption2)
                Text(entry.available)
                    .font(.system(.headline, design: .serif))
                    .minimumScaleFactor(0.6)
                Text("Tippen für neue Ausgabe").font(.caption2)
            }
            .widgetURL(expenseURL)
        case .systemMedium:
            HStack(alignment: .center, spacing: 16) {
                summary
                VStack(spacing: 8) {
                    Link(destination: expenseURL) { pill("+ Ausgabe", primary: true) }
                    Link(destination: incomeURL) { pill("+ Einnahme", primary: false) }
                }
                .frame(width: 118)
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                summary
                Spacer(minLength: 6)
                pill("+ Ausgabe", primary: true)
            }
            .widgetURL(expenseURL)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("VERFÜGBAR")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(.zSecondary)
                Spacer()
                Text("Zoëzas")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.zAccentDeep)
            }
            Text(entry.available)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundColor(entry.negative ? .zNegative : .zText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(entry.forecast)
                .font(.system(size: 11))
                .foregroundColor(.zSecondary)
                .lineLimit(1)
        }
    }

    private func pill(_ title: String, primary: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(primary ? .white : .zAccentDeep)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                Capsule().fill(
                    primary
                        ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.898, green: 0.612, blue: 0.796), .zAccentDeep],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.zAccentSoft)
                )
            )
    }
}

struct ZoezasWidget: Widget {
    // Muss zu PlatformIntegration.iOSWidget in Dart passen.
    let kind = "ZoezasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZoezasProvider()) { entry in
            if #available(iOS 17.0, *) {
                ZoezasWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(colors: [.white, Color(red: 0.988, green: 0.929, blue: 0.961)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
            } else {
                ZoezasWidgetView(entry: entry)
                    .padding()
                    .background(Color.white)
            }
        }
        .configurationDisplayName("Zoëzas")
        .description("Verfügbares Guthaben und schnell eine Ausgabe eintragen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ZoezasWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZoezasWidget()
    }
}
