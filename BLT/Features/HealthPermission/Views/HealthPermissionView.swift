import SwiftUI

struct HealthPermissionView: View {
    enum CompletionReason {
        case permissionRequested
        case skipped
    }

    @StateObject private var viewModel = HealthPermissionViewModel()
    @State private var isSkipSheetPresented = false

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
        .sheet(isPresented: $isSkipSheetPresented) {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / designWidth, 1.08)

                skipHealthKitSheet(scale: scale)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color(red: 0.078, green: 0.098, blue: 0.216))
            .preferredColorScheme(.dark)
        }
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Spacer()

            Text("2 / 3")
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
                    onComplete(.permissionRequested)
                }
            }
        } label: {
            Text(viewModel.isRequestingPermission ? "요청 중" : "허용하기")
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.36, blue: 1),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRequestingPermission)
    }

    private func laterButton(scale: CGFloat) -> some View {
        Button {
            isSkipSheetPresented = true
        } label: {
            Text("나중에 할게요")
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .frame(height: 17 * scale)
        }
        .buttonStyle(.plain)
    }

    private func skipHealthKitSheet(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.18))
                    .frame(width: 72 * scale, height: 72 * scale)

                Text("🧠")
                    .font(.system(size: 28 * scale, weight: .regular))
                    .frame(width: 36 * scale, height: 36 * scale)
            }
            .padding(.top, 24 * scale)

            Text("수면 연동 없이 시작해요")
                .font(.system(size: 20 * scale, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16 * scale)

            Text("HealthKit 없이도 PVT 반응 검사만으로\n뇌 컨디션을 측정할 수 있어요.")
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4 * scale)
                .frame(maxWidth: .infinity)
                .padding(.top, 10 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text("💡  HealthKit 연결 시 정확도 +30% ↑")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color(red: 0.133, green: 0.831, blue: 0.929).opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 12 * scale)

                Text("수면 심도·REM·HRV 데이터를 추가 활용해 더 정확한 ROI 계산")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineSpacing(3 * scale)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9 * scale)
            }
            .padding(.horizontal, 16 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 72 * scale, alignment: .top)
            .background(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                    .stroke(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.3), lineWidth: 1)
            }
            .padding(.horizontal, 24 * scale)
            .padding(.top, 20 * scale)

            Button {
                Task {
                    let didRequest = await viewModel.requestHealthKitPermission()

                    if didRequest {
                        isSkipSheetPresented = false
                        onComplete(.permissionRequested)
                    }
                }
            } label: {
                Text(viewModel.isRequestingPermission ? "요청 중" : "수면 연동하기")
                    .font(.system(size: 16 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56 * scale)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.486, green: 0.361, blue: 1),
                                Color(red: 0.133, green: 0.831, blue: 0.929)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRequestingPermission)
            .opacity(viewModel.isRequestingPermission ? 0.7 : 1)
            .padding(.horizontal, 24 * scale)
            .padding(.top, 16 * scale)

            Button {
                viewModel.skipHealthKitPermission()
                isSkipSheetPresented = false
                onComplete(.skipped)
            } label: {
                Text("무시하고 계속하기")
                    .font(.system(size: 14 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32 * scale)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRequestingPermission)
            .padding(.top, 8 * scale)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.078, green: 0.098, blue: 0.216))
    }
}
