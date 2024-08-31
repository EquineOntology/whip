import SwiftUI

struct OverlayContentView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
            Text("Time limit reached. Take a break!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .edgesIgnoringSafeArea(.all)
    }
}
