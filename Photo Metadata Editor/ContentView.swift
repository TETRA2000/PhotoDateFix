import SwiftUI
import Photos

struct ContentView: View {
    @State private var service = PhotoLibraryService()
    @State private var showFixConfirmation = false
    @State private var fixError: String?
    @State private var showFixError = false
    @State private var showFilter = false

    var body: some View {
        NavigationStack {
            Group {
                switch service.authorizationStatus {
                case .notDetermined:
                    authorizationRequestView
                case .denied:
                    deniedView
                case .authorized, .limited:
                    mainContentView
                }
            }
            .navigationTitle("PhotoDateFix")
            .task {
                service.checkAuthorization()
            }
        }
    }

    // MARK: - Authorization Views

    private var authorizationRequestView: some View {
        ContentUnavailableView {
            Label("Photo Library Access", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("This app needs access to your photo library to find and fix photos with incorrect dates.")
        } actions: {
            Button("Grant Access") {
                Task {
                    await service.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("Access Denied", systemImage: "lock.shield")
        } description: {
            Text("Photo library access was denied. Please enable it in Settings to use this app.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        Group {
            switch service.scanState {
            case .idle:
                idleView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .completed:
                resultsView
            case .error(let message):
                errorView(message: message)
            }
        }
        .toolbar {
            toolbarContent
        }
    }

    private var idleView: some View {
        VStack(spacing: 0) {
            if showFilter {
                filterBar
            }
            Spacer()
            ContentUnavailableView {
                Label("Scan Your Library", systemImage: "magnifyingglass")
            } description: {
                Text("Tap the scan button to find photos whose dates differ from the original EXIF metadata.")
                if service.isFilterActive {
                    Text("Date filter is active — only photos in the selected range will be scanned.")
                        .foregroundStyle(.blue)
                }
            } actions: {
                Button("Start Scan") {
                    Task {
                        await service.scanForMismatches()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }

    private func scanningView(progress: Double) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: progress) {
                Text("Scanning photos...")
            } currentValueLabel: {
                Text("\(service.totalPhotosScanned) photos scanned")
            }
            .padding()

            if !service.mismatchedPhotos.isEmpty {
                Text("\(service.mismatchedPhotos.count) mismatches found so far")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var resultsView: some View {
        Group {
            if service.mismatchedPhotos.isEmpty {
                ContentUnavailableView {
                    Label("All Dates Match", systemImage: "checkmark.circle")
                } description: {
                    Text("All \(service.totalPhotosScanned) photos have matching dates. No fixes needed.")
                } actions: {
                    Button("Scan Again") {
                        Task {
                            await service.scanForMismatches()
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    summaryBar
                    if showFilter {
                        filterBar
                    }
                    photoList
                }
            }
        }
    }

    private var summaryBar: some View {
        HStack {
            Text("\(service.filteredPhotos.count) of \(service.mismatchedPhotos.count) mismatched")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(service.selectedItems.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Filter

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("From")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                if let startDate = service.filterStartDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { startDate },
                            set: { service.filterStartDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    Button { service.filterStartDate = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Set start date") {
                        service.filterStartDate = Calendar.current.date(
                            from: DateComponents(year: 2010, month: 1, day: 1)
                        ) ?? .now
                    }
                    .font(.subheadline)
                    Spacer()
                }
            }

            HStack {
                Text("To")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                if let endDate = service.filterEndDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { endDate },
                            set: { service.filterEndDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    Button { service.filterEndDate = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Set end date") {
                        service.filterEndDate = Calendar.current.date(
                            from: DateComponents(year: 2020, month: 12, day: 31)
                        ) ?? .now
                    }
                    .font(.subheadline)
                    Spacer()
                }
            }

            if service.isFilterActive {
                Button("Clear Filter") {
                    service.clearFilter()
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var photoList: some View {
        List {
            ForEach(service.filteredPhotos) { item in
                NavigationLink {
                    PhotoDetailView(item: item) {
                        Task {
                            try? await service.fixDates(for: [item])
                        }
                    }
                } label: {
                    PhotoRowView(
                        item: item,
                        isSelected: item.isSelected,
                        onToggleSelection: {
                            service.toggleSelection(for: item.id)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await service.scanForMismatches()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !service.filteredPhotos.isEmpty {
                Button(service.allSelected ? "Deselect All" : "Select All") {
                    if service.allSelected {
                        service.deselectAll()
                    } else {
                        service.selectAll()
                    }
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                withAnimation {
                    showFilter.toggle()
                }
            } label: {
                Label("Filter", systemImage: service.isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }

            if !service.selectedItems.isEmpty {
                Button {
                    showFixConfirmation = true
                } label: {
                    Label("Fix Selected", systemImage: "wrench.and.screwdriver")
                }
                .confirmationDialog(
                    "Fix \(service.selectedItems.count) Photos",
                    isPresented: $showFixConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Fix \(service.selectedItems.count) photo dates") {
                        Task {
                            do {
                                try await service.fixDates(for: service.selectedItems)
                            } catch {
                                fixError = error.localizedDescription
                                showFixError = true
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will update the creation date of \(service.selectedItems.count) selected photos to their original EXIF dates.")
                }
            }

            if case .scanning = service.scanState {
                // Don't show scan button while scanning
            } else {
                Button {
                    Task {
                        await service.scanForMismatches()
                    }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
