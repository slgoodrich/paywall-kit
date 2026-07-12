/// Display model consumed by the paywall templates. Real plans are built by
/// `SubscriptionStore.load()`; hand-built ones drive SwiftUI previews and screenshots.
public struct SubscriptionPlan: Identifiable, Equatable {
    public let id: String
    public var name: String
    public var price: String
    public var periodLabel: String?
    public var trialLabel: String?
    public var trialDays: Int?
    public var savingsBadge: String?

    public init(
        id: String,
        name: String,
        price: String,
        periodLabel: String? = nil,
        trialLabel: String? = nil,
        trialDays: Int? = nil,
        savingsBadge: String? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.periodLabel = periodLabel
        self.trialLabel = trialLabel
        self.trialDays = trialDays
        self.savingsBadge = savingsBadge
    }
}
