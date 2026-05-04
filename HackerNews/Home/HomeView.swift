// Root navigation container for both iPhone and iPad. On iPad renders as a
// three-column NavigationSplitView; on iPhone, SwiftUI auto-collapses the same
// view into a NavigationStack with the sidebar as root, and preferredCompactColumn
// lands the user on the content column (Front Page) at launch.
import SwiftUI

struct HomeView: View {
    @AppStorage("showExtraLists") private var showExtraLists = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cache: AppCache
    @State private var selectedListing: HNListingDestination = .news
    @State private var rememberedListings: [ListingKind: HNListingDestination] = [
        .news: .news
    ]
    @State private var sidebarSelection: ListingKind? = .news
    @State private var selectedItem: HNItem?
    @State private var detailPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .content
    @State private var showingSettings = false

    private var selectedSidebarKind: Binding<ListingKind?> {
        Binding(
            get: { sidebarSelection },
            set: { newKind in
                guard let newKind else {
                    sidebarSelection = nil
                    return
                }

                sidebarSelection = newKind
                updateListing(rememberedListings[newKind] ?? newKind.defaultDestination)

                if horizontalSizeClass == .compact {
                    preferredCompactColumn = .content
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn) {
            sidebarView
        } content: {
            ListingContentColumn(
                destination: selectedListing,
                selectedItem: $selectedItem,
                onUpdateDestination: updateListing,
                onShowSettings: { showingSettings = true }
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 500)
        } detail: {
            NavigationStack(path: $detailPath) {
                if let item = selectedItem {
                    ItemDetailView(
                        item: item,
                        onShowUserProfile: { username in
                            detailPath.append(HNUserRoute(username: username))
                        },
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
        .onChange(of: selectedListing) {
            selectedItem = nil
            detailPath = NavigationPath()
            cache.listing(for: selectedListing).loadIfStaleOrMissing()
        }
        .onChange(of: selectedItem?.id) { _, _ in
            detailPath = NavigationPath()
            // Pre-warm the fetch at selection-change time so URLSession
            // runs in parallel with the detail column's view
            // construction. onChange fires during state reconciliation,
            // synchronously after List(selection:) updates and before
            // ItemDetailView.onAppear.
            selectedItem?.loadIfStaleOrMissing()
        }
        .onChange(of: appState.deepLinkItemID) { _, id in
            guard let id else { return }
            if let cached = cache.item(for: id) {
                selectedItem = cached
            } else {
                let stub = HNItem(id: id)
                cache.rememberItem(stub)
                selectedItem = stub
            }
            detailPath = NavigationPath()
            columnVisibility = .detailOnly
            appState.deepLinkItemID = nil
        }
        .onChange(of: appState.deepLinkUsername) { _, username in
            guard let username else { return }
            detailPath.append(HNUserRoute(username: username))
            appState.deepLinkUsername = nil
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: showExtraLists) { _, isEnabled in
            guard !isEnabled, selectedListing.kind.isExtraList else { return }
            updateListing(.news)
        }
        .onChange(of: preferredCompactColumn) { _, column in
            guard horizontalSizeClass == .compact, column == .sidebar else { return }
            sidebarSelection = nil
        }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .regular {
                sidebarSelection = selectedListing.kind
            } else if sizeClass == .compact {
                sidebarSelection = nil
            }
        }
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
        .onAppear {
            guard horizontalSizeClass == .compact else { return }
            sidebarSelection = nil
        }
    }

    private func updateListing(_ destination: HNListingDestination) {
        selectedListing = destination
        rememberedListings[destination.kind] = destination
        if horizontalSizeClass == .regular {
            sidebarSelection = destination.kind
        }
    }
}
