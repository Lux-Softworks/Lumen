import SwiftUI
import WebKit

enum SettingsType {
    case browser
    case site
}

enum SettingsSection: Hashable {
    case main
    case globalSiteSettings
    case defaultBrowser
    case searchEngine
    case nativeApps
    case languages
    case privacyPolicy
    case displayOptions
    case siteSectionSettings
}

struct SettingsPage: View {
    var type: SettingsType
    var currentURL: URL?
    var onDismiss: () -> Void

    @StateObject private var settings = BrowserSettings.shared
    @Namespace private var engineNamespace
    @Namespace private var nativeAppsNamespace
    @State private var navigationPath: [SettingsSection] = []
    @State private var showClearDataAlert = false

    @State private var pageZoom: Int = 100
    @State private var requestDesktopSite: Bool = false
    @State private var translateEnabled: Bool = false
    @State private var sitePinned: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                mainView
                    .frame(width: width)
                    .offset(x: offsetFor(index: 0, width: width))
                    .opacity(opacityFor(index: 0))

                detailView(for: navigationPath.last ?? .main)
                    .frame(width: width)
                    .offset(x: offsetFor(index: 1, width: width))
                    .opacity(opacityFor(index: 1))
            }
            .animation(.smooth(duration: 0.3), value: navigationPath)
        }
        .clipped()
        .ignoresSafeArea(.keyboard)
        .alert("Clear Browsing Data?", isPresented: $showClearDataAlert) {
            Button("Clear", role: .destructive) { clearBrowsingData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear your history and all website data.")
        }
    }

    private var levelIndex: Int {
        return navigationPath.isEmpty ? 0 : 1
    }

    private func offsetFor(index: Int, width: CGFloat) -> CGFloat {
        if index == levelIndex { return 0 }
        if index < levelIndex { return -width * 0.25 }
        return width
    }

    private func opacityFor(index: Int) -> Double {
        if index == levelIndex { return 1.0 }
        if abs(index - levelIndex) == 1 { return 0.0 }
        return 0.0
    }

    private var mainView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if type == .browser {
                    browserSettingsContent
                } else if type == .site {
                    siteSettingsContent
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                detailHeader(for: section)

                switch section {
                    case .main:
                        EmptyView()
                    case .globalSiteSettings:
                        globalSiteSettingsList
                    case .searchEngine:
                        searchEngineList
                    case .nativeApps:
                        nativeAppsList
                    case .defaultBrowser:
                        defaultBrowserContent
                    case .languages:
                        languagesContent
                    case .privacyPolicy:
                        privacyPolicyContent
                    case .displayOptions:
                        displayOptionsContent
                    case .siteSectionSettings:
                        siteSectionSettingsList
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
    }

    private var browserSettingsContent: some View {
        VStack(spacing: 16) {
            settingsGroup {
                settingsRow(icon: "globe", title: "Global Site Settings", showChevron: true) {
                    push(.globalSiteSettings)
                }
            }

            settingsGroup {
                settingsRow(icon: "app.badge.checkmark", title: "Set as Default Browser", showChevron: true) {
                    push(.defaultBrowser)
                }
            }

            settingsGroup {
                settingsRow(
                    icon: "magnifyingglass",
                    title: "Search Engine",
                    subtitle: settings.searchEngine.rawValue,
                    showChevron: true
                ) { push(.searchEngine) }

                divider

                settingsRow(
                    icon: "arrow.up.forward.app",
                    title: "Open Native Apps",
                    subtitle: settings.nativeAppsPolicy.rawValue,
                    showChevron: true
                ) { push(.nativeApps) }

                divider

                settingsRow(
                    icon: "globe.americas",
                    title: "Languages",
                    subtitle: Locale.current.localizedString(
                        forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en"
                    ) ?? "English",
                    showChevron: true
                ) { push(.languages) }
            }

            settingsGroup {
                settingsRow(icon: "trash", title: "Clear Browsing Data", destructive: true) {
                    showClearDataAlert = true
                }
            }

            settingsGroup {
                settingsRow(icon: "hand.raised", title: "Privacy Policy", showChevron: true) {
                    push(.privacyPolicy)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var siteSettingsContent: some View {
        VStack(spacing: 16) {
            settingsGroup {
                settingsRow(icon: "textformat.size", title: "Display Options", showChevron: true) {
                    push(.displayOptions)
                }
                divider
                settingsRow(icon: "gearshape", title: "Site Settings", showChevron: true) {
                    push(.siteSectionSettings)
                }
            }

            settingsGroup {
                settingsRow(icon: "doc.text.magnifyingglass", title: "Find on Page", showChevron: false) {}
                divider
                settingsRow(icon: "pin", title: "Pin Site") {}
                divider
                settingsRow(icon: "square.and.arrow.up", title: "Share") {}
            }

            settingsGroup {
                settingsRow(icon: "brain.head.profile", title: "Collect Knowledge", isOn: $settings.collectKnowledge) {}
            }

            lumenFoundCard
        }
        .padding(.horizontal, 16)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.uiElement)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Colors.text.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var lumenFoundCard: some View {
        let trackers = 0
        let ads = 0

        var attributed = AttributedString("Lumen scrubbed ")
        var trackersNumber = AttributedString("\(trackers) ")
        trackersNumber.font = .system(size: 16, weight: .bold)
        trackersNumber.foregroundColor = AppTheme.Colors.accent

        var trackersLabel = AttributedString("trackers and ")
        trackersLabel.font = .system(size: 16, weight: .regular)
        trackersLabel.foregroundColor = AppTheme.Colors.text

        var adsNumber = AttributedString("\(ads) ")
        adsNumber.font = .system(size: 16, weight: .bold)
        adsNumber.foregroundColor = AppTheme.Colors.accent

        var adsLabel = AttributedString("ads")
        adsLabel.font = .system(size: 16, weight: .regular)
        adsLabel.foregroundColor = AppTheme.Colors.text

        var base = AttributedString("Lumen scrubbed ")
        base.font = .system(size: 16, weight: .regular)
        base.foregroundColor = AppTheme.Colors.text

        attributed = base + trackersNumber + trackersLabel + adsNumber + adsLabel

        return Text(attributed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.Colors.accent.opacity(0.07))
                }
            )
    }

    private var displayOptionsContent: some View {
        VStack(spacing: 16) {
            settingsGroup {
                settingsRow(
                    icon: "character.bubble",
                    title: "Translate",
                    subtitle: "Page language",
                    showChevron: true
                ) {}

                divider

                pageZoomRow

                divider

                settingsRow(
                    icon: "desktopcomputer",
                    title: "Request Desktop Site",
                    isOn: $requestDesktopSite
                ) {}
            }
        }
        .padding(.horizontal, 16)
    }

    private var pageZoomRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 32, height: 32)
                .cornerRadius(8)

            Text("Page Zoom")
                .font(AppTheme.Typography.sansBody(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.text)

            Spacer()

            HStack(spacing: 0) {
                Button {
                    withAnimation(.smooth(duration: 0.15)) {
                        if pageZoom > 50 { pageZoom -= 10 }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(pageZoom > 50 ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.2))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Text("\(pageZoom)%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.text)
                    .frame(minWidth: 58)
                    .monospacedDigit()

                Button {
                    withAnimation(.smooth(duration: 0.15)) {
                        if pageZoom < 200 { pageZoom += 10 }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(pageZoom < 200 ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.2))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .background(AppTheme.Colors.text.opacity(0.06))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var siteSectionSettingsList: some View {
        VStack(spacing: 16) {
            settingsGroup {
                settingsRow(icon: "shield", title: "Block Trackers", isOn: $settings.blockTrackers) {}
                divider
                settingsRow(icon: "app.badge", title: "Block Popups", isOn: $settings.blockPopups) {}
                divider
                settingsRow(icon: "terminal", title: "Enable JavaScript", isOn: $settings.enableJavaScript) {}
            }
        }
        .padding(.horizontal, 16)
    }

    private var globalSiteSettingsList: some View {
        VStack(spacing: 16) {
            settingsGroup {
                settingsRow(icon: "shield", title: "Block Trackers", isOn: $settings.blockTrackers) {}
                divider
                settingsRow(icon: "app.badge", title: "Block Popups", isOn: $settings.blockPopups) {}
                divider
                settingsRow(icon: "terminal", title: "Enable JavaScript", isOn: $settings.enableJavaScript) {}
            }
        }
        .padding(.horizontal, 16)
    }

    private var searchEngineList: some View {
        VStack(spacing: 16) {
            settingsGroup {
                let engines = SearchEngine.allCases
                ForEach(Array(engines.enumerated()), id: \.element) { index, engine in
                    let isSelected = settings.searchEngine == engine

                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            settings.searchEngine = engine
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.4))
                                .frame(width: 28)

                            Text(engine.rawValue)
                                .font(AppTheme.Typography.sansBody(size: 16, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.text)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < engines.count - 1 { divider }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var nativeAppsList: some View {
        VStack(spacing: 16) {
            settingsGroup {
                let policies = NativeAppsPolicy.allCases
                ForEach(Array(policies.enumerated()), id: \.element) { index, policy in
                    let isSelected = settings.nativeAppsPolicy == policy

                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            settings.nativeAppsPolicy = policy
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: policyIcon(policy))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.4))
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(policy.rawValue)
                                    .font(AppTheme.Typography.sansBody(size: 16, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.text)

                                Text(policyDescription(policy))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isSelected ? AppTheme.Colors.accent.opacity(0.8) : AppTheme.Colors.text.opacity(0.45))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < policies.count - 1 { divider }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func policyIcon(_ policy: NativeAppsPolicy) -> String {
        switch policy {
        case .ask: return "questionmark.circle"
        case .always: return "arrow.up.forward.app"
        case .never: return "lock.shield"
        }
    }

    private func policyDescription(_ policy: NativeAppsPolicy) -> String {
        switch policy {
        case .ask: return "Prompt each time a link tries to open an app"
        case .always: return "Always launch the native app when available"
        case .never: return "Open all links inside Lumen"
        }
    }

    private var languagesContent: some View {
        let languageName =
            Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en"
            ) ?? "English"

        return VStack(spacing: 16) {
            settingsGroup {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Colors.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageName)
                            .font(AppTheme.Typography.sansBody(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.text)
                        Text("System default")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.45))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.accent.opacity(0.1))
                        .padding(.horizontal, 8)
                )
            }

            Text(
                "Language preferences are managed in iOS language settings."
            )
            .font(.system(size: 13))
            .foregroundColor(AppTheme.Colors.text.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    private var defaultBrowserContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("Links you tap in other apps will open in Lumen instead of Safari when set to default.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            settingsGroup {
                VStack(spacing: 0) {
                    defaultBrowserStep(number: "1", text: "Tap the button below to open Settings")
                    stepDivider
                    defaultBrowserStep(number: "2", text: "Scroll down and tap \"Default Browser App\"")
                    stepDivider
                    defaultBrowserStep(number: "3", text: "Select Lumen from the list")
                }
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Open Settings")
                        .font(AppTheme.Typography.sansBody(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Colors.accent)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
    }

    private func defaultBrowserStep(number: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.accent.opacity(0.18))
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.Colors.accent)
            }

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.text.opacity(0.75))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var stepDivider: some View {
        Rectangle()
            .fill(AppTheme.Colors.accent.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last updated: 2026")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.text.opacity(0.45))
                .padding(.horizontal, 16)

            settingsGroup {
                VStack(spacing: 0) {
                    policySection(
                        title: "What We Collect",
                        body: "Lumen does not collect, transmit, or sell your browsing data. All history and preferences are stored locally on your device."
                    )
                    divider
                    policySection(
                        title: "Tracking Protection",
                        body: "Lumen blocks third-party trackers, fingerprinting scripts, and crypto miners to protect your privacy as you browse."
                    )
                    divider
                    policySection(
                        title: "Search Queries",
                        body: "When you search, your query is sent directly to your chosen search engine. Lumen does not intercept or log search terms."
                    )
                    divider
                    policySection(
                        title: "Data Storage",
                        body: "Browsing history, settings, and website data are stored only on your device and never leave it."
                    )
                    divider
                    policySection(
                        title: "Contact",
                        body: "Questions? Reach us through the App Store listing or our website."
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.text)
            Text(body)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.Colors.text.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailHeader(for section: SettingsSection) -> some View {
        ZStack {
            HStack {
                Button(action: pop) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.accent.opacity(0.1))
                    .cornerRadius(20)
                }
                Spacer()
            }

            Text(sectionTitle(for: section))
                .font(AppTheme.Typography.serifDisplay(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func sectionTitle(for section: SettingsSection) -> String {
        switch section {
        case .main: return ""
        case .globalSiteSettings: return "Global Settings"
        case .defaultBrowser: return "Default Browser"
        case .searchEngine: return "Search Engine"
        case .nativeApps: return "Open Native Apps"
        case .languages: return "Languages"
        case .privacyPolicy: return "Privacy Policy"
        case .displayOptions: return "Display Options"
        case .siteSectionSettings: return "Site Settings"
        }
    }

    private func push(_ section: SettingsSection) {
        navigationPath.append(section)
    }

    private func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    private func clearBrowsingData() {
        let dataTypes: Set<String> = [
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeWebSQLDatabases
        ]
        
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: .distantPast
        ) { }
        
        Task { @MainActor in
            HistoryStore.shared.clearAll()
        }
    }

    private var groupSpacer: some View {
        Spacer().frame(height: 24)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.Colors.text.opacity(0.08))
            .frame(height: 0.5)
            .padding(.leading, 60)
            .padding(.trailing, 0)
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = false,
        destructive: Bool = false,
        isOn: Binding<Bool>? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(destructive ? .red : AppTheme.Colors.accent)
                    .frame(width: 32, height: 32)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.sansBody(size: 16, weight: .medium))
                        .foregroundColor(destructive ? .red : AppTheme.Colors.text)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.45))
                    }
                }

                Spacer()

                if let isOnBinding = isOn {
                    ThemedToggle(isOn: isOnBinding)
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.25))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
