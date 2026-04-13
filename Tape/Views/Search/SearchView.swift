import SwiftUI
import Kingfisher

struct SearchView: View {
    let currentUser: User
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var selectedFilters = SearchFilters()
    @State private var showFilters = false
    @State private var navigateToProfile: String?

    private let profileService: ProfileServiceProtocol = MockProfileService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    filterChips
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $navigateToProfile) { athleteID in
                AthleteProfileView(athleteID: athleteID, currentUser: currentUser)
            }
            .sheet(isPresented: $showFilters) {
                SearchFilterSheet(filters: $selectedFilters) {
                    Task { await performSearch() }
                }
                .presentationDetents([.medium])
            }
            .task {
                await loadAllUsers()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search athletes, coaches, brands...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .onChange(of: searchText) { _, _ in
                        Task { await performSearch() }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task { await performSearch() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.tapeCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                showFilters = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(hasActiveFilters ? Color.tapeRed : .secondary)
                    .padding(10)
                    .background(Color.tapeCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var filterChips: some View {
        Group {
            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let role = selectedFilters.role {
                            filterChip(role.displayName) {
                                selectedFilters.role = nil
                                Task { await performSearch() }
                            }
                        }
                        if let pos = selectedFilters.position, !pos.isEmpty {
                            filterChip(pos) {
                                selectedFilters.position = nil
                                Task { await performSearch() }
                            }
                        }
                        if let state = selectedFilters.state, !state.isEmpty {
                            filterChip(state) {
                                selectedFilters.state = nil
                                Task { await performSearch() }
                            }
                        }
                        if let sport = selectedFilters.sport, !sport.isEmpty {
                            filterChip(sport) {
                                selectedFilters.sport = nil
                                Task { await performSearch() }
                            }
                        }

                        Button("Clear All") {
                            selectedFilters = SearchFilters()
                            Task { await performSearch() }
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.tapeRed)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func filterChip(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption.bold())
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.tapeRed.opacity(0.2))
        .foregroundStyle(Color.tapeRed)
        .clipShape(Capsule())
    }

    private var resultsList: some View {
        ScrollView {
            if isSearching {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(searchResults) { user in
                        Button {
                            navigateToProfile = user.id
                        } label: {
                            SearchResultRow(user: user)
                        }
                    }
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedFilters.role != nil ||
        (selectedFilters.position != nil && !selectedFilters.position!.isEmpty) ||
        (selectedFilters.state != nil && !selectedFilters.state!.isEmpty) ||
        (selectedFilters.sport != nil && !selectedFilters.sport!.isEmpty)
    }

    private func loadAllUsers() async {
        do {
            searchResults = try await profileService.fetchAthletes()
        } catch {}
    }

    private func performSearch() async {
        let allUsers = MockData.allUsers
        var filtered = allUsers

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.displayName.lowercased().contains(query) ||
                ($0.highSchool?.lowercased().contains(query) ?? false) ||
                ($0.organization?.lowercased().contains(query) ?? false) ||
                ($0.position?.lowercased().contains(query) ?? false)
            }
        }

        if let role = selectedFilters.role {
            filtered = filtered.filter { $0.role == role }
        }
        if let pos = selectedFilters.position, !pos.isEmpty {
            filtered = filtered.filter { $0.position == pos }
        }
        if let state = selectedFilters.state, !state.isEmpty {
            filtered = filtered.filter { $0.state == state }
        }
        if let sport = selectedFilters.sport, !sport.isEmpty {
            filtered = filtered.filter { $0.sport == sport }
        }

        searchResults = filtered
    }
}

struct SearchFilters {
    var role: UserRole?
    var position: String?
    var state: String?
    var sport: String?
}

struct SearchResultRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 14) {
            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(user.role.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleBadgeColor(user.role).opacity(0.2))
                        .foregroundStyle(roleBadgeColor(user.role))
                        .clipShape(Capsule())
                }

                Text(user.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.tapeDarkBg)
    }

    private func roleBadgeColor(_ role: UserRole) -> Color {
        switch role {
        case .athlete: return Color.tapeRed
        case .recruiter: return .blue
        case .brand: return .orange
        }
    }
}

struct SearchFilterSheet: View {
    @Binding var filters: SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let positions = ["", "QB", "WR", "RB", "TE", "OL", "DL", "LB", "CB", "S"]
    private let states = ["", "AL", "CA", "FL", "GA", "IL", "MD", "MI", "NY", "OH", "PA", "TX"]
    private let sports = ["", "Football", "Basketball", "Baseball", "Soccer", "Track & Field"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Role filter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Role")
                                .font(.headline)
                                .foregroundStyle(.white)
                            HStack(spacing: 8) {
                                roleButton(nil, label: "All")
                                ForEach(UserRole.allCases) { role in
                                    roleButton(role, label: role.displayName)
                                }
                            }
                        }

                        // Position
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.headline)
                                .foregroundStyle(.white)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                                ForEach(positions, id: \.self) { pos in
                                    let isSelected = filters.position == (pos.isEmpty ? nil : pos)
                                    Button {
                                        filters.position = pos.isEmpty ? nil : pos
                                    } label: {
                                        Text(pos.isEmpty ? "Any" : pos)
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? Color.tapeRed : Color.tapeCardBg)
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }

                        // State
                        VStack(alignment: .leading, spacing: 8) {
                            Text("State")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Picker("State", selection: Binding(
                                get: { filters.state ?? "" },
                                set: { filters.state = $0.isEmpty ? nil : $0 }
                            )) {
                                ForEach(states, id: \.self) { s in
                                    Text(s.isEmpty ? "Any" : s).tag(s)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(10)
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Sport
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sport")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Picker("Sport", selection: Binding(
                                get: { filters.sport ?? "" },
                                set: { filters.sport = $0.isEmpty ? nil : $0 }
                            )) {
                                ForEach(sports, id: \.self) { s in
                                    Text(s.isEmpty ? "Any" : s).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Button {
                            onApply()
                            dismiss()
                        } label: {
                            Text("Apply Filters")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.tapeRed)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func roleButton(_ role: UserRole?, label: String) -> some View {
        Button {
            filters.role = role
        } label: {
            Text(label)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(filters.role == role ? Color.tapeRed : Color.tapeCardBg)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }
}
