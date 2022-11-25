//
//  PLYProduct+ToMap.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 01/12/2021.
//

import Foundation
import Purchasely

extension PLYProduct {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        
        result["vendorId"] = self.vendorId

        
        var plansDict = [String: Any]()
        self.plans.filter { $0.name != nil }.forEach { plan in
            plansDict[plan.name ?? "unknown"] = plan.toMap
        }
        result["plans"] = plansDict
        
        if let name = self.name {
            result["name"] = name
        }
        return result
    }
}
