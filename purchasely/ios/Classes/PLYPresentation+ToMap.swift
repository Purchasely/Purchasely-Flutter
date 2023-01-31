//
//  PLYPresentation+ToMap.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 27/01/2023.
//

import Foundation
import Purchasely

extension PLYPresentation {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        
        if let id = self.id {
            result["id"] = id
        }
        
        if let placementId = self.placementId {
            result["placementId"] = placementId
        }
        
        if let audienceId = self.audienceId {
            result["audienceId"] = audienceId
        }
        
        if let abTestId = self.abTestId {
            result["abTestId"] = abTestId
        }
        
        if let abTestVariantId = self.abTestVariantId {
            result["abTestVariantId"] = abTestVariantId
        }
        
        result["language"] = language
        
        result["plans"] = self.plans
        
        result["type"] = self.type.rawValue
        
        return result
    }
}

