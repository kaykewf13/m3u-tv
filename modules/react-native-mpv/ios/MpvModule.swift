import Foundation
import React

@objc(MpvModule)
class MpvModule: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool {
        return false
    }

    @objc func isAvailable(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
        resolve(true)
    }
}
