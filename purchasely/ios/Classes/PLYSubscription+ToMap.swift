//
//  PLYSubscription+ToMap.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 01/12/2021.
//

import Foundation
import Purchasely

extension PLYSubscription {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        result["plan"] = plan.toMap
        result["subscriptionSource"] = subscriptionSource.rawValue
        result["product"] = product.toMap
        
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = nextRenewalDate {
            result["nextRenewalDate"] = dateFormat.string(from:date)
        }
        
        if let date = cancelledDate {
            result["cancelledDate"] = dateFormat.string(from:date)
        }
        
        return result
    }
}
