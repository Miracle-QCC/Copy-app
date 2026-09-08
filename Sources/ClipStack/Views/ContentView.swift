import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipboardStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } content: {
            HistoryListView(store: store)
                .navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 460)
        } detail: {
            DetailView(store: store)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("显示或隐藏侧栏")
            }

            ToolbarItem(placement: .principal) {
                SearchField(text: $store.searchText)
                    .frame(width: 320)
            }

            ToolbarItemGroup {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("清除未收藏的历史记录")
                .disabled(store.items.allSatisfy(\.isFavorite))

                Menu {
                    Button(store.isMonitoring ? "暂停剪贴板记录" : "继续剪贴板记录") {
                        if store.isMonitoring {
                            store.stopMonitoring()
                        } else {
                            store.startMonitoring()
                        }
                    }
                    Divider()
                    Text("最多保留 500 条记录")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "清除剪贴板历史？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除未收藏记录", role: .destructive) {
                store.clearHistory()
            }
        } message: {
            Text("收藏的记录会被保留，此操作无法撤销。")
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索剪贴板历史", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandIcon(size: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 1) {
                    Text("ClipStack")
                        .font(.headline)
                    Text("剪贴板历史")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)

            List(SidebarFilter.allCases, selection: $store.selectedFilter) { filter in
                Label {
                    HStack {
                        Text(filter.title)
                        Spacer()
                        Text(count(for: filter).formatted())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: filter.symbol)
                        .foregroundStyle(filter == store.selectedFilter ? .white : .secondary)
                }
                .tag(filter)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(store.isMonitoring ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(store.isMonitoring ? "实时记录中" : "记录已暂停")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(.ultraThinMaterial)
    }

    private func count(for filter: SidebarFilter) -> Int {
        store.items.filter(filter.matches).count
    }
}

private struct HistoryListView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedFilter.title)
                        .font(.title2.bold())
                    Text("\(store.filteredItems.count) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()

            if store.filteredItems.isEmpty {
                ContentUnavailableView {
                    Label(
                        store.searchText.isEmpty ? "暂无记录" : "没有搜索结果",
                        systemImage: store.searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass"
                    )
                } description: {
                    Text(store.searchText.isEmpty
                         ? "复制文本、链接、代码或图片即可开始记录"
                         : "换一个关键词或筛选条件试试")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.filteredItems) { item in
                            ClipboardRow(
                                item: item,
                                isSelected: store.selectedItemID == item.id,
                                onSelect: { store.selectedItemID = item.id },
                                onCopy: { store.copy(item) },
                                onFavorite: { store.toggleFavorite(item) },
                                onDelete: { store.delete(item) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .onChange(of: store.selectedFilter) {
            store.selectedItemID = store.filteredItems.first?.id
        }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PreviewIcon(item: item)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Spacer()
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                if let text = item.text, item.type != .link {
                    Text(text.replacingOccurrences(of: "\n", with: " "))
                        .font(item.type == .code ? .system(.caption, design: .monospaced) : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if item.type == .image {
                    Text("\(item.byteCount.byteCountDescription) 图片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(item.sourceApp ?? "未知来源")
                    Text("·")
                    Text(item.createdAt.relativeClipboardDescription)
                    if item.copyCount > 1 {
                        Text("·")
                        Text("复制 \(item.copyCount) 次")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(nsColor: .textBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.65) : .primary.opacity(0.06), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onCopy)
        .contextMenu {
            Button("复制", action: onCopy)
            Button(item.isFavorite ? "取消收藏" : "收藏", action: onFavorite)
            Divider()
            Button("删除", role: .destructive, action: onDelete)
        }
    }
}

private struct PreviewIcon: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.type.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint.opacity(0.12))
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var tint: Color {
        switch item.type {
        case .text: .blue
        case .link: .purple
        case .image: .orange
        case .code: .green
        }
    }
}

private struct DetailView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        Group {
            if let item = store.selectedItem {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label(item.type.title, systemImage: item.type.symbol)
                            .font(.headline)
                        Spacer()
                        Button {
                            store.toggleFavorite(item)
                        } label: {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(item.isFavorite ? "取消收藏" : "收藏")

                        Button {
                            store.delete(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("删除")
                    }
                    .padding(20)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            content(for: item)

                            Divider()

                            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                                metadataRow("来源", item.sourceApp ?? "未知")
                                metadataRow("时间", item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                metadataRow("大小", item.byteCount.byteCountDescription)
                                metadataRow("使用次数", "\(item.copyCount)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    HStack {
                        Text("双击记录也可以复制")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            store.copy(item)
                        } label: {
                            Label("复制到剪贴板", systemImage: "doc.on.doc")
                                .frame(minWidth: 118)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(18)
                }
            } else {
                ContentUnavailableView {
                    Label("选择一条记录", systemImage: "cursorarrow.click.2")
                } description: {
                    Text("在中间列表中选择内容以查看完整预览")
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func content(for item: ClipboardItem) -> some View {
        if let image = item.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 640, maxHeight: 440)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }
        } else {
            Text(item.text ?? "")
                .font(item.type == .code
                      ? .system(size: 14, design: .monospaced)
                      : .system(size: 16))
                .textSelection(.enabled)
                .lineSpacing(5)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    item.type == .code
                        ? Color(nsColor: .textBackgroundColor)
                        : Color.primary.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.tertiary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
