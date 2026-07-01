import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var notificationStore = AppNotificationStore.shared
    @State private var isTodoSheetPresented = false

    var onPVTStart: () -> Void = {}
    var onNotificationTap: () -> Void = {}
    var onProfileTap: () -> Void = {}

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let headerTopPadding = max(30 * scale, 68 * scale - proxy.safeAreaInsets.top)
            let warningText = viewModel.roiDisplay.warningText
            let usesCompactTodoLayout = warningText != nil

            ZStack {
                Color.bltBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header(scale: scale)
                            .padding(.top, headerTopPadding)
                            .padding(.horizontal, 4 * scale)

                        roiSummary(scale: scale)
                            .padding(.top, 27 * scale)

                        if let alertText = warningText {
                            roiFocusAlert(alertText, scale: scale)
                                .padding(.top, 10 * scale)
                        }

                        todoSection(scale: scale, isCompact: usesCompactTodoLayout)
                            .padding(.top, 13 * scale)

                        pvtStartButton(scale: scale)
                            .padding(.top, (usesCompactTodoLayout ? 20 : 28) * scale)
                            .padding(.bottom, max(36, 36 * scale))
                    }
                    .padding(.horizontal, horizontalInset)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isTodoSheetPresented) {
            HomeTodoEditorSheet(
                suggestedDifficulty: viewModel.focusStrategy.recommendedDefaultDifficulty,
                focusStrategy: viewModel.focusStrategy,
                onAdd: { title, difficulty in
                    viewModel.addTodo(title: title, difficulty: difficulty)
                }
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .presentationBackground(Color.bltCard)
        }
        .onReceive(timer) { date in
            viewModel.updateCurrentDate(date)
        }
        .task {
            await viewModel.loadHealthKitSleepSummary()
        }
    }

    private func header(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(viewModel.greetingText)
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Text("\(viewModel.state.userName)님")
                    .font(.system(size: 22 * scale, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8 * scale) {
                Button(action: onNotificationTap) {
                    ZStack(alignment: .topTrailing) {
                        Text("🔔")
                            .font(.system(size: 20 * scale))
                            .frame(width: 36 * scale, height: 36 * scale)
                            .background(Color.bltCard)
                            .clipShape(Circle())

                        if notificationStore.hasUnreadNotifications {
                            Circle()
                                .fill(Color.bltNotificationBadge)
                                .frame(width: 6 * scale, height: 6 * scale)
                                .offset(x: -4 * scale, y: 4 * scale)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("알림")

                Button(action: onProfileTap) {
                    Text(viewModel.state.profileInitial)
                        .font(.system(size: 20 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36 * scale, height: 36 * scale)
                        .background(Color.bltPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("마이페이지")
            }
        }
    }

    private func roiSummary(scale: CGFloat) -> some View {
        let roiDisplay = viewModel.roiDisplay
        let roiColor = color(for: roiDisplay.accent)
        let changeColor = changeColor(for: roiDisplay.changeDirection)

        return VStack(alignment: .leading, spacing: 10 * scale) {
            HStack(spacing: 8 * scale) {
                Circle()
                    .fill(roiColor)
                    .frame(width: 8 * scale, height: 8 * scale)

                Text("BRAIN ROI")
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .tracking(0.6 * scale)
                    .foregroundStyle(Color.bltMutedText)

                Text(roiDisplay.score.map(String.init) ?? "미측정")
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundStyle(roiColor)
                    .padding(.leading, 4 * scale)

                if roiDisplay.score != nil {
                    Text("· \(roiDisplay.statusText)")
                        .font(.system(size: 11 * scale, weight: .regular))
                        .foregroundStyle(statusColor(for: roiDisplay.accent))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8 * scale)

                if roiDisplay.score != nil {
                    Text(roiDisplay.changeText)
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .foregroundStyle(changeColor)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .background(Color.bltCard)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.bltBorder, lineWidth: 1)
            }

            Text(viewModel.measurementSummaryText)
                .font(.system(size: 10 * scale, weight: .regular))
                .foregroundStyle(Color.bltSubtleText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.leading, 12 * scale)
        }
    }

    private func roiFocusAlert(_ text: String, scale: CGFloat) -> some View {
        Text("⚠️  \(text)")
            .font(.system(size: 11 * scale, weight: .regular))
            .foregroundStyle(Color.bltWarningRed.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38 * scale)
        .background(Color.bltWarningRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .stroke(Color.bltWarningRed.opacity(0.3), lineWidth: 1)
        }
    }

    private func todoSection(scale: CGFloat, isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TODAY'S TO-DO")
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .tracking(1.2 * scale)
                    .foregroundStyle(Color.bltMutedText)

                Spacer()

                if !viewModel.todoItems.isEmpty {
                    Text("\(viewModel.todoItems.count)")
                        .font(.system(size: 13 * scale, weight: .bold))
                        .foregroundStyle(Color.bltPrimary)
                }
            }
            .padding(.horizontal, 20 * scale)
            .padding(.top, 20 * scale)

            if viewModel.todoItems.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 20 * scale)
                    .padding(.top, 14 * scale)

                emptyTodoContent(scale: scale)
            } else {
                todoListContent(scale: scale)
                    .padding(.top, 22 * scale)

                Spacer(minLength: 10 * scale)

                addTodoButton(scale: scale)
                    .padding(.horizontal, 20 * scale)
                    .padding(.bottom, 20 * scale)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: (isCompact ? 350 : 395) * scale)
        .background(Color.bltCard)
        .clipShape(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24 * scale, style: .continuous)
                .stroke(Color.bltBorder, lineWidth: 1)
        }
    }

    private func emptyTodoContent(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34 * scale)

            Text("📋")
                .font(.system(size: 32 * scale))
                .frame(width: 72 * scale, height: 72 * scale)
                .background(Color.bltBackground)
                .clipShape(Circle())

            Text("오늘의 할 일을 등록해보세요")
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 22 * scale)

            Button {
                isTodoSheetPresented = true
            } label: {
                Text("+ 투두 등록하기")
                    .font(.system(size: 16 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 218 * scale, height: 52 * scale)
                    .background(gradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 22 * scale)

            Text("뇌 점수 기반으로 최적 업무 순서를 추천해드려요")
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.bltMutedText.opacity(0.45))
                .padding(.top, 18 * scale)

            Spacer(minLength: 26 * scale)
        }
        .frame(maxWidth: .infinity)
    }

    private func todoListContent(scale: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10 * scale) {
                ForEach(viewModel.todoItems) { item in
                    TodoRow(
                        item: item,
                        isFocused: viewModel.focusStrategy.isFocused(item.difficulty),
                        scale: scale,
                        onToggle: {
                            viewModel.toggleTodo(item)
                        },
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.deleteTodo(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20 * scale)
            .padding(.bottom, 4 * scale)
        }
        .frame(maxHeight: .infinity)
    }

    private func addTodoButton(scale: CGFloat) -> some View {
        Button {
            isTodoSheetPresented = true
        } label: {
            Text("+ 할 일 추가")
                .font(.system(size: 13 * scale, weight: .regular))
                .foregroundStyle(Color.bltMutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 28 * scale)
                .frame(height: 36 * scale)
                .background(Color.bltBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pvtStartButton(scale: CGFloat) -> some View {
        Button(action: onPVTStart) {
            Text("⚡ 30초 PVT 측정하기")
                .font(.system(size: 22 * scale, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 76 * scale)
                .background(gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color.bltPrimary, Color.bltCyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func color(for accent: HomeROIAccent) -> Color {
        switch accent {
        case .unmeasured:
            return Color.bltMutedText
        case .warning:
            return Color.bltWarningRed
        case .caution:
            return Color.bltAmber
        case .stable:
            return Color.bltPositive
        }
    }

    private func statusColor(for accent: HomeROIAccent) -> Color {
        switch accent {
        case .unmeasured:
            return Color.bltMutedText
        case .warning:
            return Color.bltWarningRed
        case .caution:
            return Color.bltAmber
        case .stable:
            return Color.bltMutedText
        }
    }

    private func changeColor(for direction: HomeROIChangeDirection) -> Color {
        switch direction {
        case .positive:
            return Color.bltPositive
        case .neutral:
            return Color.bltSubtleText
        case .negative:
            return Color.bltWarningRed
        }
    }
}

private struct TodoRow: View {
    let item: HomeTodoItem
    let isFocused: Bool
    let scale: CGFloat
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var isDeleteRevealed = false

    private var deleteWidth: CGFloat {
        62 * scale
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth, height: 50 * scale)
                    .background(Color.bltWarningRed)
                    .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(horizontalOffset < -1 ? 1 : 0)
            .disabled(horizontalOffset >= -1)
            .accessibilityLabel("할 일 삭제")

            rowContent
                .contentShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
                .onTapGesture {
                    if isDeleteRevealed {
                        closeDeleteAction()
                    } else {
                        onToggle()
                    }
                }
            .offset(x: horizontalOffset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            return
                        }

                        let baseOffset = isDeleteRevealed ? -deleteWidth : 0
                        horizontalOffset = min(0, max(-deleteWidth, baseOffset + value.translation.width))
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            withAnimation(.easeOut(duration: 0.18)) {
                                horizontalOffset = isDeleteRevealed ? -deleteWidth : 0
                            }
                            return
                        }

                        let shouldReveal = horizontalOffset < -deleteWidth * 0.45 || value.predictedEndTranslation.width < -deleteWidth

                        withAnimation(.easeOut(duration: 0.18)) {
                            isDeleteRevealed = shouldReveal
                            horizontalOffset = shouldReveal ? -deleteWidth : 0
                        }
                    }
            )
        }
        .clipped()
        .accessibilityLabel("\(item.title), 난이도 \(item.difficulty.title)")
        .accessibilityValue(item.isCompleted ? "완료됨" : "미완료")
        .accessibilityHint(isFocused ? "현재 점수에서 추천되는 할 일입니다." : "현재 뇌 점수에서는 우선순위가 낮은 할 일입니다.")
        .accessibilityAction(named: item.isCompleted ? "미완료로 변경" : "완료로 변경") {
            onToggle()
        }
        .accessibilityAction(named: isDeleteRevealed ? "삭제 버튼 숨기기" : "삭제 버튼 보이기") {
            withAnimation(.easeOut(duration: 0.18)) {
                isDeleteRevealed.toggle()
                horizontalOffset = isDeleteRevealed ? -deleteWidth : 0
            }
        }
        .accessibilityAction(named: "삭제") {
            onDelete()
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14 * scale) {
            ZStack {
                RoundedRectangle(cornerRadius: 7 * scale, style: .continuous)
                    .fill(item.isCompleted ? difficultyColor : Color.clear)
                    .frame(width: 22 * scale, height: 22 * scale)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7 * scale, style: .continuous)
                            .stroke(difficultyColor.opacity(isFocused ? 0.9 : 0.35), lineWidth: 1.2)
                    }

                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11 * scale, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(item.title)
                    .font(.system(size: 15 * scale, weight: .bold))
                    .foregroundStyle(.white.opacity(isFocused ? 0.95 : 0.36))
                    .strikethrough(item.isCompleted, color: .white.opacity(0.85))
                    .lineLimit(1)

                if !isFocused {
                    Text("뇌 점수 부족")
                        .font(.system(size: 10 * scale, weight: .regular))
                        .foregroundStyle(Color.bltWarningRed.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(item.difficulty.title)
                .font(.system(size: 13 * scale, weight: .bold))
                .foregroundStyle(difficultyColor.opacity(isFocused ? 1 : 0.38))
                .frame(width: 28 * scale, height: 28 * scale)
                .background(difficultyColor.opacity(isFocused ? 0.18 : 0.045))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 50 * scale)
        .background(
            isFocused
            ? difficultyColor.opacity(0.12)
            : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(isFocused ? difficultyColor.opacity(0.42) : Color.clear, lineWidth: 1)
        }
    }

    private func closeDeleteAction() {
        withAnimation(.easeOut(duration: 0.18)) {
            isDeleteRevealed = false
            horizontalOffset = 0
        }
    }

    private var difficultyColor: Color {
        color(for: item.difficulty)
    }

    private func color(for difficulty: HomeTodoDifficulty) -> Color {
        switch difficulty {
        case .high:
            return Color.bltWarningRed
        case .medium:
            return Color.bltAmber
        case .low:
            return Color.bltPositive
        }
    }
}

private struct HomeTodoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var isTitleFocused = false
    @State private var selectedDifficulty: HomeTodoDifficulty

    private static let maxTitleLength = 15

    let focusStrategy: HomeTodoFocusStrategy
    let onAdd: (String, HomeTodoDifficulty) -> Void

    init(
        suggestedDifficulty: HomeTodoDifficulty,
        focusStrategy: HomeTodoFocusStrategy,
        onAdd: @escaping (String, HomeTodoDifficulty) -> Void
    ) {
        _selectedDifficulty = State(initialValue: suggestedDifficulty)
        self.focusStrategy = focusStrategy
        self.onAdd = onAdd
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 390

            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 40 * scale, height: 4 * scale)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10 * scale)

                HStack {
                    Text("할 일 추가")
                        .font(.system(size: 17 * scale, weight: .heavy))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 32 * scale, height: 32 * scale)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24 * scale)
                .padding(.top, 14 * scale)

                todoTextField(scale: scale)
                    .padding(.horizontal, 24 * scale)
                    .padding(.top, 12 * scale)

                HStack {
                    Text("최대 15자까지 입력 가능해요")
                    Spacer()
                    Text("\(min(title.count, Self.maxTitleLength)) / \(Self.maxTitleLength)")
                }
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.bltMutedText.opacity(0.48))
                .padding(.horizontal, 24 * scale)
                .padding(.top, 8 * scale)

                Text("난이도 선택")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color.bltMutedText.opacity(0.7))
                    .padding(.horizontal, 24 * scale)
                    .padding(.top, 22 * scale)

                HStack(spacing: 8 * scale) {
                    ForEach(HomeTodoDifficulty.allCases) { difficulty in
                        DifficultySelectionCard(
                            difficulty: difficulty,
                            isSelected: selectedDifficulty == difficulty,
                            scale: scale
                        ) {
                            selectedDifficulty = difficulty
                        }
                    }
                }
                .padding(.horizontal, 24 * scale)
                .padding(.top, 14 * scale)

                selectedDifficultyHint(scale: scale)
                    .padding(.horizontal, 24 * scale)
                    .padding(.top, 12 * scale)

                Button {
                    guard canAdd else { return }
                    onAdd(Self.limitedTitle(title), selectedDifficulty)
                    dismiss()
                } label: {
                    Text("할 일 등록하기")
                        .font(.system(size: 17 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56 * scale)
                        .background {
                            if canAdd {
                                gradient
                            } else {
                                Color.bltMutedText.opacity(0.2)
                            }
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .padding(.horizontal, 24 * scale)
                .padding(.top, 12 * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(Color.bltCard)
            .contentShape(Rectangle())
            .onTapGesture {
                isTitleFocused = false
            }
            .onAppear {
                isTitleFocused = true
            }
            .onChange(of: title) { _, newValue in
                let limitedValue = Self.limitedTitle(newValue)
                if limitedValue != newValue {
                    title = limitedValue
                }
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color.bltPrimary, Color.bltCyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func todoTextField(scale: CGFloat) -> some View {
        HStack(spacing: 12 * scale) {
            Rectangle()
                .fill(Color.bltPrimary)
                .frame(width: 2 * scale, height: 22 * scale)

            LimitedTodoTitleField(
                text: $title,
                isFocused: $isTitleFocused,
                maxLength: Self.maxTitleLength,
                fontSize: 16 * scale
            )
            .frame(maxWidth: .infinity)
            .frame(height: 24 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .frame(height: 58 * scale)
        .background(Color.bltBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .stroke(Color.bltPrimary.opacity(0.65), lineWidth: 1.5)
        }
    }

    private static func limitedTitle(_ value: String) -> String {
        String(value.prefix(maxTitleLength))
    }

    private func selectedDifficultyHint(scale: CGFloat) -> some View {
        HStack(spacing: 8 * scale) {
            Text("💡")
                .font(.system(size: 14 * scale))

            Text(focusStrategy.recommendationMessage(for: selectedDifficulty))
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(difficultyColor(for: selectedDifficulty).opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38 * scale)
        .background(difficultyColor(for: selectedDifficulty).opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                .stroke(difficultyColor(for: selectedDifficulty).opacity(0.22), lineWidth: 1)
        }
    }

    private func difficultyColor(for difficulty: HomeTodoDifficulty) -> Color {
        switch difficulty {
        case .high:
            return Color.bltWarningRed
        case .medium:
            return Color.bltAmber
        case .low:
            return Color.bltPositive
        }
    }
}

private struct LimitedTodoTitleField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let maxLength: Int
    let fontSize: CGFloat

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.backgroundColor = .clear
        textField.textColor = UIColor.white.withAlphaComponent(0.88)
        textField.tintColor = UIColor(red: 0.486, green: 0.361, blue: 1, alpha: 1)
        textField.font = .systemFont(ofSize: fontSize, weight: .regular)
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.accessibilityLabel = "할 일 이름"
        textField.accessibilityHint = "최대 15자까지 입력할 수 있습니다."
        textField.accessibilityValue = textField.text ?? ""
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self

        if textField.text != text {
            textField.text = text
        }

        textField.font = .systemFont(ofSize: fontSize, weight: .regular)
        textField.accessibilityValue = text

        if isFocused, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !isFocused, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LimitedTodoTitleField

        init(parent: LimitedTodoTitleField) {
            self.parent = parent
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let currentText = textField.text,
                  let textRange = Range(range, in: currentText) else {
                return false
            }

            let nextText = currentText.replacingCharacters(in: textRange, with: string)
            return nextText.count <= parent.maxLength
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.isFocused = false
            textField.resignFirstResponder()
            return true
        }

        @objc
        func textDidChange(_ textField: UITextField) {
            let limitedText = String((textField.text ?? "").prefix(parent.maxLength))

            if textField.text != limitedText {
                textField.text = limitedText
            }

            parent.text = limitedText
        }
    }
}

private struct DifficultySelectionCard: View {
    let difficulty: HomeTodoDifficulty
    let isSelected: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10 * scale) {
                    Text(difficulty.title)
                        .font(.system(size: 24 * scale, weight: .heavy))
                        .foregroundStyle(color.opacity(isSelected ? 1 : 0.55))

                    Text(difficulty.subtitle)
                        .font(.system(size: 10 * scale, weight: .regular))
                        .foregroundStyle(color.opacity(isSelected ? 0.78 : 0.38))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 84 * scale)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11 * scale, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.top, 8 * scale)
                        .padding(.trailing, 10 * scale)
                }
            }
            .background(color.opacity(isSelected ? 0.14 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                    .stroke(color.opacity(isSelected ? 0.65 : 0.22), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(difficulty.title) 난이도")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
        .accessibilityHint(difficulty.subtitle)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var color: Color {
        switch difficulty {
        case .high:
            return Color.bltWarningRed
        case .medium:
            return Color.bltAmber
        case .low:
            return Color.bltPositive
        }
    }
}

private extension Color {
    static let bltBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let bltCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let bltBorder = Color(red: 0.11, green: 0.133, blue: 0.29)
    static let bltPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let bltCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let bltPositive = Color(red: 0.063, green: 0.722, blue: 0.506)
    static let bltAmber = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let bltWarningRed = Color(red: 1, green: 0.267, blue: 0.267)
    static let bltNotificationBadge = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let bltMutedText = Color(red: 0.62, green: 0.66, blue: 0.82)
    static let bltSubtleText = Color(red: 0.42, green: 0.46, blue: 0.62)
}
