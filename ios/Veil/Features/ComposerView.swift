import PhotosUI
import SwiftUI
import UIKit

struct ComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var appFlow: AppFlowStore

    @State private var identity: PostIdentityChoice = .anonymous
    @State private var anonymousMode: AnonymousPresentationMode = .generatedAlias
    @State private var generatedAlias = "quiet frequency"
    @State private var customAlias = ""
    @State private var sigilSeed = 17
    @State private var bodyText = ""
    @State private var topic: Topic? = .afterHours
    @State private var expiration: PostExpiration = .oneDay
    @State private var isSensitive = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @State private var isProcessingImages = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case body, alias }
    private let aliases = ["quiet frequency", "low orbit", "paper satellite", "soft eclipse", "distant signal", "silver hour"]

    private var canPost: Bool {
        (!bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty)
            && bodyText.count <= 2_000
            && !isProcessingImages
    }

    private var activeName: String {
        switch identity {
        case .profile: return appFlow.username
        case .anonymous:
            switch anonymousMode {
            case .generatedAlias: return generatedAlias
            case .customAlias: return customAlias.isEmpty ? "your chosen alias" : customAlias
            case .sigil: return "a thread-only sigil"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identityHero
                    identityPicker

                    if identity == .anonymous {
                        anonymousControls
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        profileIdentity
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    writingArea
                    imagePreviews
                    composerTools
                    VeilDivider()
                    options
                    VeilDivider()

                    Label(
                        identity == .anonymous
                            ? "This post won’t appear on your public profile."
                            : "This post appears on your public profile.",
                        systemImage: identity == .anonymous ? "eye.slash" : "person.crop.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(Color.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("Composer error: \(errorMessage)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.veilBackground)
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        publish()
                    } label: {
                        Label("Post", systemImage: "arrow.up.right")
                            .fontWeight(.semibold)
                    }
                    .disabled(!canPost)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 9) {
                    if identity == .anonymous {
                        SigilView(seed: sigilSeed, size: 18, color: appearance.accentColor)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(appearance.accentColor)
                    }
                    Text("Posting as ") + Text(activeName).bold()
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(appearance.accentColor)
                }
                .font(.caption)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .onChange(of: pickerItems) { newItems in
                Task { await prepareImages(newItems) }
            }
        }
    }

    private var identityHero: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 9) {
                VeilSectionLabel(text: "Your voice. Your choice.")
                Text(identity == .anonymous ? "Behind\nthe veil." : "In your\nown name.")
                    .font(.system(size: 42, weight: .medium))
                    .tracking(-1.7)
                    .lineSpacing(-2)
            }
            Spacer()
            ZStack(alignment: .topLeading) {
                SigilView(seed: sigilSeed, size: 76, color: appearance.accentColor)
                    .opacity(identity == .anonymous ? 1 : 0)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(appearance.accentColor)
                    .opacity(identity == .profile ? 1 : 0)
                CornerMarks()
                    .stroke(appearance.accentColor, lineWidth: 1)
                    .frame(width: 100, height: 100)
            }
            .frame(width: 100, height: 100)
            .accessibilityHidden(true)
        }
        .padding(.top, 16)
    }

    private var identityPicker: some View {
        HStack(spacing: 4) {
            ForEach(PostIdentityChoice.allCases) { choice in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { identity = choice }
                    errorMessage = nil
                } label: {
                    Label(choice.title, systemImage: choice == .profile ? "person" : "hexagon")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(identity == choice ? Color.veilBackground : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(identity == choice ? Color.primary : Color.veilSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(identity == choice ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(Color.veilLine, lineWidth: 1) }
    }

    private var anonymousControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 20) {
                ForEach(AnonymousPresentationMode.allCases) { mode in
                    Button(mode.title) {
                        withAnimation(.easeOut(duration: 0.18)) { anonymousMode = mode }
                        errorMessage = nil
                        if mode == .customAlias { focusedField = .alias }
                    }
                    .font(.caption.weight(anonymousMode == mode ? .semibold : .regular))
                    .foregroundStyle(anonymousMode == mode ? appearance.accentColor : Color.veilSecondary)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(anonymousMode == mode ? appearance.accentColor : .clear)
                            .frame(height: 1)
                            .offset(y: 8)
                    }
                    .accessibilityAddTraits(anonymousMode == mode ? .isSelected : [])
                }
            }

            VeilDivider()

            HStack(spacing: 12) {
                SigilView(seed: sigilSeed, size: 30, color: appearance.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    VeilSectionLabel(text: anonymousMode == .sigil ? "Your mark in this thread" : "In this thread, you’re")
                    switch anonymousMode {
                    case .generatedAlias:
                        Text(generatedAlias).font(.subheadline.weight(.semibold))
                    case .customAlias:
                        TextField("Choose a thread alias", text: $customAlias)
                            .focused($focusedField, equals: .alias)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.subheadline.weight(.semibold))
                            .submitLabel(.done)
                            .onChange(of: customAlias) { _ in errorMessage = nil }
                    case .sigil:
                        Text("No public name").font(.subheadline.weight(.semibold))
                    }
                }
                Spacer(minLength: 4)
                Button {
                    rotateIdentity()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(Color.veilSecondary)
                .accessibilityLabel("Generate a new thread identity")
            }
        }
    }

    private var profileIdentity: some View {
        HStack(spacing: 12) {
            ActorBadge(actor: .profile(handle: appFlow.username, displayName: appFlow.username))
            VStack(alignment: .leading, spacing: 3) {
                Text(appFlow.username).font(.subheadline.weight(.semibold))
                Text("Shared with your public profile").font(.caption).foregroundStyle(Color.veilSecondary)
            }
        }
    }

    private var writingArea: some View {
        ZStack(alignment: .topLeading) {
            if bodyText.isEmpty {
                Text("What’s on your mind?")
                    .font(.title2)
                    .foregroundStyle(Color.veilSecondary)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $bodyText)
                .focused($focusedField, equals: .body)
                .font(.title2)
                .lineSpacing(4)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onChange(of: bodyText) { _ in errorMessage = nil }
                .overlay(alignment: .bottomTrailing) {
                    Text("\(bodyText.count.formatted()) / 2,000")
                        .font(.veilLabel(size: 9))
                        .foregroundStyle(bodyText.count > 2_000 ? Color.red : Color.veilSecondary)
                        .padding(.bottom, 3)
                }
        }
    }

    @ViewBuilder
    private var imagePreviews: some View {
        if !images.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 108, height: 108)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        images.remove(at: index)
                                        if index < pickerItems.count { pickerItems.remove(at: index) }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.bold))
                                            .frame(width: 30, height: 30)
                                            .background(.ultraThinMaterial, in: Circle())
                                    }
                                    .padding(5)
                                    .accessibilityLabel("Remove image \(index + 1)")
                                }
                        }
                    }
                }
            }
        }
    }

    private var composerTools: some View {
        HStack {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 4,
                selectionBehavior: .ordered,
                matching: .images
            ) {
                Label(isProcessingImages ? "Preparing…" : "Add images", systemImage: "photo")
                    .font(.subheadline)
                    .foregroundStyle(Color.veilSecondary)
                    .frame(minHeight: 44)
            }
            .disabled(isProcessingImages)
            Spacer()
            Menu {
                Button("No topic") { topic = nil }
                ForEach(store.topics) { option in
                    Button(option.title) { topic = option }
                }
            } label: {
                Label(topic?.title ?? "No topic", systemImage: "number")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(PostExpiration.allCases) { option in
                    Button(option.title) { expiration = option }
                }
            } label: {
                HStack {
                    Label("Disappears after", systemImage: "clock")
                    Spacer()
                    Text(expiration.title).foregroundStyle(Color.veilSecondary)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .font(.subheadline)
                .frame(minHeight: 48)
            }
            Toggle(isOn: $isSensitive) {
                Label("Sensitive content", systemImage: "eye")
                    .font(.subheadline)
            }
            .tint(appearance.accentColor)
            .frame(minHeight: 48)
        }
    }

    private func rotateIdentity() {
        let current = aliases.firstIndex(of: generatedAlias) ?? 0
        generatedAlias = aliases[(current + 1) % aliases.count]
        sigilSeed = (sigilSeed + 29) % 101
    }

    private func prepareImages(_ items: [PhotosPickerItem]) async {
        isProcessingImages = true
        errorMessage = nil
        var prepared: [Data] = []
        do {
            for item in items.prefix(4) {
                guard let raw = try await item.loadTransferable(type: Data.self) else {
                    throw ImageSanitizerError.unreadable
                }
                prepared.append(try ImageSanitizer.sanitizedUploadData(from: raw))
            }
            images = prepared
        } catch {
            errorMessage = error.localizedDescription
            pickerItems = []
            images = []
        }
        isProcessingImages = false
    }

    private func publish() {
        do {
            try store.createPost(
                body: bodyText,
                identity: identity,
                anonymousMode: anonymousMode,
                generatedAlias: generatedAlias,
                customAlias: customAlias,
                sigilSeed: sigilSeed,
                profileHandle: appFlow.username,
                topic: topic,
                expiration: expiration,
                isSensitive: isSensitive,
                images: images
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CornerMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 10
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        return path
    }
}
