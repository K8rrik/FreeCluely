import SwiftUI

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(0.6))
            .frame(width: AppConstants.UI.buttonSize, height: AppConstants.UI.buttonSize)
            .padding(AppConstants.UI.buttonPadding)
            .background(Color.white.opacity(configuration.isPressed ? 0.2 : 0.0))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
