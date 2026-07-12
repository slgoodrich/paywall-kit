import StoreKit

public enum SubscriptionMath {
    /// Percent saved by paying `yearlyPrice` once instead of `monthlyPrice` twelve times.
    /// Nil when the yearly plan isn't actually cheaper.
    public static func savingsPercent(yearlyPrice: Decimal, monthlyPrice: Decimal) -> Int? {
        let fullYear = monthlyPrice * 12
        guard fullYear > 0, yearlyPrice < fullYear else { return nil }
        let saving = (fullYear - yearlyPrice) / fullYear * 100
        return Int(NSDecimalNumber(decimal: saving).doubleValue.rounded())
    }

    /// Length of a subscription period in days. Months ≈ 30, years ≈ 365:
    /// display copy, not billing math. Nil for unknown future units.
    static func days(unit: Product.SubscriptionPeriod.Unit, value: Int) -> Int? {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }
}

public extension Product {
    /// "month", "year", "3 months"… localized by StoreKit. Nil for non-subscriptions.
    var periodLabel: String? {
        guard let period = subscription?.subscriptionPeriod else { return nil }
        if period.value == 1 { return subscriptionPeriodUnitFormatStyle.format(period.unit) }
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.weekOfMonth = period.value
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: return nil
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter.string(from: components)
    }

    /// "7-day free trial" when an introductory free trial exists.
    var trialLabel: String? {
        guard let days = trialDays else { return nil }
        return "\(days)-day free trial"
    }

    /// Length of the introductory free trial in days, if any.
    var trialDays: Int? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return SubscriptionMath.days(unit: offer.period.unit, value: offer.period.value)
    }
}
