import SwiftUI

/// Flat progress bar and interactive scrubber slider for audio tracks.
/// Computes drag offsets in real-time and calls `onSeek` when the drag finishes.
struct ProgressBarView: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragPosition: Double = 0
    
    var effectiveTime: TimeInterval {
        if isDragging {
            return dragPosition * duration
        }
        return currentTime
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = duration > 0 ? min(max(effectiveTime / duration, 0), 1) : 0
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: max(0, width * CGFloat(progress)), height: 4)
                        .cornerRadius(2)
                    
                    Circle()
                        .fill(Color.primary)
                        .frame(width: isDragging ? 16 : 10, height: isDragging ? 16 : 10)
                        .offset(x: max(0, min(width * CGFloat(progress) - (isDragging ? 8 : 5), width - (isDragging ? 16 : 10))))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let clampedX = max(0, min(value.location.x, width))
                            dragPosition = Double(clampedX / width)
                        }
                        .onEnded { _ in
                            let targetTime = dragPosition * duration
                            onSeek(targetTime)
                            currentTime = targetTime
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)
            
            HStack {
                Text(formatTime(effectiveTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("-" + formatTime(max(0, duration - effectiveTime)))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, time >= 0 else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
