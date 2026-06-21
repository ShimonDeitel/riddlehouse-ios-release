import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @AppStorage("riddlehouse.theme") private var themeRaw = AppTheme.system.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        HomeView()
            .preferredColorScheme(theme.colorScheme)
            .onChange(of: store.isPro) { _, _ in appModel.refresh() }
    }
}
