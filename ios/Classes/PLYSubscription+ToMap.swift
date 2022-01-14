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
        
        if let date = nextRenewalDate {
            result["nextRenewalDate"] = date.timeIntervalSince1970
        }
        
        if let date = cancelledDate {
            result["cancelledDate"] = date.timeIntervalSince1970
        }
        
        return result
    }
}
