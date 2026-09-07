import SwiftUI

struct VeiledActivityView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var appFlow: AppFlowStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        VeilSectionLabel(text: "Private to this app")
                        HStack {
                            Text("The things you’ve\nsaid behind the veil.")
                                .font(.system(size: 31, weight: .medium))
                                .tracking(-1.1)
                            Spacer()
                            SigilView(seed: 83, size: 60, color: appearance.accentColor)
                        }
                        Text("Anonymous posts, comments, and conversations never appear on your public profile.")
                            .font(.callout)
                            .foregroundStyle(Color.veilSecondary)
                            .lineSpacing(3)
                    }
                    .padding(20)
                    VeilDivider()

                    if store.veiledActivity.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "hexagon").font(.largeTitle).foregroundStyle(appearance.accentColor)
                            Text("A quiet space for your veiled activity.").font(.headline)
                            Text("Create an anonymous post and it will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(Color.veilSecondary)
                        }
                        .padding(40)
                    } else {
                        ForEach(store.veiledActivity) { post in PostCardView(post: post) }
                    }
                }
            }
            .background(Color.veilBackground)
            .navigationTitle("Veiled Activity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { PublicProfileView() } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Public profile")
                }
            }
        }
    }
}

struct PublicProfileView: View {
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore

    private var attributedPosts: [DemoPost] {
        store.posts.filter { $0.isMine && !$0.actor.isAnonymous }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        ActorBadge(actor: .profile(handle: appFlow.username, displayName: appFlow.username), size: 72)
                        Spacer()
                        NavigationLink("Settings") { PrivacySettingsView() }
                            .buttonStyle(.bordered)
                    }
                    Text(appFlow.username).font(.title.bold())
                    Text("Looking for quieter corners of the city.")
                        .font(.body)
                        .foregroundStyle(Color.veilSecondary)
                    HStack(spacing: 24) {
                        Label("128 followers", systemImage: "person.2")
                        Label("94 following", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
                }
                .padding(20)
                VeilDivider()
                ForEach(attributedPosts) { post in PostCardView(post: post) }
            }
        }
        .background(Color.veilBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var appearance: AppearanceStore
    @AppStorage("veil.preference.blurSensitive") private var blursSensitiveMedia = true
    @AppStorage("veil.preference.readReceipts") private var readReceipts = false
    @AppStorage("veil.preference.typing") private var typingIndicators = false
    @AppStorage("veil.preference.anonymousRequests") private var requestPolicy = AnonymousRequestPolicy.filtered.rawValue
    @State private var keyword = ""
    @State private var mutedKeywords: [String] = []
    @State private var showsResetConfirmation = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance.appearance) {
                    ForEach(VeilAppearance.allCases) { Text($0.title).tag($0) }
                }
                Picker("Accent", selection: $appearance.accent) {
                    ForEach(VeilAccent.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Content") {
                Toggle("Blur sensitive media", isOn: $blursSensitiveMedia)
                HStack {
                    TextField("Mute a keyword", text: $keyword)
                    Button("Add") {
                        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        mutedKeywords.append(value)
                        keyword = ""
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(mutedKeywords, id: \.self) { value in
                    Text(value).foregroundStyle(Color.veilSecondary)
                }
                .onDelete { mutedKeywords.remove(atOffsets: $0) }
            }

            Section("Messages") {
                Picker("Anonymous requests", selection: $requestPolicy) {
                    ForEach(AnonymousRequestPolicy.allCases) { policy in
                        Text(policy.title).tag(policy.rawValue)
                    }
                }
                Toggle("Read receipts", isOn: $readReceipts)
                Toggle("Typing indicators", isOn: $typingIndicators)
                Text("Receipts and typing indicators start off. Anonymous requests start filtered.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
            }

            Section("Account") {
                LabeledContent("Mode", value: appFlow.accountMode.title)
                NavigationLink("Recovery and device access") { RecoveryExplanationView() }
                Button("Reset local demo account", role: .destructive) { showsResetConfirmation = true }
            }

            Section {
                Text("Demo preferences stay on this device. The adult confirmation remains in Keychain and is never included in API models.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.veilBackground)
        .navigationTitle("Privacy controls")
        .confirmationDialog("Reset the local demo account?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("Reset local demo", role: .destructive) { appFlow.resetLocalDemoAccount() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the locally saved demo username and account mode. It does not delete the Keychain adult confirmation.")
        }
    }
}
