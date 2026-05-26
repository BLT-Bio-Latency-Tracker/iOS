import Foundation

struct MyPageService {
    func fetchMyPage() async throws -> MyPageState {
        // TODO: 마이페이지 API가 확정되면 서버 응답 DTO를 MyPageState로 매핑합니다.
        MyPageState.serverPlaceholder
    }

    func updateProfile(_ request: MyPageProfilePatchRequest) async throws {
        // TODO: 프로필 수정 API가 확정되면 변경된 필드만 서버 DTO로 매핑해 저장합니다.
        _ = request
    }
}
