//
//  PLYPresentationInfo+ToMap.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 13/01/2022.
//

import Foundation
import Purchasely

extension PLYPresentationInfo {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        
        if let contentId = contentId {
            result["contentId"] = contentId
        }

        if let presentationId = presentationId {
            result["presentationId"] = presentationId
        }
                
        if let placementId = placementId {
            result["placementId"] = placementId
        }
        
        return result
    }
    
}
