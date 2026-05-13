import SwiftUI

struct ProfileSetupView: View {
    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.055, blue: 0.153)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Profile Setup")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)

                Text("프로필 설정 화면은 추후 디자인 확정 후 구현합니다.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }
}
