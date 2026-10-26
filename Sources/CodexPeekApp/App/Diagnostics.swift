import CodexPeekCore
import Foundation

enum Diagnostics {
    /// Opt-in real reads; no account identifiers or response bodies are printed.
    static func run() async -> Int32 {
        let settings = PeekSettings.read()
        let store = AccountFileStore(
            stashURL: URL(fileURLWithPath: (settings.stashPath as NSString).expandingTildeInPath),
            authURL: URL(fileURLWithPath: (settings.authPath as NSString).expandingTildeInPath))
        let catalog = store.load()
        print("CodexPeek 只读诊断：发现 \(catalog.credentials.count) 个订阅账号；当前账号\(catalog.currentID == nil ? "未识别" : "已识别")")
        for notice in catalog.notices { print("来源提示：\(notice)") }
        let client = UsageClient()
        var success = 0
        for (index, id) in settings.displayedIDs(in: catalog).enumerated() {
            guard let credential = catalog.credentials.first(where: { $0.account.id == id }) else {
                print("展示位置 \(index + 1)：账号不可用")
                continue
            }
            if credential.isExpired() {
                print("账号 \(index + 1)：授权过期，未发送请求")
                continue
            }
            do {
                let snapshot = try await client.fetch(credential)
                print("账号 \(index + 1)：查询成功；5 小时窗口\(snapshot.fiveHour == nil ? "不可用" : "可用")；周窗口\(snapshot.weekly == nil ? "不可用" : "可用")")
                success += 1
            } catch let error as QuotaError {
                print("账号 \(index + 1)：\(error.localizedDescription)")
            } catch { print("账号 \(index + 1)：查询已取消") }
        }
        return success > 0 ? 0 : 1
    }
}
