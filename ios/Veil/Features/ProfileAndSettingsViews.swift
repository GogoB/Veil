import SwiftUI
import VeilShared

struct VeiledActivityView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var appFlow: AppFlowStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !store.collaborationInvitations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            VeilSectionLabel(text: "Collaboration invitations")
                            ForEach(store.collaborationInvitations) { invitation in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("@\(invitation.creator.username) invited you")
                                        .font(.headline)
                                    Text(invitation.excerpt)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.veilSecondary)
                                        .lineLimit(3)
                                    if invitation.visibility == .anonymous {
                                        Label("Owners and owner count stay hidden", systemImage: "eye.slash")
                                            .font(.caption)
                                            .foregroundStyle(Color.veilSecondary)
                                    }
                                    Button("Accept and publish") {
                                        Task { await store.acceptCollaboration(invitation) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(14)
                                .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(20)
                        VeilDivider()
                    }
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
    @State private var editsBio = false
    @State private var bioDraft = ""

    private var attributedPosts: [DemoPost] {
        store.currentProfile == nil
            ? store.posts.filter { $0.isMine && !$0.actor.isAnonymous }
            : store.currentProfilePosts
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
                    Text(store.currentProfile?.username ?? appFlow.username).font(.title.bold())
                    Text(store.currentProfile?.bio ?? "Looking for quieter corners of the city.")
                        .font(.body)
                        .foregroundStyle(Color.veilSecondary)
                    HStack(spacing: 24) {
                        Label("\(store.currentProfile?.followerCount ?? 128) followers", systemImage: "person.2")
                        Label("\(store.currentProfile?.followingCount ?? 94) following", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
                    if store.currentProfile != nil {
                        Button("Edit bio") {
                            bioDraft = store.currentProfile?.bio ?? ""
                            editsBio = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
                VeilDivider()
                ForEach(attributedPosts) { post in PostCardView(post: post) }
            }
        }
        .background(Color.veilBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editsBio) {
            NavigationStack {
                Form {
                    TextEditor(text: $bioDraft)
                        .frame(minHeight: 150)
                    Text("\(bioDraft.count)/300")
                        .font(.caption)
                        .foregroundStyle(bioDraft.count > 300 ? Color.red : Color.veilSecondary)
                }
                .navigationTitle("Edit bio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editsBio = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await store.updateBio(bioDraft)
                                editsBio = false
                            }
                        }
                        .disabled(bioDraft.count > 300)
                    }
                }
            }
        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var store: DemoSocialStore
    @AppStorage("veil.preference.blurSensitive") private var blursSensitiveMedia = true
    @AppStorage("veil.preference.readReceipts") private var readReceipts = false
    @AppStorage("veil.preference.typing") private var typingIndicators = false
    @AppStorage("veil.preference.anonymousRequests") private var requestPolicy = AnonymousRequestPolicy.filtered.rawValue
    @AppStorage("veil.api.base-url") private var apiBaseURL = "http://127.0.0.1:8080"
    @AppStorage("veil.preference.mutedKeywords") private var mutedKeywordsStorage = ""
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

            Section("Local server") {
                TextField("API address", text: $apiBaseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Text("Use your Windows host LAN address on a physical iPhone. Restart Veil after changing it.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
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
                NavigationLink("Transfer encrypted message history") { MessageKeyTransferView() }
                Button("Sign out on this device", role: .destructive) { showsResetConfirmation = true }
            }

            Section {
                Text("The adult confirmation remains in Keychain and is never included in API models.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.veilBackground)
        .navigationTitle("Privacy controls")
        .onAppear {
            mutedKeywords = mutedKeywordsStorage.split(separator: "\n").map(String.init)
        }
        .onChange(of: mutedKeywords) { values in
            mutedKeywordsStorage = values.joined(separator: "\n")
        }
        .onDisappear {
            guard let policy = VeilShared.AnonymousRequestPolicy(rawValue: requestPolicy) else { return }
            Task {
                await store.savePreferences(
                    mutedKeywords: Set(mutedKeywords),
                    blurSensitiveMedia: blursSensitiveMedia,
                    anonymousRequestPolicy: policy
                )
            }
        }
        .confirmationDialog("Sign out on this device?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await appFlow.signOut() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Device-only accounts cannot be recovered after the last enrolled device is lost. The local adult confirmation stays in Keychain.")
        }
    }
}

private struct MessageKeyTransferView: View {
    @EnvironmentObject private var messagingStore: MessagingStore
    @State private var exportedKey: String?
    @State private var importedKey = ""
    @State private var status: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section("From this device") {
                Text("Export only while you still have an old device that can decrypt your history.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
                Button(isWorking ? "Preparing…" : "Prepare transfer key") {
                    isWorking = true
                    Task {
                        do {
                            exportedKey = try await messagingStore.exportMessageRecoveryKey()
                            status = "Transfer key ready. Keep it private."
                        } catch { status = error.localizedDescription }
                        isWorking = false
                    }
                }
                .disabled(isWorking)
                if let exportedKey {
                    Text(exportedKey)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    ShareLink(item: exportedKey) {
                        Label("Export securely", systemImage: "square.and.arrow.up")
                    }
                }
            }
            Section("On the replacement device") {
                SecureField("Transfer key", text: $importedKey)
                Button("Import message history key") {
                    isWorking = true
                    Task {
                        do {
                            try await messagingStore.importMessageRecoveryKey(importedKey)
                            importedKey = ""
                            status = "Encrypted history key imported."
                        } catch { status = error.localizedDescription }
                        isWorking = false
                    }
                }
                .disabled(importedKey.isEmpty || isWorking)
            }
            if let status { Section { Text(status) } }
            Section {
                Text("Social-account recovery alone cannot decrypt old messages. This transfer key is separate from the Veil recovery code.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
            }
        }
        .navigationTitle("Message history")
    }
}
