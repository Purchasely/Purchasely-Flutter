//
//  PLYPlan+ToDict.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 01/12/2021.
//

import Foundation
import Purchasely

extension PLYPlan {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        result["vendorId"] = self.vendorId
        
        result["hasIntroductoryPrice"] =  self.hasIntroductoryPrice
        result["type"] = self.type.rawValue
        
        if let introAmount = self.introAmount?.intValue, introAmount == 0, self.hasIntroductoryPrice {
            result.removeValue(forKey: "hasIntroductoryPrice")
            result["hasFreeTrial"] = true
        }
        
        if let name = self.name {
            result["name"] = name
        }

        if let productId = self.appleProductId {
            result["productId"] = productId
        }
        
        if let price = self.localizedFullPrice(language: nil) {
            result["price"] = price
        }
        
        if let amount = self.amount {
            result["amount"] = amount
        }

        if let localizedAmount = self.localizedPrice(language: nil) {
            result["localizedAmount"] = localizedAmount
        }
        
        if let introAmount = self.introAmount {
            result["introAmount"] = introAmount
        }
        
        if let currencyCode = self.currencyCode {
            result["currencyCode"] = currencyCode
        }
        
        if let currencySymbol = self.currencySymbol {
            result["currencySymbol"] = currencySymbol
        }
        
        if let period = self.localizedPeriod(language: nil) {
            result["period"] = period
        }
        
        if let introPrice = self.localizedFullIntroductoryPrice(language: nil) {
            result["introPrice"] = introPrice
        }
        
        if let introDuration = self.localizedIntroductoryDuration(language: nil) {
            result["introDuration"] = introDuration
        }
        
        if let introPeriod = self.localizedIntroductoryPeriod(language: nil) {
            result["introPeriod"] = introPeriod
        }

        // Apple commitment installment details (iOS 26.4+ "monthly subscription
        // with N-month commitment"). Empty on non-Apple stores / older iOS.
        if !self.commitmentInfo.isEmpty {
            result["commitmentInfo"] = self.commitmentInfoMaps
        }

        return result
    }

    /// Serializes `commitmentInfo` into the same wire shape the Dart
    /// `plyCommitmentInfoFromMap` parses. Reused by the interceptor payload.
    var commitmentInfoMaps: [[String: Any]] {
        self.commitmentInfo.map { info in
            [
                "billingPlanType": info.billingPlanType.wireValue,
                "billingPrice": info.billingPrice.doubleValue,
                "billingPeriod": info.billingPeriod,
                "totalPrice": info.totalPrice.doubleValue,
                "totalPeriod": info.totalPeriod,
                "totalDuration": info.totalDuration,
            ]
        }
    }
}

extension PLYBillingPlanType {
    /// Wire value sent to the Dart bridge, matching the native SDK's own
    /// string form (`"up_front"` / `"monthly"`).
    var wireValue: String {
        switch self {
        case .upFront: return "up_front"
        case .monthly: return "monthly"
        default:       return "unspecified"
        }
    }
}
