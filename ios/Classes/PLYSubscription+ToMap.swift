//
//  PLYSubscription+ToMap.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 01/12/2021.
//

import Foundation
import Purchasely

let dateFormatter = DateFormatter()

extension PLYSubscription {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        result["plan"] = plan.toMap
        result["subscriptionSource"] = subscriptionSource.rawValue
        
        if let date = nextRenewalDate {
            result["nextRenewalDate"] = date.string(withFormat:"yyyy-MM-dd'T'HH:mm:ssZ")
        }
        
        if let date = cancelledDate {
            result["cancelledDate"] = date.string(withFormat:"yyyy-MM-dd'T'HH:mm:ssZ")
        }
        
        return result
    }
}

extension Date {
    
    func string(withFormat format: String, withLocale locale: Locale = Locale(identifier: "en_US_POSIX"), timeZone: TimeZone? = TimeZone.current) -> String {
        dateFormatter.dateFormat = format
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        return dateFormatter.string(from: self)
    }
}
