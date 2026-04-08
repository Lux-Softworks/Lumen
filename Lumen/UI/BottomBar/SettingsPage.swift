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

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                mainView
                    .frame(width: geometry.size.width)

                detailView(for: navigationPath.last ?? .main)
                    .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width * 2, alignment: .leading)
            .offset(x: navigationPath.isEmpty ? 0 : -geometry.size.width)
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
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
    }

    private var browserSettingsContent: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "globe", title: "Global Site Settings", showChevron: true) {
                push(.globalSiteSettings)
            }

            groupSpacer

            settingsRow(icon: "app.badge.checkmark", title: "Set as Default Browser", showChevron: true) {
                push(.defaultBrowser)
            }

            divider

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

            groupSpacer

            settingsRow(icon: "trash", title: "Clear Browsing Data", destructive: true) {
                showClearDataAlert = true
            }

            groupSpacer

            settingsRow(icon: "hand.raised", title: "Privacy Policy", showChevron: true) {
                push(.privacyPolicy)
            }
        }
    }

    private var siteSettingsContent: some View {
        EmptyView()
    }

    private var globalSiteSettingsList: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "shield", title: "Block Trackers", isOn: $settings.blockTrackers) {}
            divider
            settingsRow(icon: "app.badge", title: "Block Popups", isOn: $settings.blockPopups) {}
            divider
            settingsRow(icon: "terminal", title: "Enable JavaScript", isOn: $settings.enableJavaScript) {}
        }
    }

    private var searchEngineList: some View {
        VStack(spacing: 0) {
            ForEach(SearchEngine.allCases) { engine in
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
                            .foregroundColor(AppTheme.Colors.text)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.Colors.accent.opacity(0.1))
                                    .matchedGeometryEffect(id: "enginePill", in: engineNamespace)
                                    .padding(.horizontal, 8)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nativeAppsList: some View {
        VStack(spacing: 0) {
            ForEach(NativeAppsPolicy.allCases) { policy in
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
                                .foregroundColor(AppTheme.Colors.text)

                            Text(policyDescription(policy))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(AppTheme.Colors.text.opacity(0.45))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.Colors.accent.opacity(0.1))
                                    .matchedGeometryEffect(id: "nativePill", in: nativeAppsNamespace)
                                    .padding(.horizontal, 8)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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

        return VStack(spacing: 0) {
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

            Spacer().frame(height: 20)

            Text(
                "Language preferences are managed in iOS language settings."
            )
            .font(.system(size: 13))
            .foregroundColor(AppTheme.Colors.text.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }
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

            VStack(spacing: 0) {
                defaultBrowserStep(number: "1", text: "Tap the button below to open Settings")
                stepDivider
                defaultBrowserStep(number: "2", text: "Scroll down and tap \"Default Browser App\"")
                stepDivider
                defaultBrowserStep(number: "3", text: "Select Lumen from the list")
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.06))
            )
            .padding(.horizontal, 4)

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
            .padding(.horizontal, 4)
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

            policySection(
                title: "What We Collect",
                body: "Lumen does not collect, transmit, or sell your browsing data. All history and preferences are stored locally on your device."
            )

            policySection(
                title: "Tracking Protection",
                body: "Lumen blocks third-party trackers, fingerprinting scripts, and crypto miners to protect your privacy as you browse."
            )

            policySection(
                title: "Search Queries",
                body: "When you search, your query is sent directly to your chosen search engine. Lumen does not intercept or log search terms."
            )

            policySection(
                title: "Data Storage",
                body: "Browsing history, settings, and website data are stored only on your device and never leave it."
            )

            policySection(
                title: "Contact",
                body: "Questions? Reach us through the App Store listing or our website."
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.Colors.text)
            Text(body)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.text.opacity(0.04))
        )
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
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
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
            .padding(.horizontal, 24)
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(destructive ? .red : AppTheme.Colors.accent)
                    .frame(width: 32, height: 32)
                    .background((destructive ? Color.red : AppTheme.Colors.accent).opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.sansBody(size: 16, weight: .semibold))
                        .foregroundColor(destructive ? .red : AppTheme.Colors.text)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.5))
                    }
                }

                Spacer()

                if let isOnBinding = isOn {
                    ThemedToggle(isOn: isOnBinding)
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
