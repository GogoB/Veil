import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var query = ""

    private var results: [DemoPost] { store.search(query) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if query.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            VeilSectionLabel(text: "Public discovery")
                            Text("Find a topic, a thought,\nor a public profile.")
                                .font(.system(size: 34, weight: .medium))
                                .tracking(-1.2)
                            Text("Anonymous aliases and sigils never appear in search results.")
                                .font(.callout)
                                .foregroundStyle(Color.veilSecondary)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    } else if results.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(appearance.accentColor)
                            Text("Nothing public found").font(.headline)
                            Text("Try a topic, post text, or public handle.")
                                .font(.subheadline)
                                .foregroundStyle(Color.veilSecondary)
                        }
                        .padding(.top, 70)
                    } else {
                        ForEach(results) { post in
                            PostCardView(post: post)
                        }
                    }
                }
            }
            .background(Color.veilBackground)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Topics, posts, profiles")
        }
    }
}
