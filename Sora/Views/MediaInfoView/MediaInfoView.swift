//
//  MediaInfoView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import NukeUI
import SwiftUI
import SafariServices

private let tmdbFetcher = TMDBFetcher()

struct MediaItem: Identifiable {
    let id = UUID()
    let description: String
    let aliases: String
    let airdate: String
}

struct MediaInfoView: View {
    let title: String
    @State var imageUrl: String
    let href: String
    let module: ScrapingModule
    
    @State private var aliases: String = ""
    @State private var synopsis: String = ""
    @State private var airdate: String = ""
    @State private var episodeLinks: [EpisodeLink] = []
    @State private var chapters: [[String: Any]] = []
    @State private var itemID: Int?
    @State private var tmdbID: Int?
    @State private var tmdbType: TMDBFetcher.MediaType? = nil
    @State private var currentFetchTask: Task<Void, Never>? = nil
    
    @State private var isLoading: Bool = true
    @State private var showFullSynopsis: Bool = false
    @State private var hasFetched: Bool = false
    @State private var isRefetching: Bool = true
    @State private var isFetchingEpisode: Bool = false
    @State private var isError = false
    @State private var showLoadingAlert: Bool = false
    
    @State private var selectedEpisodeNumber: Int = 0
    @State private var selectedEpisodeImage: String = ""
    @State private var selectedSeason: Int = 0
    @State private var selectedRange: Range<Int> = {
        let size = UserDefaults.standard.integer(forKey: "episodeChunkSize")
        let chunk = size == 0 ? 50 : size
        return 0..<chunk
    }()
    
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedEpisodes: Set<Int> = []
    @State private var showRangeInput: Bool = false
    @State private var isBulkDownloading: Bool = false
    @State private var bulkDownloadProgress: String = ""
    @State private var isSingleEpisodeDownloading: Bool = false
    
    @State private var isModuleSelectorPresented = false
    @State private var isMatchingPresented = false
    @State private var matchedTitle: String? = nil
    @State private var showSettingsMenu = false
    @State private var customAniListID: Int?
    @State private var showStreamLoadingView: Bool = false
    @State private var currentStreamTitle: String = ""
    @State private var activeFetchID: UUID? = nil
    @State private var activeProvider: String?
    @State private var isTMDBMatchingPresented = false
    
    @State private var refreshTrigger: Bool = false
    @State private var buttonRefreshTrigger: Bool = false
    
    private var selectedRangeKey: String { "selectedRangeStart_\(href)" }
    private var selectedSeasonKey: String { "selectedSeason_\(href)" }
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @AppStorage("episodeChunkSize") private var episodeChunkSize: Int = 50
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject private var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    @ObservedObject private var navigator = ChapterNavigator.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @AppStorage("metadataProvidersOrder") private var metadataProvidersOrderData: Data = {
        try! JSONEncoder().encode(["TMDB","AniList"])
    }()
    
    private var metadataProvidersOrder: [String] {
        get { (try? JSONDecoder().decode([String].self, from: metadataProvidersOrderData)) ?? ["TMDB","AniList"] }
        set { metadataProvidersOrderData = try! JSONEncoder().encode(newValue) }
    }
    
    private var isGroupedBySeasons: Bool {
        return groupedEpisodes().count > 1
    }
    
    private var isCompactLayout: Bool {
        return verticalSizeClass == .compact
    }
    
    private var useIconOnlyButtons: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return false
        }
        return verticalSizeClass == .regular
    }
    
    private var multiselectButtonSpacing: CGFloat {
        return isCompactLayout ? 16 : 12
    }
    
    private var multiselectPadding: CGFloat {
        return isCompactLayout ? 20 : 16
    }
    
    private var startActionText: String {
        if module.metadata.novel == true {
            let lastReadChapter = UserDefaults.standard.string(forKey: "lastReadChapter")
            if let lastRead = lastReadChapter, chapters.contains(where: { $0["href"] as! String == lastRead }) {
                return NSLocalizedString("Continue Reading", comment: "")
            }
            return NSLocalizedString("Start Reading", comment: "")
        } else {
            let indices = finishedAndUnfinishedIndices()
            let finished = indices.finished
            let unfinished = indices.unfinished
            
            if episodeLinks.count == 1 {
                if let _ = unfinished {
                    return NSLocalizedString("Continue Watching", comment: "")
                }
                return NSLocalizedString("Start Watching", comment: "")
            }
            
            if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
                let nextEp = episodeLinks[finishedIndex + 1]
                return String(format: NSLocalizedString("Start Watching Episode %d", comment: ""), nextEp.number)
            }
            
            if let unfinishedIndex = unfinished {
                let currentEp = episodeLinks[unfinishedIndex]
                return String(format: NSLocalizedString("Continue Watching Episode %d", comment: ""), currentEp.number)
            }
            
            return NSLocalizedString("Start Watching", comment: "")
        }
    }
    
    private var singleEpisodeWatchText: String {
        if let ep = episodeLinks.first {
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
            return progress <= 0.9 ? NSLocalizedString("Mark watched", comment: "") : NSLocalizedString("Reset progress", comment: "")
        }
        return NSLocalizedString("Mark watched", comment: "")
    }
    
    @State private var selectedChapterRange: Range<Int> = {
        let size = UserDefaults.standard.integer(forKey: "episodeChunkSize")
        let chunk = size == 0 ? 50 : size
        return 0..<chunk
    }()
    @AppStorage("chapterChunkSize") private var chapterChunkSize: Int = 50
    private var selectedChapterRangeKey: String { "selectedChapterRangeStart_\(href)" }
    
    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    mainScrollView
                }
            }
            .navigationBarHidden(true)
            .ignoresSafeArea(.container, edges: .top)
            .onAppear {
                setupViewOnAppear()
                NotificationCenter.default.post(name: .hideTabBar, object: nil)
                UserDefaults.standard.set(true, forKey: "isMediaInfoActive")
            }
            .onChange(of: selectedRange) { newValue in
                UserDefaults.standard.set(newValue.lowerBound, forKey: selectedRangeKey)
            }
            .onChange(of: selectedSeason) { newValue in
                let ranges = generateRanges(for: currentEpisodeList.count)
                if let validRange = ranges.first(where: { $0 == selectedRange }) {
                    selectedRange = validRange
                } else {
                    selectedRange = ranges.first ?? 0..<episodeChunkSize
                }
                UserDefaults.standard.set(newValue, forKey: selectedSeasonKey)
            }
            .onChange(of: selectedChapterRange) { newValue in
                UserDefaults.standard.set(newValue.lowerBound, forKey: selectedChapterRangeKey)
            }
            .onDisappear {
                currentFetchTask?.cancel()
                activeFetchID = nil
                UserDefaults.standard.set(false, forKey: "isMediaInfoActive")
                UIScrollView.appearance().bounces = true
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
            .task {
                await setupInitialData()
            }
            .alert("Loading Stream", isPresented: $showLoadingAlert) {
                Button("Cancel", role: .cancel) {
                    cancelCurrentFetch()
                }
            } message: {
                HStack {
                    Text("Loading Episode \(selectedEpisodeNumber)...")
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            
            navigationOverlay
        }
        .sheet(isPresented: $libraryManager.isShowingCollectionPicker) {
            if let bookmark = libraryManager.bookmarkToAdd {
                CollectionPickerView(bookmark: bookmark)
            }
        }
    }
    
    @ViewBuilder
    private var navigationOverlay: some View {
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.8))
                        .clipShape(Circle())
                        .circularGradientOutline()
                }
                .padding(.top, 8)
                .padding(.leading, 16)
                
                Spacer()
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                heroImageSection
                contentContainer
            }
        }
        .onAppear {
            UIScrollView.appearance().bounces = false
        }
    }
    
    @ViewBuilder
    private var heroImageSection: some View {
        LazyImage(url: URL(string: imageUrl)) { state in
            if let uiImage = state.imageContainer?.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: 700)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: UIScreen.main.bounds.width, height: 700)
                    .clipped()
            }
        }
    }
    
    @ViewBuilder
    private var contentContainer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 400)
            
            ZStack(alignment: .top) {
                gradientOverlay
                
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    
                    if !aliases.isEmpty && !(module.metadata.novel ?? false) {
                        Text(aliases)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    if module.metadata.novel ?? false {
                        if !chapters.isEmpty {
                            chaptersSection
                        } else {
                            noContentSection
                        }
                    } else {
                        if !episodeLinks.isEmpty {
                            episodesSection
                        } else {
                            noContentSection
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.0), location: 0.0),
                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.5), location: 0.2),
                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.8), location: 0.5),
                .init(color: (colorScheme == .dark ? Color.black : Color.white), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: (colorScheme == .dark ? Color.black : Color.white).opacity(1), radius: 10, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !airdate.isEmpty && airdate != "N/A" && airdate != "No Data" {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.accentColor)
                    Text(airdate)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                    Spacer()
                }
            }
            
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .onLongPressGesture {
                    copyTitleToClipboard()
                }
            
            if !synopsis.isEmpty && !(module.metadata.novel ?? false) {
                synopsisSection
            }
            
            if module.metadata.novel ?? false && !synopsis.isEmpty {
                synopsisSection
            }
            
            playAndBookmarkSection
            
            if episodeLinks.count == 1 {
                singleEpisodeSection
            }
        }
    }
    
    @ViewBuilder
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(synopsis)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
                .lineLimit(showFullSynopsis ? nil : 3)
                .animation(nil, value: showFullSynopsis)
            
            HStack {
                Spacer()
                Text(showFullSynopsis ? NSLocalizedString("LESS", comment: "") : NSLocalizedString("MORE", comment: ""))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.accentColor)
                    .animation(.easeInOut(duration: 0.3), value: showFullSynopsis)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showFullSynopsis.toggle()
            }
        }
    }
    
    @ViewBuilder
    private var playAndBookmarkSection: some View {
        HStack(spacing: 12) {
            Button(action: { playFirstUnwatchedEpisode() }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                    Text(startActionText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.accentColor)
                )
            }
            .disabled(isFetchingEpisode)
            
            Button(action: { toggleBookmark() }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .resizable()
                    .frame(width: 16, height: 22)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                    .circularGradientOutline()
            }
        }
    }
    
    @ViewBuilder
    private var singleEpisodeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { toggleSingleEpisodeWatchStatus() }) {
                    HStack(spacing: 4) {
                        Image(systemName: singleEpisodeWatchIcon)
                            .foregroundColor(.primary)
                        Text(singleEpisodeWatchText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    .gradientOutline()
                }
                
                Button(action: { downloadSingleEpisode() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.primary)
                        Text(NSLocalizedString("Download", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: 120)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    .gradientOutline()
                }
                
                Button(action: { openSafariViewController(with: href) }) {
                    Image(systemName: "safari")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                        .circularGradientOutline()
                }
                
                menuButton
            }
            
            VStack(spacing: 4) {
                Text(NSLocalizedString("Why am I not seeing any episodes?", comment: ""))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(NSLocalizedString("The module provided only a single episode, this is most likely a movie, so we decided to make separate screens for these cases.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }
    
    private var isBookmarked: Bool {
        libraryManager.isBookmarked(href: href, moduleName: module.metadata.sourceName)
    }
    
    private var singleEpisodeWatchIcon: String {
        if let ep = episodeLinks.first {
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
            return progress <= 0.9 ? "checkmark.circle" : "arrow.counterclockwise"
        }
        return "checkmark.circle"
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        let _ = Logger.shared.log("episodesSection: episodeLinks count = \(episodeLinks.count)", type: "Debug")
        if episodeLinks.count != 1 {
            VStack(alignment: .leading, spacing: 16) {
                episodesSectionHeader
                episodeListSection
            }
        }
    }
    
    @ViewBuilder
    private var seasonSelectorStyled: some View {
        let seasons = groupedEpisodes()
        if seasons.count > 1 {
            Menu {
                ForEach(0..<seasons.count, id: \..self) { index in
                    Button(action: { selectedSeason = index }) {
                        Text(String(format: NSLocalizedString("Season %d", comment: ""), index + 1))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Season \(selectedSeason + 1)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.accentColor)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    @ViewBuilder
    private var rangeSelectorStyled: some View {
        Menu {
            ForEach(episodeRanges, id: \.self) { range in
                Button(action: { selectedRange = range }) {
                    Text("\(range.lowerBound + 1)-\(range.upperBound)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(selectedRange.lowerBound + 1)-\(selectedRange.upperBound)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.accentColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private var episodesSectionHeader: some View {
        HStack {
            Text(NSLocalizedString("Episodes", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            sourceButton
            menuButton
        }
        if isGroupedBySeasons || episodeLinks.count > episodeChunkSize {
            HStack {
                if isGroupedBySeasons {
                    seasonSelectorStyled
                } else {
                    Spacer(minLength: 0)
                }
                Spacer()
                if episodeLinks.count > episodeChunkSize {
                    rangeSelectorStyled
                        .padding(.trailing, 4)
                }
            }
            .padding(.top, -8)
        }
    }
    
    @ViewBuilder
    private var episodeListSection: some View {
        Group {
            if isGroupedBySeasons {
                seasonsEpisodeList
            } else {
                flatEpisodeList
            }
        }
    }
    
    @ViewBuilder
    private var flatEpisodeList: some View {
        VStack(spacing: 15) {
            ForEach(currentEpisodeList.indices.filter { selectedRange.contains($0) }, id: \.self) { i in
                let ep = currentEpisodeList[i]
                createEpisodeCell(episode: ep, index: i, season: isGroupedBySeasons ? selectedSeason + 1 : 1)
            }
        }
    }
    
    @ViewBuilder
    private var seasonsEpisodeList: some View {
        let seasons = groupedEpisodes()
        if !seasons.isEmpty, selectedSeason < seasons.count {
            VStack(spacing: 15) {
                ForEach(seasons[selectedSeason].indices.filter { selectedRange.contains($0) }, id: \.self) { i in
                    let ep = seasons[selectedSeason][i]
                    createEpisodeCell(episode: ep, index: i, season: selectedSeason + 1)
                }
            }
        } else {
            Text("No episodes available")
        }
    }
    
    @ViewBuilder
    private func createEpisodeCell(episode: EpisodeLink, index: Int, season: Int) -> some View {
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episode.href)")
        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episode.href)")
        let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
        let defaultBannerImageValue = getBannerImageBasedOnAppearance()
        
        EpisodeCell(
            episodeIndex: index,
            episode: episode.href,
            episodeID: episode.number - 1,
            progress: progress,
            itemID: itemID ?? 0,
            totalEpisodes: episodeLinks.count,
            defaultBannerImage: defaultBannerImageValue,
            module: module,
            parentTitle: title,
            showPosterURL: imageUrl,
            isMultiSelectMode: isMultiSelectMode,
            isSelected: selectedEpisodes.contains(episode.number),
            onSelectionChanged: { isSelected in
                handleEpisodeSelection(episode: episode, isSelected: isSelected)
            },
            onTap: { imageUrl in
                episodeTapAction(ep: episode, imageUrl: imageUrl)
            },
            onMarkAllPrevious: {
                markAllPreviousEpisodes(episode: episode, index: index, inSeason: isGroupedBySeasons)
            },
            tmdbID: tmdbID,
            seasonNumber: season
        )
        .disabled(isFetchingEpisode)
    }
    
    @ViewBuilder
    private var chaptersSection: some View {
        let _ = Logger.shared.log("chaptersSection: chapters count = \(chapters.count)", type: "Debug")
        VStack(alignment: .leading, spacing: 16) {
            if !airdate.isEmpty && airdate != "N/A" && airdate != "No Data" {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.accentColor)
                    Text(airdate)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                    Spacer()
                }
            }
            if !aliases.isEmpty {
                Text(aliases)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(NSLocalizedString("Chapters", comment: ""))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 4) {
                    if chapters.count > chapterChunkSize {
                        HStack {
                            Spacer()
                            chapterRangeSelectorStyled
                        }
                        .padding(.bottom, 0)
                    }
                    
                    sourceButton
                    menuButton
                }
            }
            
            LazyVStack(spacing: 15) {
                ForEach(chapters.indices.filter { selectedChapterRange.contains($0) }, id: \..self) { i in
                    let chapter = chapters[i]
                    let _ = refreshTrigger
                    if let href = chapter["href"] as? String,
                       let number = chapter["number"] as? Int,
                       let title = chapter["title"] as? String {
                        Button(action: {
                            presentReaderView(
                                moduleId: module.id,
                                chapterHref: href,
                                chapterTitle: title,
                                chapters: chapters,
                                mediaTitle: self.title,
                                chapterNumber: number
                            )
                        }) {
                            ChapterCell(
                                chapterNumber: String(number),
                                chapterTitle: title,
                                isCurrentChapter: false,
                                progress: UserDefaults.standard.double(forKey: "readingProgress_\(href)"),
                                href: href
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(action: {
                                markChapterAsRead(href: href, number: number)
                            }) {
                                Label("Mark as Read", systemImage: "checkmark.circle")
                            }
                            
                            Button(action: {
                                resetChapterProgress(href: href)
                            }) {
                                Label("Reset Progress", systemImage: "arrow.counterclockwise")
                            }
                            
                            Button(action: {
                                markAllPreviousChaptersAsRead(currentNumber: number)
                            }) {
                                Label("Mark Previous as Read", systemImage: "checkmark.circle.badge.plus")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var chapterRangeSelectorStyled: some View {
        Menu {
            ForEach(generateChapterRanges(), id: \..self) { range in
                Button(action: { selectedChapterRange = range }) {
                    Text("\(range.lowerBound + 1)-\(range.upperBound)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(selectedChapterRange.lowerBound + 1)-\(selectedChapterRange.upperBound)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.accentColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private var noContentSection: some View {
        VStack(spacing: 8) {
            Image(systemName: module.metadata.novel == true ? "book.slash" : "tv.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(module.metadata.novel == true ? NSLocalizedString("No Chapters Available", comment: "") : NSLocalizedString("No Episodes Available", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(module.metadata.novel == true ? NSLocalizedString("Chapters might not be available yet or there could be an issue with the source.", comment: "") : NSLocalizedString("Episodes might not be available yet or there could be an issue with the source.", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
        .padding(.vertical, 50)
    }
    
    @ViewBuilder
    private var sourceButton: some View {
        Button(action: { openSafariViewController(with: href) }) {
            Image(systemName: "safari")
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(.primary)
                .padding(6)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
                .circularGradientOutline()
        }
    }
    
    @ViewBuilder
    private var menuButton: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
                .resizable()
                .frame(width: 16, height: 4)
                .foregroundColor(.primary)
                .padding(12)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
                .circularGradientOutline()
        }
        .sheet(isPresented: $isMatchingPresented) {
            AnilistMatchPopupView(seriesTitle: title) { id, matched in
                handleAniListMatch(selectedID: id)
                matchedTitle = matched
                fetchMetadataIDIfNeeded()
            }
        }
        .sheet(isPresented: $isTMDBMatchingPresented) {
            TMDBMatchPopupView(seriesTitle: title) { id, type, matched in
                tmdbID   = id
                tmdbType = type
                matchedTitle = matched
                fetchMetadataIDIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private var menuContent: some View {
        Group {
            if let provider = activeProvider {
                Text("Matched \(provider): \(matchedTitle ?? title)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if activeProvider == "AniList" {
                Button("Match with AniList") {
                    isMatchingPresented = true
                }
                Button(action: { resetAniListID() }) {
                    Label("Reset AniList ID", systemImage: "arrow.clockwise")
                }
                
                Button(action: { openAniListPage(id: itemID ?? 0) }) {
                    Label("Open in AniList", systemImage: "link")
                }
            }
            else if activeProvider == "TMDB" {
                Button("Match with TMDB") {
                    isTMDBMatchingPresented = true
                }
            }
            
            posterMenuOptions
            
            Divider()
            
            Button(action: { logDebugInfo() }) {
                Label("Log Debug Info", systemImage: "terminal")
            }
        }
    }
    
    @ViewBuilder
    private var posterMenuOptions: some View {
        Group {
            if UserDefaults.standard.string(forKey: "originalPoster_\(href)") != nil {
                Button(action: { restoreOriginalPoster() }) {
                    Label("Original Poster", systemImage: "photo.badge.arrow.down")
                }
            } else {
                Button(action: { fetchTMDBPosterImageAndSet() }) {
                    Label("Use TMDB Poster Image", systemImage: "photo")
                }
            }
        }
    }
    
    private func setupViewOnAppear() {
        buttonRefreshTrigger.toggle()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController?.children.first as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
    
    private func setupInitialData() async {
        do {
            UserDefaults.standard.set(imageUrl, forKey: "mediaInfoImageUrl_\(module.id.uuidString)")
            Logger.shared.log("Saved MediaInfoView image URL: \(imageUrl) for module \(module.id.uuidString)", type: "Debug")
            
            if module.metadata.novel == true {
                if !hasFetched {
                    DispatchQueue.main.async {
                        DropManager.shared.showDrop(
                            title: "Fetching Data",
                            subtitle: "Please wait while fetching.",
                            duration: 0.5,
                            icon: UIImage(systemName: "arrow.triangle.2.circlepath")
                        )
                    }
                }
                let jsContent = try? moduleManager.getModuleContent(module)
                if let jsContent = jsContent {
                    jsController.loadScript(jsContent)
                }
                
                await withTaskGroup(of: Void.self) { group in
                    var detailsLoaded = false
                    
                    group.addTask {
                        await MainActor.run {
                            self.fetchDetails()
                        }
                        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in@Sendable
                            func checkDetails() {
                                Task { @MainActor in
                                    if !(self.synopsis.isEmpty && self.aliases.isEmpty && self.airdate.isEmpty) {
                                        detailsLoaded = true
                                        continuation.resume()
                                    } else {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            checkDetails()
                                        }
                                    }
                                }
                            }
                            checkDetails()
                        }
                    }
                    while true {
                        let loaded = await MainActor.run { detailsLoaded }
                        if loaded { break }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
                DispatchQueue.main.async {
                    self.hasFetched = true
                    self.isLoading = false
                }
            } else {
                let savedCustomID = UserDefaults.standard.integer(forKey: "custom_anilist_id_\(href)")
                if savedCustomID != 0 { customAniListID = savedCustomID }
                if let savedPoster = UserDefaults.standard.string(forKey: "tmdbPosterURL_\(href)") {
                    imageUrl = savedPoster
                }
                if !hasFetched {
                    DropManager.shared.showDrop(
                        title: "Fetching Data",
                        subtitle: "Please wait while fetching.",
                        duration: 0.5,
                        icon: UIImage(systemName: "arrow.triangle.2.circlepath")
                    )
                }
                fetchDetails()
                if savedCustomID != 0 {
                    itemID = savedCustomID
                    activeProvider = "AniList"
                    UserDefaults.standard.set("AniList", forKey: "metadataProviders")
                } else {
                    fetchMetadataIDIfNeeded()
                }
                hasFetched = true
                AnalyticsManager.shared.sendEvent(
                    event: "MediaInfoView",
                    additionalData: ["title": title]
                )
            }
        } catch let loadError {
            isError = true
            isLoading = false
            Logger.shared.log("Error loading media info: \(loadError)", type: "Error")
        }
    }
    
    private func cancelCurrentFetch() {
        activeFetchID = nil
        isFetchingEpisode = false
        showStreamLoadingView = false
        showLoadingAlert = false
    }
    
    private func copyTitleToClipboard() {
        UIPasteboard.general.string = title
        DropManager.shared.showDrop(
            title: "Copied to Clipboard",
            subtitle: "",
            duration: 1.0,
            icon: UIImage(systemName: "doc.on.clipboard.fill")
        )
    }
    
    private func toggleBookmark() {
        libraryManager.toggleBookmark(
            title: title,
            imageUrl: imageUrl,
            href: href,
            moduleId: module.id.uuidString,
            moduleName: module.metadata.sourceName
        )
    }
    
    private func toggleSingleEpisodeWatchStatus() {
        guard let ep = episodeLinks.first else { return }
        let lastPlayedKey = "lastPlayedTime_\(ep.href)"
        let totalTimeKey   = "totalTime_\(ep.href)"
        let last = UserDefaults.standard.double(forKey: lastPlayedKey)
        let total = UserDefaults.standard.double(forKey: totalTimeKey)
        let progress = total > 0 ? last/total : 0
        let watchedEp = ep.number
        
        if progress <= 0.9 {
            UserDefaults.standard.set(99999999.0, forKey: lastPlayedKey)
            UserDefaults.standard.set(99999999.0, forKey: totalTimeKey)
            DropManager.shared.showDrop(title: "Marked as Watched", subtitle: "", duration: 1.0, icon: UIImage(systemName: "checkmark.circle.fill"))
            
            if let listID = itemID, listID > 0 {
                AniListMutation().updateAnimeProgress(animeId: listID, episodeNumber: watchedEp, status: "CURRENT") { result in
                    switch result {
                    case .success:
                        Logger.shared.log("AniList sync: marked ep \(watchedEp) as CURRENT", type: "General")
                    case .failure(let err):
                        Logger.shared.log("AniList sync failed: \(err.localizedDescription)", type: "Error")
                    }
                }
            }
        } else {
            UserDefaults.standard.set(0.0, forKey: lastPlayedKey)
            UserDefaults.standard.set(0.0, forKey: totalTimeKey)
            DropManager.shared.showDrop(title: "Progress Reset", subtitle: "", duration: 1.0, icon: UIImage(systemName: "arrow.counterclockwise"))
            
            if let listID = itemID, listID > 0 {
                AniListMutation().updateAnimeProgress(animeId: listID, episodeNumber: 0, status: "CURRENT") { _ in }
            }
        }
    }
    
    private func downloadSingleEpisode() {
        if let ep = episodeLinks.first {
            let downloadStatus = jsController.isEpisodeDownloadedOrInProgress(
                showTitle: title,
                episodeNumber: ep.number,
                season: 1
            )
            
            if downloadStatus == .notDownloaded {
                downloadSingleEpisodeDirectly(episode: ep)
                DropManager.shared.showDrop(
                    title: "Starting Download",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "arrow.down.circle")
                )
            } else {
                DropManager.shared.showDrop(
                    title: "Already Downloaded",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "checkmark.circle")
                )
            }
        }
    }
    
    private func handleEpisodeSelection(episode: EpisodeLink, isSelected: Bool) {
        if isSelected {
            selectedEpisodes.insert(episode.number)
        } else {
            selectedEpisodes.remove(episode.number)
        }
    }
    
    private func episodeTapAction(ep: EpisodeLink, imageUrl: String) {
        if !isFetchingEpisode {
            selectedEpisodeNumber = ep.number
            selectedEpisodeImage = imageUrl
            fetchStream(href: ep.href)
            AnalyticsManager.shared.sendEvent(
                event: "watch",
                additionalData: ["title": title, "episode": ep.number]
            )
        }
    }
    
    private func markAllPreviousEpisodes(episode: EpisodeLink, index: Int, inSeason: Bool) {
        if inSeason {
            markAllPreviousEpisodesAsWatched(ep: episode, inSeason: true)
        } else {
            markAllPreviousEpisodesInFlatList(ep: episode, index: index)
        }
    }
    
    private func handleAniListMatch(selectedID: Int) {
        self.customAniListID = selectedID
        self.itemID = selectedID
        self.activeProvider = "AniList"
        UserDefaults.standard.set("AniList", forKey: "metadataProviders")
        UserDefaults.standard.set(selectedID, forKey: "custom_anilist_id_\(href)")
        self.fetchDetails()
        isMatchingPresented = false
    }
    
    private func resetAniListID() {
        customAniListID = nil
        itemID = nil
        matchedTitle = nil
        fetchItemID(byTitle: cleanTitle(title)) { result in
            switch result {
            case .success(let id):
                itemID = id
            case .failure(let error):
                Logger.shared.log("Failed to fetch AniList ID: \(error)")
            }
        }
    }
    
    private func openAniListPage(id: Int) {
        if let url = URL(string: "https://anilist.co/anime/\(id)") {
            openSafariViewController(with: url.absoluteString)
        }
    }
    
    private func restoreOriginalPoster() {
        if let originalPoster = UserDefaults.standard.string(forKey: "originalPoster_\(href)") {
            imageUrl = originalPoster
            UserDefaults.standard.removeObject(forKey: "tmdbPosterURL_\(href)")
            UserDefaults.standard.removeObject(forKey: "originalPoster_\(href)")
        }
    }
    
    private func logDebugInfo() {
        Logger.shared.log("""
            Debug Info:
            Title: \(title)
            Href: \(href)
            Module: \(module.metadata.sourceName)
            AniList ID: \(itemID ?? -1)
            Custom ID: \(customAniListID ?? -1)
            Matched Title: \(matchedTitle ?? "—")
            """, type: "Debug")
        DropManager.shared.showDrop(
            title: "Debug Info Logged",
            subtitle: "",
            duration: 1.0,
            icon: UIImage(systemName: "terminal")
        )
    }
    
    private func getBannerImageBasedOnAppearance() -> String {
        let isLightMode = selectedAppearance == .light || (selectedAppearance == .system && colorScheme == .light)
        return isLightMode
        ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
        : "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
    }
    
    private func restoreSelectionState() {
        if let savedStart = UserDefaults.standard.object(forKey: selectedRangeKey) as? Int,
           let savedRange = generateRanges().first(where: { $0.lowerBound == savedStart }) {
            selectedRange = savedRange
        } else {
            selectedRange = generateRanges().first ?? 0..<episodeChunkSize
        }
        
        if let savedSeason = UserDefaults.standard.object(forKey: selectedSeasonKey) as? Int {
            let maxIndex = max(0, groupedEpisodes().count - 1)
            selectedSeason = min(savedSeason, maxIndex)
        }
        
        if let savedChapterStart = UserDefaults.standard.object(forKey: selectedChapterRangeKey) as? Int,
           let savedChapterRange = generateChapterRanges().first(where: { $0.lowerBound == savedChapterStart }) {
            selectedChapterRange = savedChapterRange
        } else {
            selectedChapterRange = generateChapterRanges().first ?? 0..<chapterChunkSize
        }
    }
    
    private func generateRanges() -> [Range<Int>] {
        let chunkSize = episodeChunkSize
        let totalEpisodes = episodeLinks.count
        var ranges: [Range<Int>] = []
        
        for i in stride(from: 0, to: totalEpisodes, by: chunkSize) {
            let end = min(i + chunkSize, totalEpisodes)
            ranges.append(i..<end)
        }
        
        return ranges
    }
    
    private func groupedEpisodes() -> [[EpisodeLink]] {
        guard !episodeLinks.isEmpty else { return [] }
        var groups: [[EpisodeLink]] = []
        var currentGroup: [EpisodeLink] = [episodeLinks[0]]
        
        for ep in episodeLinks.dropFirst() {
            if let last = currentGroup.last, ep.number < last.number {
                groups.append(currentGroup)
                currentGroup = [ep]
            } else {
                currentGroup.append(ep)
            }
        }
        
        groups.append(currentGroup)
        return groups
    }
    
    private func cleanTitle(_ title: String?) -> String {
        guard let title = title else { return "Unknown" }
        
        let cleaned = title.replacingOccurrences(
            of: "\\s*\\([^\\)]*\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        
        return cleaned.isEmpty ? "Unknown" : cleaned
    }
    
    private func playFirstUnwatchedEpisode() {
        if module.metadata.novel ?? false {
            guard !chapters.isEmpty else { return }
            
            var firstUnreadChapter: [String: Any]? = nil
            for chapter in chapters {
                if let href = chapter["href"] as? String {
                    let progress = UserDefaults.standard.double(forKey: "readingProgress_\(href)")
                    if progress < 0.95 {
                        firstUnreadChapter = chapter
                        break
                    }
                }
            }
            
            let chapterToRead = firstUnreadChapter ?? chapters[0]
            
            if let href = chapterToRead["href"] as? String,
               let title = chapterToRead["title"] as? String,
               let number = chapterToRead["number"] as? Int {
                
                UserDefaults.standard.set(true, forKey: "navigatingToReaderView")
                presentReaderView(
                    moduleId: module.id,
                    chapterHref: href,
                    chapterTitle: title,
                    chapters: chapters,
                    mediaTitle: self.title,
                    chapterNumber: number
                )
                
                Logger.shared.log("Navigating to chapter: \(title)", type: "Debug")
            }
            return
        }
        
        let indices = finishedAndUnfinishedIndices()
        let finished = indices.finished
        let unfinished = indices.unfinished
        
        if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
            let nextEp = episodeLinks[finishedIndex + 1]
            selectedEpisodeNumber = nextEp.number
            fetchStream(href: nextEp.href)
            return
        }
        
        if let unfinishedIndex = unfinished {
            let ep = episodeLinks[unfinishedIndex]
            selectedEpisodeNumber = ep.number
            fetchStream(href: ep.href)
            return
        }
        
        if let firstEpisode = episodeLinks.first {
            selectedEpisodeNumber = firstEpisode.number
            fetchStream(href: firstEpisode.href)
        }
    }
    
    private func finishedAndUnfinishedIndices() -> (finished: Int?, unfinished: Int?) {
        var finishedIndex: Int? = nil
        var firstUnfinishedIndex: Int? = nil
        
        for (index, ep) in episodeLinks.enumerated() {
            let keyLast = "lastPlayedTime_\(ep.href)"
            let keyTotal = "totalTime_\(ep.href)"
            let lastPlayedTime = UserDefaults.standard.double(forKey: keyLast)
            let totalTime = UserDefaults.standard.double(forKey: keyTotal)
            
            guard totalTime > 0 else { continue }
            
            let remainingFraction = (totalTime - lastPlayedTime) / totalTime
            if remainingFraction <= 0.1 {
                finishedIndex = index
            } else if firstUnfinishedIndex == nil {
                firstUnfinishedIndex = index
            }
        }
        return (finishedIndex, firstUnfinishedIndex)
    }
    
    private func selectNextEpisode() {
        guard let currentIndex = episodeLinks.firstIndex(where: { $0.number == selectedEpisodeNumber }),
              currentIndex + 1 < episodeLinks.count else {
            Logger.shared.log("No more episodes to play", type: "Info")
            return
        }
        
        let nextEpisode = episodeLinks[currentIndex + 1]
        selectedEpisodeNumber = nextEpisode.number
        fetchStream(href: nextEpisode.href)
        DropManager.shared.showDrop(
            title: "Fetching Next Episode",
            subtitle: "",
            duration: 0.5,
            icon: UIImage(systemName: "arrow.triangle.2.circlepath")
        )
    }
    
    private func markAllPreviousEpisodesAsWatched(ep: EpisodeLink, inSeason: Bool) {
        let userDefaults = UserDefaults.standard
        var updates = [String: Double]()
        
        if inSeason {
            let seasons = groupedEpisodes()
            for ep2 in seasons[selectedSeason] where ep2.number < ep.number {
                let href = ep2.href
                updates["lastPlayedTime_\(href)"] = 99999999.0
                updates["totalTime_\(href)"] = 99999999.0
            }
            
            for (key, value) in updates {
                userDefaults.set(value, forKey: key)
            }
            
            userDefaults.synchronize()
            Logger.shared.log("Marked episodes watched within season \(selectedSeason + 1) of \"\(title)\".", type: "General")
        }
    }
    
    private func markAllPreviousEpisodesInFlatList(ep: EpisodeLink, index: Int) {
        let userDefaults = UserDefaults.standard
        var updates = [String: Double]()
        
        for idx in 0..<index {
            let href = episodeLinks[idx].href
            updates["lastPlayedTime_\(href)"] = 1000.0
            updates["totalTime_\(href)"] = 1000.0
        }
        for (key, value) in updates {
            userDefaults.set(value, forKey: key)
        }
        userDefaults.synchronize()
        NotificationCenter.default.post(name: NSNotification.Name("episodeProgressChanged"), object: nil)
        
        Logger.shared.log(
            "Marked \(ep.number - 1) episodes watched within series \"\(title)\".",
            type: "General"
        )
        
        guard let listID = itemID, listID > 0 else { return }
        let watchedCount = ep.number - 1
        let statusToSend = (watchedCount == episodeLinks.count) ? "COMPLETED" : "CURRENT"
        AniListMutation().updateAnimeProgress(
            animeId: listID,
            episodeNumber: watchedCount,
            status: statusToSend
        ) { result in
            switch result {
            case .success:
                Logger.shared.log(
                    "AniList bulk‐sync: set progress to \(watchedCount) (\(statusToSend))",
                    type: "General"
                )
            case .failure(let error):
                Logger.shared.log(
                    "AniList bulk‐sync failed: \(error.localizedDescription)",
                    type: "Error"
                )
            }
        }
    }
    
    
    private func presentReaderView(moduleId: UUID, chapterHref: String, chapterTitle: String, chapters: [[String: Any]], mediaTitle: String, chapterNumber: Int) {
        UserDefaults.standard.set(true, forKey: "navigatingToReaderView")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            let topVC = findTopViewController.findViewController(rootVC)
            
            if topVC is UIHostingController<ReaderView> {
                Logger.shared.log("ReaderView is already presented, skipping presentation", type: "Debug")
                return
            }
        }
        
        let readerView = ReaderView(
            moduleId: moduleId,
            chapterHref: chapterHref,
            chapterTitle: chapterTitle,
            chapters: chapters,
            mediaTitle: mediaTitle,
            chapterNumber: chapterNumber
        )
        
        let hostingController = UIHostingController(rootView: readerView)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        
        hostingController.isModalInPresentation = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            findTopViewController.findViewController(rootVC).present(hostingController, animated: true)
        }
    }
    
    private func openSafariViewController(with urlString: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            Logger.shared.log("Unable to open the webpage", type: "Error")
            return
        }
        let safariViewController = SFSafariViewController(url: url)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(safariViewController, animated: true, completion: nil)
        }
    }
    
    func fetchDetails() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                let jsContent = try self.moduleManager.getModuleContent(self.module)
                self.jsController.loadScript(jsContent)
                
                let completion: (Any?, [EpisodeLink]) -> Void = { items, episodes in
                    if self.module.metadata.novel ?? false {
                        self.processItemsResponse(items)
                        
                        self.jsController.extractChapters(moduleId: self.module.id, href: self.href) { chapters in
                            DispatchQueue.main.async {
                                self.chapters = chapters
                                Logger.shared.log("fetchDetails: (novel) chapters count = \(self.chapters.count)", type: "Debug")
                                self.restoreSelectionState()
                                
                                self.isLoading = false
                                self.isRefetching = false
                            }
                        }
                    } else {
                        self.handleFetchDetailsResponse(items: items, episodes: episodes)
                    }
                }
                
                if self.module.metadata.asyncJS == true {
                    self.jsController.fetchDetailsJS(url: self.href, completion: completion)
                } else {
                    self.jsController.fetchDetails(url: self.href, completion: completion)
                }
            } catch {
                Logger.shared.log("Error loading module: \(error)", type: "Error")
                self.isLoading = false
                self.isRefetching = false
            }
        }
    }
    
    private func handleFetchDetailsResponse(items: Any?, episodes: [EpisodeLink]) {
        Logger.shared.log("fetchDetails: items = \(String(describing: items))", type: "Debug")
        Logger.shared.log("fetchDetails: episodes = \(episodes)", type: "Debug")
        processItemsResponse(items)
        
        Logger.shared.log("fetchDetails: (episodes) episodes count = \(episodes.count)", type: "Debug")
        episodeLinks = episodes
        restoreSelectionState()
        
        isLoading = false
        isRefetching = false
    }
    
    private func processItemsResponse(_ items: Any?) {
        if let mediaItems = items as? [MediaItem], let item = mediaItems.first {
            synopsis = item.description
            aliases = item.aliases
            airdate = item.airdate
        } else if let str = items as? String {
            parseStringResponse(str)
        } else if let dict = items as? [String: Any] {
            extractMetadataFromDict(dict)
        } else if let arr = items as? [[String: Any]], let dict = arr.first {
            extractMetadataFromDict(dict)
        } else {
            Logger.shared.log("Failed to process items of type: \(type(of: items))", type: "Error")
        }
    }
    
    private func parseStringResponse(_ str: String) {
        guard let data = str.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let dict = arr.first else { return }
        extractMetadataFromDict(dict)
    }
    
    private func extractMetadataFromDict(_ dict: [String: Any]) {
        synopsis = dict["description"] as? String ?? ""
        aliases = dict["aliases"] as? String ?? ""
        airdate = dict["airdate"] as? String ?? ""
    }
    
    private func fetchAniListPosterImageAndSet() {
        guard let listID = itemID, listID > 0 else { return }
        AniListMutation().fetchCoverImage(animeId: listID) { result in
            switch result {
            case .success(let urlString):
                DispatchQueue.main.async {
                    let originalKey = "originalPoster_\(self.href)"
                    UserDefaults.standard.set(self.imageUrl, forKey: originalKey)
                    self.imageUrl = urlString
                }
            case .failure(let err):
                Logger.shared.log("AniList poster fetch failed: \(err.localizedDescription)", type: "Error")
            }
        }
    }
    
    private func fetchAniListIDForSync() {
        let cleaned = cleanTitle(title)
        fetchItemID(byTitle: cleaned) { result in
            switch result {
            case .success(let id):
                DispatchQueue.main.async {
                    if customAniListID == nil {
                        self.itemID = id
                    }
                }
            case .failure(let err):
                Logger.shared.log("AniList sync‐ID fetch failed: \(err.localizedDescription)", type: "Error")
            }
        }
    }
    
    func fetchMetadataIDIfNeeded() {
        let order = metadataProvidersOrder
        let cleanedTitle = cleanTitle(title)
        
        itemID = nil
        tmdbID = nil
        activeProvider = nil
        isError = false
        
        var aniListCompleted = false
        var tmdbCompleted = false
        var aniListSuccess = false
        var tmdbSuccess = false
        
        func checkCompletion() {
            guard aniListCompleted && tmdbCompleted else { return }
            
            let primaryProvider = order.first ?? "TMDB"
            
            if primaryProvider == "AniList" && aniListSuccess {
                activeProvider = "AniList"
                UserDefaults.standard.set("AniList", forKey: "metadataProviders")
            } else if primaryProvider == "TMDB" && tmdbSuccess {
                activeProvider = "TMDB"
                UserDefaults.standard.set("TMDB", forKey: "metadataProviders")
            } else if aniListSuccess {
                activeProvider = "AniList"
                UserDefaults.standard.set("AniList", forKey: "metadataProviders")
            } else if tmdbSuccess {
                activeProvider = "TMDB"
                UserDefaults.standard.set("TMDB", forKey: "metadataProviders")
            } else {
                isError = true
            }
        }
        
        fetchItemID(byTitle: cleanedTitle) { result in
            DispatchQueue.main.async {
                aniListCompleted = true
                switch result {
                case .success(let id):
                    self.itemID = id
                    aniListSuccess = true
                    Logger.shared.log("Successfully fetched AniList ID: \(id)", type: "Debug")
                case .failure(let error):
                    Logger.shared.log("Failed to fetch AniList ID: \(error)", type: "Debug")
                }
                checkCompletion()
            }
        }
        
        tmdbFetcher.fetchBestMatchID(for: cleanedTitle) { id, type in
            DispatchQueue.main.async {
                tmdbCompleted = true
                if let id = id, let type = type {
                    self.tmdbID = id
                    self.tmdbType = type
                    tmdbSuccess = true
                    Logger.shared.log("Successfully fetched TMDB ID: \(id) (type: \(type.rawValue))", type: "Debug")
                } else {
                    Logger.shared.log("Failed to fetch TMDB ID", type: "Debug")
                }
                checkCompletion()
            }
        }
    }
    
    private func fetchItemID(byTitle title: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let query = """
        query {
            Media(search: "\(title)", type: ANIME) {
                id
            }
        }
        """
        
        guard let url = URL(string: "https://graphql.anilist.co") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.custom.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let media = data["Media"] as? [String: Any],
                   let id = media["id"] as? Int {
                    completion(.success(id))
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func fetchTMDBPosterImageAndSet() {
        guard let tmdbID = tmdbID, let tmdbType = tmdbType else { return }
        let apiType = tmdbType.rawValue
        let urlString = "https://api.themoviedb.org/3/\(apiType)/\(tmdbID)?api_key=738b4edd0a156cc126dc4a4b8aea4aca"
        guard let url = URL(string: urlString) else { return }
        
        let tmdbImageWidth = UserDefaults.standard.string(forKey: "tmdbImageWidth") ?? "original"
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let posterPath = json["poster_path"] as? String {
                    let imageUrl: String
                    if tmdbImageWidth == "original" {
                        imageUrl = "https://image.tmdb.org/t/p/original\(posterPath)"
                    } else {
                        imageUrl = "https://image.tmdb.org/t/p/w\(tmdbImageWidth)\(posterPath)"
                    }
                    DispatchQueue.main.async {
                        let currentPosterKey = "originalPoster_\(self.href)"
                        let currentPoster = self.imageUrl
                        UserDefaults.standard.set(currentPoster, forKey: currentPosterKey)
                        self.imageUrl = imageUrl
                        UserDefaults.standard.set(imageUrl, forKey: "tmdbPosterURL_\(self.href)")
                    }
                }
            } catch {
                Logger.shared.log("Failed to parse TMDB poster: \(error.localizedDescription)", type: "Error")
            }
        }.resume()
    }
    
    func fetchStream(href: String) {
        let fetchID = UUID()
        activeFetchID = fetchID
        currentStreamTitle = "Episode \(selectedEpisodeNumber)"
        showLoadingAlert = true
        isFetchingEpisode = true
        
        let completion: ((streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?)) -> Void = { result in
            guard self.activeFetchID == fetchID else { return }
            
            self.showLoadingAlert = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard self.activeFetchID == fetchID else { return }
                
                if let sources = result.sources, !sources.isEmpty {
                    if sources.count > 1 {
                        self.showStreamSelectionAlert(sources: sources, fullURL: href, subtitles: result.subtitles?.first, fetchID: fetchID)
                    } else if let streamUrl = sources[0]["streamUrl"] as? String {
                        let headers = sources[0]["headers"] as? [String: String]
                        self.playStream(url: streamUrl, fullURL: href, subtitles: result.subtitles?.first, headers: headers, fetchID: fetchID)
                    } else {
                        self.handleStreamFailure(error: nil)
                    }
                } else if let streams = result.streams, !streams.isEmpty {
                    if streams.count > 1 {
                        self.showStreamSelectionAlert(sources: streams, fullURL: href, subtitles: result.subtitles?.first, fetchID: fetchID)
                    } else {
                        self.playStream(url: streams[0], fullURL: href, subtitles: result.subtitles?.first, fetchID: fetchID)
                    }
                } else {
                    self.handleStreamFailure(error: nil)
                }
                
                DispatchQueue.main.async {
                    self.isFetchingEpisode = false
                }
            }
        }
        
        Task {
            do {
                let jsContent = try moduleManager.getModuleContent(module)
                jsController.loadScript(jsContent)
                
                if module.metadata.asyncJS == true {
                    jsController.fetchStreamUrlJS(episodeUrl: href, softsub: module.metadata.softsub == true, module: module, completion: completion)
                } else if module.metadata.streamAsyncJS == true {
                    jsController.fetchStreamUrlJSSecond(episodeUrl: href, softsub: module.metadata.softsub == true, module: module, completion: completion)
                } else {
                    jsController.fetchStreamUrl(episodeUrl: href, softsub: module.metadata.softsub == true, module: module, completion: completion)
                }
            } catch {
                self.handleStreamFailure(error: error)
                DispatchQueue.main.async {
                    self.isFetchingEpisode = false
                }
            }
        }
    }
    
    private func handleStreamFailure(error: Error?) {
        DispatchQueue.main.async {
            self.showLoadingAlert = false
            if let error = error {
                Logger.shared.log("Error loading module: \(error)", type: "Error")
                AnalyticsManager.shared.sendEvent(event: "error", additionalData: ["error": error, "message": "Failed to fetch stream"])
            }
            DropManager.shared.showDrop(title: "Stream not Found", subtitle: "", duration: 0.5, icon: UIImage(systemName: "xmark"))
            
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self.isLoading = false
        }
    }
    
    func showStreamSelectionAlert(sources: [Any], fullURL: String, subtitles: String? = nil, fetchID: UUID) {
        guard self.activeFetchID == fetchID else { return }
        
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.activeFetchID == fetchID else { return }
            
            let alert = UIAlertController(title: "Select Server", message: "Choose a server to play from", preferredStyle: .actionSheet)
            
            var index = 0
            var streamIndex = 1
            
            while index < sources.count {
                var title: String = ""
                var streamUrl: String = ""
                var headers: [String:String]? = nil
                
                if let sources = sources as? [String] {
                    if index + 1 < sources.count {
                        if !sources[index].lowercased().contains("http") {
                            title = sources[index]
                            streamUrl = sources[index + 1]
                            index += 2
                        } else {
                            title = "Stream \(streamIndex)"
                            streamUrl = sources[index]
                            index += 1
                        }
                    } else {
                        title = "Stream \(streamIndex)"
                        streamUrl = sources[index]
                        index += 1
                    }
                } else if let sources = sources as? [[String: Any]] {
                    if let currTitle = sources[index]["title"] as? String {
                        title = currTitle
                        streamUrl = (sources[index]["streamUrl"] as? String) ?? ""
                    } else {
                        title = "Stream \(streamIndex)"
                        streamUrl = (sources[index]["streamUrl"] as? String)!
                    }
                    headers = sources[index]["headers"] as? [String:String] ?? [:]
                    index += 1
                }
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    guard self.activeFetchID == fetchID else { return }
                    self.playStream(url: streamUrl, fullURL: fullURL, subtitles: subtitles, headers: headers, fetchID: fetchID)
                })
                
                streamIndex += 1
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.presentAlert(alert)
        }
    }
    
    func playStream(url: String, fullURL: String, subtitles: String? = nil, headers: [String:String]? = nil, fetchID: UUID) {
        guard self.activeFetchID == fetchID else { return }
        
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.activeFetchID == fetchID else { return }
            
            let externalPlayer = UserDefaults.standard.string(forKey: "externalPlayer") ?? "Sora"
            var scheme: String?
            
            switch externalPlayer {
            case "Infuse":
                scheme = "infuse://x-callback-url/play?url=\(url)"
            case "VLC":
                scheme = "vlc://\(url)"
            case "OutPlayer":
                scheme = "outplayer://\(url)"
            case "nPlayer":
                scheme = "nplayer-\(url)"
            case "SenPlayer":
                scheme = "senplayer://x-callback-url/play?url=\(url)"
            case "IINA":
                scheme = "iina://weblink?url=\(url)"
            case "TracyPlayer":
                scheme = "tracy://open?url=\(url)"
            case "Default":
                self.presentDefaultPlayer(url: url, fullURL: fullURL, subtitles: subtitles, headers: headers)
                return
            default:
                break
            }
            
            if let scheme = scheme, let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                Logger.shared.log("Opening external app with scheme: \(url)", type: "General")
            } else {
                self.presentCustomPlayer(url: url, fullURL: fullURL, subtitles: subtitles, headers: headers, fetchID: fetchID)
            }
        }
    }
    
    private func presentDefaultPlayer(url: String, fullURL: String, subtitles: String?, headers: [String:String]?) {
        let isMovie = tmdbType == .movie
        
        let videoPlayerViewController = VideoPlayerViewController(module: module)
        videoPlayerViewController.headers = headers
        videoPlayerViewController.streamUrl = url
        videoPlayerViewController.fullUrl = fullURL
        videoPlayerViewController.episodeNumber = selectedEpisodeNumber
        videoPlayerViewController.seasonNumber = selectedSeason + 1
        videoPlayerViewController.episodeImageUrl = selectedEpisodeImage
        videoPlayerViewController.mediaTitle = title
        videoPlayerViewController.subtitles = subtitles ?? ""
        videoPlayerViewController.aniListID = itemID ?? 0
        videoPlayerViewController.tmdbID = tmdbID
        videoPlayerViewController.isMovie = isMovie
        videoPlayerViewController.seasonNumber = selectedSeason + 1
        videoPlayerViewController.modalPresentationStyle = .fullScreen
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            findTopViewController.findViewController(rootVC).present(videoPlayerViewController, animated: true, completion: nil)
        } else {
            Logger.shared.log("Failed to find root view controller", type: "Error")
            DropManager.shared.showDrop(title: "Error", subtitle: "Failed to present player", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
        }
    }
    
    private func presentCustomPlayer(url: String, fullURL: String, subtitles: String?, headers: [String:String]?, fetchID: UUID) {
        guard let url = URL(string: url) else {
            Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
            DropManager.shared.showDrop(title: "Error", subtitle: "Invalid stream URL", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
            return
        }
        
        guard self.activeFetchID == fetchID else { return }
        let isMovie = tmdbType == .movie
        
        let customMediaPlayer = CustomMediaPlayerViewController(
            module: module,
            urlString: url.absoluteString,
            fullUrl: fullURL,
            title: title,
            episodeNumber: selectedEpisodeNumber,
            onWatchNext: { selectNextEpisode() },
            subtitlesURL: subtitles,
            aniListID: itemID ?? 0,
            totalEpisodes: episodeLinks.count,
            episodeImageUrl: selectedEpisodeImage,
            headers: headers ?? nil
        )
        customMediaPlayer.seasonNumber = selectedSeason + 1
        customMediaPlayer.tmdbID = tmdbID
        customMediaPlayer.isMovie = isMovie
        customMediaPlayer.modalPresentationStyle = .fullScreen
        Logger.shared.log("Opening custom media player with url: \(url)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            findTopViewController.findViewController(rootVC).present(customMediaPlayer, animated: true, completion: nil)
        } else {
            Logger.shared.log("Failed to find root view controller", type: "Error")
            DropManager.shared.showDrop(title: "Error", subtitle: "Failed to present player", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
        }
    }
    
    private func downloadSingleEpisodeDirectly(episode: EpisodeLink) {
        if isSingleEpisodeDownloading { return }
        
        isSingleEpisodeDownloading = true
        DropManager.shared.downloadStarted(episodeNumber: episode.number)
        
        Task {
            do {
                let jsContent = try moduleManager.getModuleContent(module)
                jsController.loadScript(jsContent)
                tryNextSingleDownloadMethod(episode: episode, methodIndex: 0, softsub: module.metadata.softsub == true)
            } catch {
                DropManager.shared.error("Failed to start download: \(error.localizedDescription)")
                isSingleEpisodeDownloading = false
            }
        }
    }
    
    private func tryNextSingleDownloadMethod(episode: EpisodeLink, methodIndex: Int, softsub: Bool) {
        if !isSingleEpisodeDownloading { return }
        
        switch methodIndex {
        case 0:
            if module.metadata.asyncJS == true {
                jsController.fetchStreamUrlJS(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                    self.handleSingleDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
            }
        case 1:
            if module.metadata.streamAsyncJS == true {
                jsController.fetchStreamUrlJSSecond(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                    self.handleSingleDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
            }
        case 2:
            jsController.fetchStreamUrl(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                self.handleSingleDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub)
            }
        default:
            DropManager.shared.error("Failed to find a valid stream for download after trying all methods")
            isSingleEpisodeDownloading = false
        }
    }
    
    private func handleSingleDownloadResult(_ result: (streams: [String]?, subtitles: [String]?, sources: [[String:Any]]?), episode: EpisodeLink, methodIndex: Int, softsub: Bool) {
        if !isSingleEpisodeDownloading { return }
        
        if let sources = result.sources, !sources.isEmpty {
            if sources.count > 1 {
                showSingleDownloadStreamSelectionAlert(streams: sources, episode: episode, subtitleURL: result.subtitles?.first)
                return
            } else if let streamUrl = sources[0]["streamUrl"] as? String, let url = URL(string: streamUrl) {
                let subtitleURLString = sources[0]["subtitle"] as? String
                let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
                startSingleEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
                return
            }
        }
        
        if let streams = result.streams, !streams.isEmpty {
            if streams[0] == "[object Promise]" {
                tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
                return
            }
            
            if streams.count > 1 {
                showSingleDownloadStreamSelectionAlert(streams: streams, episode: episode, subtitleURL: result.subtitles?.first)
                return
            } else if let url = URL(string: streams[0]) {
                let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
                startSingleEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streams[0], subtitleURL: subtitleURL)
                return
            }
        }
        
        tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
    }
    
    private func showSingleDownloadStreamSelectionAlert(streams: [Any], episode: EpisodeLink, subtitleURL: String? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Select Download Server", message: "Choose a server to download Episode \(episode.number) from", preferredStyle: .actionSheet)
            
            var index = 0
            var streamIndex = 1
            
            while index < streams.count {
                var title: String = ""
                var streamUrl: String = ""
                
                if let streams = streams as? [String] {
                    if index + 1 < streams.count && !streams[index].lowercased().contains("http") {
                        title = streams[index]
                        streamUrl = streams[index + 1]
                        index += 2
                    } else {
                        title = "Server \(streamIndex)"
                        streamUrl = streams[index]
                        index += 1
                    }
                } else if let streams = streams as? [[String: Any]] {
                    title = (streams[index]["title"] as? String) ?? "Server \(streamIndex)"
                    streamUrl = (streams[index]["streamUrl"] as? String) ?? ""
                    index += 1
                }
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    guard let url = URL(string: streamUrl) else {
                        DropManager.shared.error("Invalid stream URL selected")
                        self.isSingleEpisodeDownloading = false
                        return
                    }
                    
                    var subtitleURL: URL? = nil
                    if let streams = streams as? [[String: Any]],
                       let subtitleURLString = streams[index-1]["subtitle"] as? String {
                        subtitleURL = URL(string: subtitleURLString)
                    }
                    
                    self.startSingleEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
                })
                
                streamIndex += 1
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.isSingleEpisodeDownloading = false
            })
            
            self.presentAlert(alert)
        }
    }
    
    private func startSingleEpisodeDownloadWithProcessedStream(episode: EpisodeLink, url: URL, streamUrl: String, subtitleURL: URL? = nil) {
        let headers = generateDownloadHeaders(for: url)
        
        fetchEpisodeMetadataForDownload(episode: episode) { metadata in
            let episodeTitle = metadata?.title["en"] ?? "Episode \(episode.number)"
            let episodeImageUrl = metadata?.imageUrl ?? ""
            
            let episodeThumbnailURL: URL?
            if !episodeImageUrl.isEmpty {
                episodeThumbnailURL = URL(string: episodeImageUrl)
            } else {
                episodeThumbnailURL = URL(string: self.getBannerImageBasedOnAppearance())
            }
            
            let showPosterImageURL = URL(string: self.imageUrl)
            
            self.jsController.downloadWithStreamTypeSupport(
                url: url,
                headers: headers,
                title: episodeTitle,
                imageURL: episodeThumbnailURL,
                module: self.module,
                isEpisode: true,
                showTitle: self.title,
                season: 1,
                episode: episode.number,
                subtitleURL: subtitleURL,
                showPosterURL: showPosterImageURL,
                completionHandler: { success, message in
                    if success {
                        Logger.shared.log("Started download for Episode \(episode.number): \(episode.href)", type: "Download")
                        AnalyticsManager.shared.sendEvent(
                            event: "download",
                            additionalData: ["episode": episode.number, "url": streamUrl]
                        )
                    } else {
                        DropManager.shared.error(message)
                    }
                    self.isSingleEpisodeDownloading = false
                }
            )
        }
    }
    
    private func generateDownloadHeaders(for url: URL) -> [String: String] {
        var headers: [String: String] = [:]
        
        if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
            headers = [
                "Origin": module.metadata.baseUrl,
                "Referer": module.metadata.baseUrl,
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Sec-Fetch-Dest": "empty",
                "Sec-Fetch-Mode": "cors",
                "Sec-Fetch-Site": "same-origin"
            ]
        } else {
            if let scheme = url.scheme, let host = url.host {
                let baseUrl = scheme + "://" + host
                headers = [
                    "Origin": baseUrl,
                    "Referer": baseUrl,
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                    "Accept": "*/*",
                    "Accept-Language": "en-US,en;q=0.9",
                    "Sec-Fetch-Dest": "empty",
                    "Sec-Fetch-Mode": "cors",
                    "Sec-Fetch-Site": "same-origin"
                ]
            } else {
                headers = ["User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"]
                Logger.shared.log("Warning: Missing URL scheme/host for episode, using minimal headers", type: "Warning")
            }
        }
        
        return headers
    }
    
    private func fetchEpisodeMetadataForDownload(episode: EpisodeLink, completion: @escaping (EpisodeMetadataInfo?) -> Void) {
        guard let anilistId = itemID else {
            Logger.shared.log("No AniList ID available for episode metadata", type: "Warning")
            completion(nil as EpisodeMetadataInfo?)
            return
        }
        
        fetchEpisodeMetadataFromNetwork(anilistId: anilistId, episodeNumber: episode.number, completion: completion)
    }
    
    private func fetchEpisodeMetadataFromNetwork(anilistId: Int, episodeNumber: Int, completion: @escaping (EpisodeMetadataInfo?) -> Void) {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(anilistId)") else {
            Logger.shared.log("Invalid URL for anilistId: \(anilistId)", type: "Error")
            completion(nil)
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("Failed to fetch episode metadata: \(error)", type: "Error")
                completion(nil as EpisodeMetadataInfo?)
                return
            }
            
            guard let data = data else {
                Logger.shared.log("No data received for episode metadata", type: "Error")
                completion(nil as EpisodeMetadataInfo?)
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeNumber)"] as? [String: Any] else {
                    Logger.shared.log("Episode \(episodeNumber) not found in metadata response", type: "Warning")
                    completion(nil as EpisodeMetadataInfo?)
                    return
                }
                
                var title: [String: String] = [:]
                var image: String = ""
                
                if let titleData = episodeDetails["title"] as? [String: String], !titleData.isEmpty {
                    title = titleData
                } else {
                    title = ["en": "Episode \(episodeNumber)"]
                }
                
                if let imageUrl = episodeDetails["image"] as? String, !imageUrl.isEmpty {
                    image = imageUrl
                }
                
                let metadataInfo = EpisodeMetadataInfo(
                    title: title,
                    imageUrl: image,
                    anilistId: anilistId,
                    episodeNumber: episodeNumber
                )
                
                completion(metadataInfo)
                
            } catch {
                Logger.shared.log("JSON parsing error for episode metadata: \(error.localizedDescription)", type: "Error")
                completion(nil as EpisodeMetadataInfo?)
            }
        }.resume()
    }
    
    private func presentAlert(_ alert: UIAlertController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(
                        x: UIScreen.main.bounds.width / 2,
                        y: UIScreen.main.bounds.height / 2,
                        width: 0,
                        height: 0
                    )
                    popover.permittedArrowDirections = []
                }
            }
            
            findTopViewController.findViewController(rootVC).present(alert, animated: true)
        }
    }
    
    private func generateChapterRanges() -> [Range<Int>] {
        let chunkSize = chapterChunkSize
        let totalChapters = chapters.count
        var ranges: [Range<Int>] = []
        for i in stride(from: 0, to: totalChapters, by: chunkSize) {
            let end = min(i + chunkSize, totalChapters)
            ranges.append(i..<end)
        }
        return ranges
    }
    
    private func markChapterAsRead(href: String, number: Int) {
        UserDefaults.standard.set(1.0, forKey: "readingProgress_\(href)")
        
        UserDefaults.standard.set(1.0, forKey: "scrollPosition_\(href)")
        
        ContinueReadingManager.shared.updateProgress(for: href, progress: 1.0)
        
        DropManager.shared.showDrop(
            title: "Chapter \(number) Marked as Read",
            subtitle: "",
            duration: 1.0,
            icon: UIImage(systemName: "checkmark.circle.fill")
        )
        refreshTrigger.toggle()
    }
    
    private func resetChapterProgress(href: String) {
        UserDefaults.standard.set(0.0, forKey: "readingProgress_\(href)")
        
        UserDefaults.standard.removeObject(forKey: "scrollPosition_\(href)")
        
        ContinueReadingManager.shared.updateProgress(for: href, progress: 0.0)
        
        DropManager.shared.showDrop(
            title: "Progress Reset",
            subtitle: "",
            duration: 1.0,
            icon: UIImage(systemName: "arrow.counterclockwise")
        )
        refreshTrigger.toggle()
    }
    
    private func markAllPreviousChaptersAsRead(currentNumber: Int) {
        let userDefaults = UserDefaults.standard
        var markedCount = 0
        
        for chapter in chapters {
            if let number = chapter["number"] as? Int,
               let href = chapter["href"] as? String {
                if number < currentNumber {
                    userDefaults.set(1.0, forKey: "readingProgress_\(href)")
                    
                    userDefaults.set(1.0, forKey: "scrollPosition_\(href)")
                    
                    ContinueReadingManager.shared.updateProgress(for: href, progress: 1.0)
                    markedCount += 1
                }
            }
        }
        
        userDefaults.synchronize()
        
        DropManager.shared.showDrop(
            title: "Marked \(markedCount) Chapters as Read",
            subtitle: "",
            duration: 1.0,
            icon: UIImage(systemName: "checkmark.circle.fill")
        )
        
        refreshTrigger.toggle()
    }
    
    private func simultaneousGesture(for item: NavigationLink<some View, some View>) -> some View {
        item.simultaneousGesture(TapGesture().onEnded {
            UserDefaults.standard.set(true, forKey: "navigatingToReaderView")
        })
    }
    
    // MARK: - Episode Range Fix for Seasons
    private func generateRanges(for count: Int) -> [Range<Int>] {
        let chunkSize = episodeChunkSize
        var ranges: [Range<Int>] = []
        for i in stride(from: 0, to: count, by: chunkSize) {
            let end = min(i + chunkSize, count)
            ranges.append(i..<end)
        }
        return ranges
    }
    
    private var currentEpisodeList: [EpisodeLink] {
        if isGroupedBySeasons {
            let seasons = groupedEpisodes()
            if selectedSeason < seasons.count {
                return seasons[selectedSeason]
            }
            return []
        } else {
            return episodeLinks
        }
    }
    
    private var episodeRanges: [Range<Int>] {
        generateRanges(for: currentEpisodeList.count)
    }
}
