import SwiftUI

struct TermsAgreementView: View {
    var onBack: () -> Void = {}
    var onNext: (TermsAgreementState) -> Void = { _ in }
    var isProcessing = false
    var errorMessage: String?

    @State private var isTermsAgreed = false
    @State private var isPrivacyAgreed = false
    @State private var isAgeAgreed = false
    @State private var isHealthDataAgreed = false
    @State private var isMarketingAgreed = false
    @State private var isPushAgreed = false
    @State private var isSmsAgreed = false
    @State private var selectedAgreementDetail: AgreementDetail?

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    private var isRequiredAgreed: Bool {
        termsAgreementState.isRequiredAgreed
    }

    private var isAllAgreed: Bool {
        isTermsAgreed &&
        isPrivacyAgreed &&
        isAgeAgreed &&
        isHealthDataAgreed &&
        isMarketingAgreed &&
        isPushAgreed &&
        isSmsAgreed
    }

    private var termsAgreementState: TermsAgreementState {
        TermsAgreementState(
            serviceTerms: isTermsAgreed,
            privacyPolicy: isPrivacyAgreed,
            ageOver14: isAgeAgreed,
            healthDataAnalytics: isHealthDataAgreed,
            marketing: isMarketingAgreed,
            notification: isPushAgreed,
            sms: isSmsAgreed
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let contentInset = max(8 * scale, (proxy.size.width - 359 * scale) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    header(scale: scale)
                        .padding(.top, max(proxy.safeAreaInsets.top - 24 * scale, 8 * scale))
                        .padding(.horizontal, contentInset)

                    titleSection(scale: scale)
                        .padding(.top, 18 * scale)
                        .padding(.horizontal, contentInset)

                    allAgreementCard(scale: scale)
                        .padding(.top, 24 * scale)
                        .padding(.horizontal, contentInset)

                    agreementListCard(scale: scale)
                        .padding(.top, 24 * scale)
                        .padding(.horizontal, contentInset)

                    marketingChannels(scale: scale)
                        .padding(.top, 16 * scale)
                        .padding(.horizontal, contentInset)
                        .opacity(isMarketingAgreed ? 1 : 0.45)

                    Spacer(minLength: 0)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11 * scale, weight: .medium))
                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, contentInset)
                            .padding(.bottom, 10 * scale)
                    }

                    nextButton(scale: scale)
                        .padding(.horizontal, contentInset)
                        .padding(.bottom, max(20, 20 * scale))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .onChange(of: isMarketingAgreed) { _, isAgreed in
            isPushAgreed = isAgreed
            isSmsAgreed = isAgreed
        }
        .onChange(of: isPushAgreed) { _, _ in
            updateMarketingAgreementFromChannels()
        }
        .onChange(of: isSmsAgreed) { _, _ in
            updateMarketingAgreementFromChannels()
        }
        .fullScreenCover(item: $selectedAgreementDetail) { detail in
            AgreementDetailView(detail: detail) {
                selectedAgreementDetail = nil
            }
        }
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Spacer()

            pageIndicator(scale: scale)
        }
    }

    private func pageIndicator(scale: CGFloat) -> some View {
        Text("1 / 3")
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

    private func titleSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            Text("Bryki 시작 전\n약관에 동의해주세요")
                .font(.system(size: 24 * scale, weight: .heavy))
                .foregroundStyle(.white)
                .lineSpacing(4 * scale)

            Text("필수 항목 동의 후\n헬스 데이터 권한 화면으로 이동해요")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(4 * scale)
        }
    }

    private func allAgreementCard(scale: CGFloat) -> some View {
        Button {
            toggleAllAgreement()
        } label: {
            HStack(spacing: 16 * scale) {
                CheckCircle(
                    isSelected: isAllAgreed,
                    size: 28 * scale,
                    selectedColor: Color(red: 0.486, green: 0.361, blue: 1)
                )

                VStack(alignment: .leading, spacing: 4 * scale) {
                    Text("약관 전체 동의")
                        .font(.system(size: 15 * scale, weight: .bold))
                        .foregroundStyle(.white)

                    Text("필수 + 선택 항목 모두에 동의합니다")
                        .font(.system(size: 11 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()
            }
            .padding(.horizontal, 16 * scale)
            .frame(height: 64 * scale)
            .background(Color(red: 0.078, green: 0.098, blue: 0.216))
            .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .stroke(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func agreementListCard(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            AgreementRow(
                title: "Bryki 이용약관 동의",
                tag: "필수",
                isRequired: true,
                isSelected: $isTermsAgreed,
                onDetailTapped: {
                    selectedAgreementDetail = .terms
                },
                scale: scale
            )

            DividerLine(scale: scale)

            AgreementRow(
                title: "개인정보 처리방침 동의",
                tag: "필수",
                isRequired: true,
                isSelected: $isPrivacyAgreed,
                onDetailTapped: {
                    selectedAgreementDetail = .privacy
                },
                scale: scale
            )

            DividerLine(scale: scale)

            AgreementRow(
                title: "만 14세 이상 확인",
                tag: "필수",
                isRequired: true,
                isSelected: $isAgeAgreed,
                onDetailTapped: nil,
                scale: scale
            )

            DividerLine(scale: scale)

            AgreementRow(
                title: "헬스 데이터 익명 분석 활용",
                tag: "선택",
                isRequired: false,
                isSelected: $isHealthDataAgreed,
                onDetailTapped: {
                    selectedAgreementDetail = .healthData
                },
                scale: scale
            )

            DividerLine(scale: scale)

            AgreementRow(
                title: "마케팅 정보 수신",
                tag: "선택",
                isRequired: false,
                isSelected: $isMarketingAgreed,
                onDetailTapped: {
                    selectedAgreementDetail = .marketing
                },
                scale: scale
            )
        }
        .padding(.vertical, 10 * scale)
        .frame(height: 320 * scale, alignment: .top)
        .background(Color(red: 0.078, green: 0.098, blue: 0.216))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func marketingChannels(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            Text("마케팅 수신 채널 (선택 시 펼침)")
                .font(.system(size: 10 * scale, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 10 * scale) {
                MarketingChannelButton(
                    title: "앱 푸시",
                    icon: "🔔",
                    isSelected: $isPushAgreed,
                    isEnabled: isMarketingAgreed,
                    scale: scale
                )

                MarketingChannelButton(
                    title: "SMS",
                    icon: "✉️",
                    isSelected: $isSmsAgreed,
                    isEnabled: isMarketingAgreed,
                    scale: scale
                )
            }
        }
    }

    private func nextButton(scale: CGFloat) -> some View {
        Button {
            guard isRequiredAgreed, !isProcessing else { return }
            onNext(termsAgreementState)
        } label: {
            Text(isProcessing ? "처리 중" : "동의하고 계속하기")
                .font(.system(size: 15 * scale, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(
                    LinearGradient(
                        colors: isRequiredAgreed
                        ? [
                            Color(red: 0.49, green: 0.36, blue: 1),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ]
                        : [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isRequiredAgreed || isProcessing)
    }

    private func toggleAllAgreement() {
        let nextValue = !isAllAgreed

        isTermsAgreed = nextValue
        isPrivacyAgreed = nextValue
        isAgeAgreed = nextValue
        isHealthDataAgreed = nextValue
        isMarketingAgreed = nextValue
        isPushAgreed = nextValue
        isSmsAgreed = nextValue
    }

    private func updateMarketingAgreementFromChannels() {
        if !isPushAgreed && !isSmsAgreed {
            isMarketingAgreed = false
        }
    }
}

private struct AgreementRow: View {
    let title: String
    let tag: String
    let isRequired: Bool
    @Binding var isSelected: Bool
    let onDetailTapped: (() -> Void)?
    let scale: CGFloat

    private var accentColor: Color {
        isRequired
        ? Color(red: 0.486, green: 0.361, blue: 1)
        : Color(red: 0.133, green: 0.827, blue: 0.933)
    }

    var body: some View {
        HStack(spacing: 12 * scale) {
            Button {
                isSelected.toggle()
            } label: {
                CheckCircle(
                    isSelected: isSelected,
                    size: 24 * scale,
                    selectedColor: accentColor
                )
            }
            .buttonStyle(.plain)

            Button {
                isSelected.toggle()
            } label: {
                HStack(spacing: 10 * scale) {
                    TagView(
                        title: tag,
                        color: accentColor,
                        scale: scale
                    )

                    Text(title)
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if let onDetailTapped {
                Button(action: onDetailTapped) {
                    Text("›")
                        .font(.system(size: 22 * scale, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 28 * scale, height: 44 * scale)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 52 * scale)
        .padding(.horizontal, 16 * scale)
    }
}

private enum AgreementDetail: Identifiable {
    case terms
    case privacy
    case healthData
    case marketing

    var id: String {
        title
    }

    var title: String {
        switch self {
        case .terms:
            return "Bryki 이용약관"
        case .privacy:
            return "개인정보 처리방침"
        case .healthData:
            return "헬스 데이터 익명 분석 활용"
        case .marketing:
            return "마케팅 정보 수신"
        }
    }
}

private struct AgreementDetailView: View {
    let detail: AgreementDetail
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.055, blue: 0.153)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                            .frame(width: 32, height: 32)

                        Text("←")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 32)

                Text(detail.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                Text("약관 상세 내용은 추후 확정된 문서로 연결합니다.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 16)

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .preferredColorScheme(.dark)
    }
}

private struct CheckCircle: View {
    let isSelected: Bool
    let size: CGFloat
    let selectedColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? selectedColor : .clear)
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? .clear : .white.opacity(0.3),
                            lineWidth: 1.5
                        )
                }

            Text("✓")
                .font(.system(size: size * 0.58, weight: .bold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.15))
        }
        .frame(width: size, height: size)
    }
}

private struct TagView: View {
    let title: String
    let color: Color
    let scale: CGFloat

    var body: some View {
        Text(title)
            .font(.system(size: 9 * scale, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 32 * scale, height: 18 * scale)
            .background(color.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 4 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            }
    }
}

private struct DividerLine: View {
    let scale: CGFloat

    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.05))
            .frame(height: 1)
            .padding(.horizontal, 16 * scale)
    }
}

private struct MarketingChannelButton: View {
    let title: String
    let icon: String
    @Binding var isSelected: Bool
    let isEnabled: Bool
    let scale: CGFloat

    var body: some View {
        Button {
            guard isEnabled else { return }
            isSelected.toggle()
        } label: {
            HStack(spacing: 10 * scale) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 0.133, green: 0.827, blue: 0.933) : .clear)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1.2)
                        }

                    if isSelected {
                        Text("✓")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 16 * scale, height: 16 * scale)

                Text("\(icon)  \(title)")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .background(Color(red: 0.078, green: 0.098, blue: 0.216))
            .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
