// Root navigation adapter. iPhone and iPad share one navigation state, then
// render it through the native container for each size class.
import SwiftUI

private enum HomeRoute: Hashable {
    case listing(ListingKind)
    case item(HNItem)
    case user(HNUserRoute)
}

struct HomeView: View {
    @AppStorage("showExtraLists") private var showExtraLists = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cache: AppCache

    @State private var selectedListing: HNListingDestination = .news
    @State private var rememberedListings: [ListingKind: HNListingDestination] = [
        .news: .news
    ]
    @State private var selectedItem: HNItem?
    @State private var profilePath: [HNUserRoute] = []
    @State private var stackPath: [HomeRoute] = [.listing(.news)]
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingSettings = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                SplitHomeView(
                    selectedListing: $selectedListing,
                    rememberedListings: rememberedListings,
                    selectedItem: $selectedItem,
                    profilePath: $profilePath,
                    columnVisibility: $columnVisibility,
                    showExtraLists: showExtraLists,
                    onSelectListing: selectListing,
                    onUpdateListing: updateListing,
                    onShowUserProfile: showUserProfile,
                    onShowSettings: { showingSettings = true }
                )
            } else {
                StackHomeView(
                    path: $stackPath,
                    selectedListing: selectedListing,
                    rememberedListings: rememberedListings,
                    showExtraLists: showExtraLists,
                    onUpdateListing: updateListing,
                    onSelectItem: selectItem,
                    onShowUserProfile: showUserProfile,
                    onShowSettings: { showingSettings = true }
                )
            }
        }
        .onChange(of: stackPath) { _, path in
            syncSelection(from: path)
        }
        .onChange(of: selectedListing) { _, destination in
            cache.listing(for: destination).loadIfStaleOrMissing()
        }
        .onChange(of: selectedItem?.id) { _, _ in
            selectedItem?.loadIfStaleOrMissing()
        }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            syncNavigation(for: sizeClass)
        }
        .onChange(of: appState.deepLinkItemID) { _, id in
            guard let id else { return }
            openDeepLinkedItem(id)
            appState.deepLinkItemID = nil
        }
        .onChange(of: appState.deepLinkUsername) { _, username in
            guard let username else { return }
            showUserProfile(username)
            appState.deepLinkUsername = nil
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: showExtraLists) { _, isEnabled in
            guard !isEnabled, selectedListing.kind.isExtraList else { return }
            selectListing(.news)
            if horizontalSizeClass != .regular, !stackPath.isEmpty {
                stackPath = [.listing(ListingKind.news)]
            }
        }
    }

    private func listingDestination(for kind: ListingKind) -> HNListingDestination {
        rememberedListings[kind] ?? kind.defaultDestination
    }

    private func selectListing(_ destination: HNListingDestination) {
        updateListing(destination)
        selectedItem = nil
        profilePath = []

        if horizontalSizeClass == .regular {
            stackPath = [.listing(destination.kind)]
        }
    }

    private func updateListing(_ destination: HNListingDestination) {
        selectedListing = destination
        rememberedListings[destination.kind] = destination

        if horizontalSizeClass == .regular {
            selectedItem = nil
            profilePath = []
            stackPath = [.listing(destination.kind)]
        }
    }

    private func selectItem(_ item: HNItem) {
        selectedItem = item
        profilePath = []
        item.loadIfStaleOrMissing()
        stackPath.append(.item(item))
    }

    private func showUserProfile(_ username: String) {
        let route = HNUserRoute(username: username)
        profilePath.append(route)

        if horizontalSizeClass != .regular {
            stackPath.append(.user(route))
        } else {
            columnVisibility = .detailOnly
        }
    }

    private func openDeepLinkedItem(_ id: Int) {
        let target: HNItem
        if let cached = cache.item(for: id) {
            target = cached
        } else {
            let stub = HNItem(id: id)
            cache.rememberItem(stub)
            target = stub
        }

        selectedItem = target
        profilePath = []
        target.loadIfStaleOrMissing()

        if horizontalSizeClass == .regular {
            columnVisibility = .detailOnly
            if !stackPath.isEmpty {
                stackPath = stackPathForCurrentState()
            }
        } else {
            stackPath = stackPathForCurrentState()
        }
    }

    private func syncSelection(from path: [HomeRoute]) {
        if let kind = path.compactMap({ route -> ListingKind? in
            guard case .listing(let kind) = route else { return nil }
            return kind
        }).last {
            selectedListing = listingDestination(for: kind)
        }

        selectedItem = path.compactMap { route -> HNItem? in
            guard case .item(let item) = route else { return nil }
            return item
        }.last

        profilePath = path.compactMap { route -> HNUserRoute? in
            guard case .user(let route) = route else { return nil }
            return route
        }
    }

    private func syncNavigation(for sizeClass: UserInterfaceSizeClass?) {
        if sizeClass == .regular {
            syncSelection(from: stackPath)
        } else if selectedItem != nil || !profilePath.isEmpty || !stackPath.isEmpty {
            stackPath = stackPathForCurrentState()
        }
    }

    private func stackPathForCurrentState() -> [HomeRoute] {
        var path: [HomeRoute] = [.listing(selectedListing.kind)]

        if let selectedItem {
            path.append(.item(selectedItem))
        }

        path.append(contentsOf: profilePath.map(HomeRoute.user))
        return path
    }
}

private struct StackHomeView: View {
    @Binding var path: [HomeRoute]
    let selectedListing: HNListingDestination
    let rememberedListings: [ListingKind: HNListingDestination]
    let showExtraLists: Bool
    let onUpdateListing: (HNListingDestination) -> Void
    let onSelectItem: (HNItem) -> Void
    let onShowUserProfile: (String) -> Void
    let onShowSettings: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            ListingDirectoryView(
                selectedKind: selectedListing.kind,
                showExtraLists: showExtraLists
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .listing(let kind):
                    StackListingView(
                        destination: rememberedListings[kind] ?? kind.defaultDestination,
                        onUpdateDestination: onUpdateListing,
                        onSelectItem: onSelectItem
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            settingsButton
                        }
                    }

                case .item(let item):
                    ItemDetailView(
                        item: item,
                        onShowUserProfile: onShowUserProfile
                    )

                case .user(let route):
                    UserProfileView(route: route)
                }
            }
        }
    }

    private var settingsButton: some View {
        Button(action: onShowSettings) {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
    }
}

private struct ListingDirectoryView: View {
    let selectedKind: ListingKind
    let showExtraLists: Bool

    var body: some View {
        List {
            Section(ListingSection.stories.rawValue) {
                ForEach(ListingKind.storyKinds, id: \.self) { kind in
                    listingLink(for: kind)
                }
            }

            if showExtraLists {
                Section(ListingSection.lists.rawValue) {
                    ForEach(ListingKind.listKinds, id: \.self) { kind in
                        listingLink(for: kind)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Hacker News")
    }

    private func listingLink(for kind: ListingKind) -> some View {
        NavigationLink(value: HomeRoute.listing(kind)) {
            Label(
                kind.displayName,
                systemImage: selectedKind == kind ? "checkmark" : kind.iconName
            )
        }
    }
}

private struct SplitHomeView: View {
    @Binding var selectedListing: HNListingDestination
    let rememberedListings: [ListingKind: HNListingDestination]
    @Binding var selectedItem: HNItem?
    @Binding var profilePath: [HNUserRoute]
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let showExtraLists: Bool
    let onSelectListing: (HNListingDestination) -> Void
    let onUpdateListing: (HNListingDestination) -> Void
    let onShowUserProfile: (String) -> Void
    let onShowSettings: () -> Void

    private var selectedSidebarKind: Binding<ListingKind?> {
        Binding(
            get: { selectedListing.kind },
            set: { newKind in
                guard let newKind else { return }
                onSelectListing(rememberedListings[newKind] ?? newKind.defaultDestination)
            }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } content: {
            ListingContentColumn(
                destination: selectedListing,
                selectedItem: $selectedItem,
                onUpdateDestination: onUpdateListing,
                onShowSettings: onShowSettings
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 500)
        } detail: {
            NavigationStack(path: $profilePath) {
                if let item = selectedItem {
                    ItemDetailView(
                        item: item,
                        onShowUserProfile: onShowUserProfile,
                        onToggleFullScreen: {
                            withAnimation {
                                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                            }
                        },
                        isFullScreen: columnVisibility == .detailOnly
                    )
                } else {
                    ContentUnavailableView {
                        Label("Select a story", systemImage: "newspaper")
                    } description: {
                        Text("Choose a story from the list.")
                    }
                }
            }
            .navigationDestination(for: HNUserRoute.self) { route in
                UserProfileView(route: route)
            }
            .id(selectedItem?.id)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: selectedSidebarKind) {
            Section(ListingSection.stories.rawValue) {
                ForEach(ListingKind.storyKinds, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.iconName)
                        .tag(kind as ListingKind?)
                }
            }

            if showExtraLists {
                Section(ListingSection.lists.rawValue) {
                    ForEach(ListingKind.listKinds, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.iconName)
                            .tag(kind as ListingKind?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

#if DEBUG
struct Home_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppState())
            .environmentObject(AppCache())
    }
}
#endif
