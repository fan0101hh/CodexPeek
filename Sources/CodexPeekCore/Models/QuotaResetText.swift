import Foundation

public enum QuotaResetText {
    public static func label(date: Date?, windowSeconds: Int, now: Date = Date(),
                             timeZone: TimeZone = .autoupdatingCurrent) -> String {
        guard let date else { return "重置时间：—" }
        guard date > now else { return "等待重置" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        } else if windowSeconds >= 604_800 {
            formatter.dateFormat = "M月d日"
        } else if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
        }
        return "重置时间：" + formatter.string(from: date)
    }
}
