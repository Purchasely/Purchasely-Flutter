//
//  PLYOfferSignature+ToMap.swift
//  Purchasely_Example
//
//  Created by Florian Huet on 20/09/2023.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import Purchasely

extension PLYOfferSignature {
    
    var toMap: [String: Any] {
        var result = [String: Any]()
        result["planVendorId"] = planVendorId
        result["identifier"] = identifier
        result["signature"] = signature
        result["nonce"] = nonce
        result["keyIdentifier"] = keyIdentifier
        result["timestamp"] = timestamp
        return result
    }
}