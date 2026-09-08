import SwiftUI

struct AdultConfirmationView: View {
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var appearance: AppearanceStore

    var body: some View {
        ZStack {
            Color.veilBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                VeilWordmark()
                Spacer()
                VeilSectionLabel(text: "Before you enter")
                    .padding(.bottom, 18)
                Text("A space of\nyour own.")
                    .font(.system(size: 52, weight: .medium, design: .default))
                    .tracking(-2.2)
                    .minimumScaleFactor(0.75)
                Text("Veil is for adults. This confirmation stays on this device and is never sent to the Veil API.")
                    .font(.body)
                    .foregroundStyle(Color.veilSecondary)
                    .lineSpacing(4)
                    .padding(.top, 22)
                Spacer()
                Button {
                    appFlow.confirmAdultStatement()
                } label: {
                    HStack {
                        Text("I confirm that I am 18 or older")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 58)
                    .background(appearance.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.veilBackground)
                }
                Text("Self-attestation does not verify your age.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }
}

struct AccountSetupView: View {
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var username = ""
    @State private var mode: AccountMode = .deviceOnly
    @State private var passphrase = ""
    @State private var showsDetails = false
    @State private var showsRecovery = false
    @State private var usesLocalServer = true

    private var canContinue: Bool {
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return (3...24).contains(handle.count)
            && handle.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            && (mode == .deviceOnly || passphrase.count >= 12)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VeilSectionLabel(text: "Choose how you return")
                    Text("Your account.\nYour terms.")
                        .font(.system(size: 43, weight: .medium))
                        .tracking(-1.7)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Public username").font(.subheadline.weight(.semibold))
                        TextField("your_handle", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .textContentType(.username)
                            .padding(15)
                            .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityHint("Three to twenty-four letters, numbers, underscores, or dots")
                    }

                    Picker("Data source", selection: $usesLocalServer) {
                        Text("Local server").tag(true)
                        Text("Demo data").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("The local server creates a real proof-of-concept account. Demo data stays on this device.")

                    VStack(spacing: 10) {
                        ForEach(AccountMode.allCases) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { mode = option }
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: mode == option ? "circle.inset.filled" : "circle")
                                        .foregroundStyle(mode == option ? appearance.accentColor : Color.veilSecondary)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(option.title).font(.headline)
                                        Text(option.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.veilSecondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(16)
                                .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(mode == option ? appearance.accentColor : Color.veilLine, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if mode == .recoverable {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Security passphrase").font(.subheadline.weight(.semibold))
                            SecureField("At least 12 characters", text: $passphrase)
                                .textContentType(.newPassword)
                                .padding(15)
                                .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
                            Text("The passphrase is sent only to your local Veil API over the configured connection and is stored there as a password verifier. It is never saved on this device.")
                                .font(.caption)
                                .foregroundStyle(Color.veilSecondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        showsDetails = true
                    } label: {
                        Label("How recovery works", systemImage: "key")
                    }
                    .foregroundStyle(appearance.accentColor)

                    if usesLocalServer {
                        Button {
                            showsRecovery = true
                        } label: {
                            Label("Recover an existing account", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(Color.veilSecondary)
                    }

                    Button {
                        if usesLocalServer {
                            Task {
                                await appFlow.createAccount(
                                    username: username,
                                    mode: mode,
                                    passphrase: mode == .recoverable ? passphrase : nil
                                )
                            }
                        } else {
                            appFlow.createLocalDemoAccount(username: username, mode: mode)
                        }
                    } label: {
                        HStack {
                            Text(appFlow.isWorking ? "Creating…" : "Enter Veil")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 56)
                    }
                    .background(appearance.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.veilBackground)
                    .disabled(!canContinue || appFlow.isWorking)

                    if let error = appFlow.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Text(usesLocalServer
                         ? "Connects to \(APIClient.configuredBaseURL.absoluteString). Change the address in Settings after setup."
                         : "Demo mode stays entirely on this device.")
                        .font(.caption)
                        .foregroundStyle(Color.veilSecondary)
                }
                .padding(24)
            }
            .background(Color.veilBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { VeilWordmark() }
            }
            .sheet(isPresented: $showsDetails) {
                RecoveryExplanationView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsRecovery) {
                RecoveryAccountView()
            }
        }
    }
}

struct RecoveryCodeView: View {
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var appearance: AppearanceStore
    let recoveryCode: String
    @State private var hasConfirmedStorage = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VeilSectionLabel(text: "Shown once")
                Text("Save your recovery code.")
                    .font(.system(size: 40, weight: .medium))
                    .tracking(-1.4)
                Text("You need this code and your security passphrase to recover the account. Keep them in separate places.")
                    .foregroundStyle(Color.veilSecondary)
                Text(recoveryCode)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(appearance.accentColor.opacity(0.5)) }
                ShareLink(item: recoveryCode) {
                    Label("Export securely", systemImage: "square.and.arrow.up")
                }
                Toggle("I saved it somewhere separate", isOn: $hasConfirmedStorage)
                Button("Continue") { appFlow.clearRecoveryCodeFromScreen() }
                    .buttonStyle(.borderedProminent)
                    .tint(appearance.accentColor)
                    .disabled(!hasConfirmedStorage)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
            }
            .padding(24)
            .background(Color.veilBackground.ignoresSafeArea())
            .navigationTitle("Recovery")
        }
    }
}

struct RecoveryAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appFlow: AppFlowStore
    @State private var username = ""
    @State private var passphrase = ""
    @State private var recoveryCode = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Security passphrase", text: $passphrase)
                    TextField("Recovery code", text: $recoveryCode, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Recovery revokes old Veil and Matrix sessions. Old encrypted history still needs a transfer from an existing device.")
                        .font(.caption)
                        .foregroundStyle(Color.veilSecondary)
                }
                if let error = appFlow.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Recover account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appFlow.isWorking ? "Recovering…" : "Recover") {
                        Task {
                            if await appFlow.recoverAccount(username: username, passphrase: passphrase, recoveryCode: recoveryCode) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(username.isEmpty || passphrase.count < 12 || recoveryCode.isEmpty || appFlow.isWorking)
                }
            }
        }
    }
}

struct RecoveryExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VeilSectionLabel(text: "Two independent secrets")
                    Text("Recovery requires both your security passphrase and a high-entropy recovery code.")
                        .font(.title2.weight(.medium))
                    explanation("1", "Keep the passphrase in your memory or password manager.")
                    explanation("2", "Keep the recovery code somewhere separate from your everyday device.")
                    explanation("3", "A successful recovery revokes old sessions and rotates the recovery code.")
                    Text("Recovering your social account without an old device does not restore historical encrypted messages.")
                        .font(.callout)
                        .foregroundStyle(Color.veilSecondary)
                }
                .padding(24)
            }
            .background(Color.veilBackground)
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func explanation(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.veilLabel(size: 10)).foregroundStyle(Color.veilSecondary)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
    }
}
