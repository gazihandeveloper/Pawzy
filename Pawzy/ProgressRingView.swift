//
//  ProgressRingView.swift
//  Pawzy
//
//  Progress Ring bileşeni — Canvas/Circle stroke ile çizim
//

import SwiftUI

struct ProgressRingView: View {
    let completed: Int
    let total: Int
    let size: CGFloat

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private let trackColor = Color.pzBlueGradientStart.opacity(0.35)
    private let fillColor = Color.white
    private let strokeWidth: CGFloat = 8

    var body: some View {
        ZStack {
            // Track (arka plan çember)
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)

            // Fill (ilerleme çemberi)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(fillColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.6), value: progress)

            // Merkez metni
            Text("\(completed)/\(total)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .accessibilityLabel("\(completed)/\(total) \(L.string("tamamlandı"))")
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(progress * 100))% \(L.string("tamamlandı"))")
    }
}

#Preview {
    ProgressRingView(completed: 3, total: 4, size: 74)
        .padding()
        .background(Color.pzBlueGradientStart)
}
