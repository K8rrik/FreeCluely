import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    appState.historyWindow?.close()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            
            // List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.history) { session in
                        HistoryItemView(session: session, isHovered: hoveredItemId == session.id)
                            .onTapGesture {
                                appState.currentSession = session
                                appState.historyWindow?.close()
                            }
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredItemId = session.id
                                } else if hoveredItemId == session.id {
                                    hoveredItemId = nil
                                }
                            }
                            .contextMenu {
                                Button("Delete") {
                                    if let index = appState.history.firstIndex(where: { $0.id == session.id }) {
                                        appState.deleteHistoryItem(at: IndexSet(integer: index))
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct HistoryItemView: View {
    let session: ChatSession
    let isHovered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(previewText)
                .lineLimit(2)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(session.timestamp, formatter: Self.dateFormatter)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(isHovered ? 0.2 : 0.05), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        // Attempt to set Perm timezone, fallback to current if not found or if user prefers local
        if let permTimeZone = TimeZone(identifier: "Asia/Yekaterinburg") {
            formatter.timeZone = permTimeZone
        }
        return formatter
    }()
    
    var previewText: String {
        if let firstMsg = session.messages.first {
            return firstMsg.text.isEmpty ? "New Chat" : firstMsg.text
        }
        return "Empty Chat"
    }
}
