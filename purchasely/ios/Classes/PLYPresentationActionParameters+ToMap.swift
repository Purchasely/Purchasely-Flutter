//
//  PLYPresentationActionParameters+ToMap.swift
//  purchasely_flutter
//
//  Created by Mathieu LANOY on 13/01/2022.
//

import Foundation
import Purchasely

extension PLYPresentationActionParameters {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        
        if let url = url?.absoluteString {
            result["url"] = url
        }

        if let plan = plan {
            result["plan"] = plan.toMap
        }
                
        if let title = title {
            result["title"] = title
        }
        
        if let presentation = presentation {
            result["presentation"] = presentation
        }
        
        if let promoOffer = promoOffer {
            var offerMap = [String: Any]()
            offerMap["vendorId"] = promoOffer.vendorId
            offerMap["storeOfferId"] = promoOffer.storeOfferId
            result["offer"] = offerMap
        }

        if let queryParameterKey = queryParameterKey {
            result["queryParameterKey"] = queryParameterKey
        }

        if let clientReferenceId = clientReferenceId {
            result["clientReferenceId"] = clientReferenceId
        }

        let webCheckoutProviderString: String
        switch webCheckoutProvider {
        case .stripe:
            webCheckoutProviderString = "stripe"
        case .other:
            webCheckoutProviderString = "other"
        case .none:
            webCheckoutProviderString = "none"
        }
        result["webCheckoutProvider"] = webCheckoutProviderString
        
        return result
    }
    
}
