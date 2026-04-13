// Phone root container that opens on the front page listing, exposes listing
// switching and settings from the nav bar, and receives deep-link requests.
import SwiftUI

struct HomeView: View {
    @AppStorage("showExtraLists") private var showExtraLists = false
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cache: AppCache
    @State private var path = NavigationPath()
    @State private var selectedListing = ListingKind.news.defaultDestination
    @State private var rememberedListings: [ListingKind: HNListingDestination] = [
        .news: .news
    ]
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            ListingView(
                destination: selectedListing,
                onUpdateDestination: updateListing
            )
            .id(selectedListing)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        menuSection(title: ListingSection.stories.rawValue, kinds: ListingKind.storyKinds)
                        if showExtraLists {
                            menuSection(title: ListingSection.lists.rawValue, kinds: ListingKind.listKinds)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Listings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: HNItem.self) { item in
                ItemDetailView(
                    item: item,
                    onShowUserProfile: { username in
                        path.append(HNUserRoute(username: username))
                    }
                )
            }
            .navigationDestination(for: HNUserRoute.self) { route in
                UserProfileView(route: route)
            }
        }
        .onChange(of: appState.deepLinkItemID) { _, id in
            guard let id else { return }
            let target: HNItem
            if let cached = cache.item(for: id) {
                target = cached
            } else {
                let stub = HNItem(id: id)
                cache.rememberItem(stub)
                target = stub
            }
            path.append(target)
            appState.deepLinkItemID = nil
        }
        .onChange(of: appState.deepLinkUsername) { _, username in
            guard let username else { return }
            path.append(HNUserRoute(username: username))
            appState.deepLinkUsername = nil
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: showExtraLists) { _, isEnabled in
            guard !isEnabled, selectedListing.kind.isExtraList else { return }
            selectedListing = .news
            path = NavigationPath()
        }
    }

    @ViewBuilder
    private func menuSection(title: String, kinds: [ListingKind]) -> some View {
        Section(title) {
            ForEach(kinds, id: \.self) { kind in
                Button {
                    selectedListing = rememberedListings[kind] ?? kind.defaultDestination
                    path = NavigationPath()
                } label: {
                    Label(
                        kind.displayName,
                        systemImage: selectedListing.kind == kind ? "checkmark" : kind.iconName
                    )
                }
            }
        }
    }

    private func updateListing(_ destination: HNListingDestination) {
        selectedListing = destination
        rememberedListings[destination.kind] = destination
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppState())
            .environmentObject(AppCache())
    }
}
