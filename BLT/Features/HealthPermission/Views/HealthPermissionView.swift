import SwiftUI

struct HealthPermissionView: View {
    enum CompletionReason {
        case permissionRequested
        case skipped
    }

    @StateObject private var viewModel = HealthPermissionViewModel()
    @State private var shouldShowPermissionResultGuide = false
    @State private var shouldShowPVTOnlyGuide = false

    let onComplete: (CompletionReason) -> Void

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let contentWidth = min(proxy.size.width - 24, 351 * scale)
            let horizontalInset = max(12, (proxy.size.width - contentWidth) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, 56 * scale)
                        .padding(.horizontal, horizontalInset)

                    iconView(scale: scale)
                        .padding(.top, 36 * scale)

                    titleSection(scale: scale)
                        .padding(.top, 32 * scale)
                        .padding(.horizontal, horizontalInset)

                    benefitCard(scale: scale)
                        .padding(.top, 40 * scale)
                        .padding(.horizontal, horizontalInset)

                    Spacer(minLength: 0)

                    permissionButton(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 20 * scale)

                    laterButton(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, max(55, 55 * scale))
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Spacer()

                        Text(errorMessage)
                            .font(.system(size: 12 * scale, weight: .medium))
                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, horizontalInset)
                            .padding(.bottom, 96 * scale)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .alert("권한 설정이 완료되었습니다", isPresented: $shouldShowPermissionResultGuide) {
            Button("확인") {
                onComplete(.permissionRequested)
            }
        } message: {
            Text("권한을 허용하지 않은 경우에는 수면/HRV 데이터 없이 PVT 단독 모드로 진행됩니다. 권한은 건강 앱 > 공유 > 앱 > BLT에서 나중에 변경할 수 있습니다.")
        }
        .alert("PVT 단독 모드로 진행합니다", isPresented: $shouldShowPVTOnlyGuide) {
            Button("확인") {
                onComplete(.skipped)
            }
        } message: {
            Text("HealthKit 권한 요청은 건너뜁니다. 이후 결과는 수면/HRV 데이터 없이 PVT 측정값만으로 계산될 수 있습니다.")
        }
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Spacer()

            Text("1 / 2")
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 56 * scale, height: 22 * scale)
                .background(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.18))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.4), lineWidth: 1)
                }
        }
    }

    private func iconView(scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .fill(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.18))
                .frame(width: 64 * scale, height: 64 * scale)

            Text("♥")
                .font(.system(size: 36 * scale, weight: .bold))
                .foregroundStyle(Color(red: 0.486, green: 0.361, blue: 1))
        }
        .frame(width: 64 * scale, height: 64 * scale)
    }

    private func titleSection(scale: CGFloat) -> some View {
        VStack(spacing: 20 * scale) {
            Text("Apple Health 데이터로\n더 정확한 측정을")
                .font(.system(size: 26 * scale, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(5 * scale)

            Text("수면 시간 / REM·깊은 수면 비율을 사용해\nBrain ROI 정확도가 30% 향상됩니다")
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(4 * scale)
        }
        .frame(maxWidth: .infinity)
    }

    private func benefitCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            benefitText("✓  수면 시간 / 단계별 분포", scale: scale)
                .padding(.top, 20 * scale)

            benefitText("✓  기상 시간 (자동 감지)", scale: scale)
                .padding(.top, 14 * scale)

            benefitText("✓  심박변이도", scale: scale)
                .padding(.top, 14 * scale)

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.top, 25 * scale)
        }
        .padding(.horizontal, 18 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 156 * scale, alignment: .top)
        .background(Color(red: 0.078, green: 0.098, blue: 0.216))
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func benefitText(_ text: String, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 14 * scale, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
    }

    private func permissionButton(scale: CGFloat) -> some View {
        Button {
            Task {
                let didRequest = await viewModel.requestHealthKitPermission()

                if didRequest {
                    shouldShowPermissionResultGuide = true
                }
            }
        } label: {
            Text(viewModel.isRequestingPermission ? "요청 중" : "허용하기")
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(Color(red: 0.486, green: 0.361, blue: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRequestingPermission)
    }

    private func laterButton(scale: CGFloat) -> some View {
        Button {
            Task {
                await viewModel.skipHealthKitPermission()
                shouldShowPVTOnlyGuide = true
            }
        } label: {
            Text("나중에 할게요")
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .frame(height: 17 * scale)
        }
        .buttonStyle(.plain)
    }
}
