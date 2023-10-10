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
        
        result["metadata"] = getPresentationMetadata(self.metadata)
        
        return result
    }
    
    private func getPresentationMetadata(_ metadata:  PLYPresentationMetadata?) -> [String : Any?] {
        guard let metadata = metadata else { return [:] }
        
        let rawMetadata = metadata.getRawMetadata()
        var resultDict: [String: Any?] = [:]
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: 0)

        for (key, value) in rawMetadata {
            if let stringValue = value as? String {
                group.enter() // Enter the dispatch group before making the async call

                metadata.getString(with: key) { result in
                    resultDict[key] = result
                    group.leave() // Leave the dispatch group after the async call is completed
                }
            } else {
                resultDict[key] = value
            }
        }

        group.notify(queue: DispatchQueue.global(qos: .default)) {
            semaphore.signal()
        }

        // Wait until all async calls are completed
        semaphore.wait()
        
        return resultDict
    }
}
