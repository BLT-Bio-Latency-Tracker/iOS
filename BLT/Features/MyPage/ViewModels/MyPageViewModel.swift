import Combine
import Foundation

@MainActor
final class MyPageViewModel: ObservableObject {
    @Published private(set) var state: MyPageState?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: MyPageService

    init(service: MyPageService? = nil) {
        self.service = service ?? MyPageService()
    }

    func fetchMyPage() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            state = try await service.fetchMyPage()
        } catch {
            errorMessage = "마이페이지 정보를 불러오지 못했어요."
            state = MyPageState.serverPlaceholder
        }
    }
}
