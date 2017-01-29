//
//  Backend.swift
//  Bolt
//
//  Created by Elliott Bolzan on 2/27/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import Foundation
import AWSLambda
import AWSSNS

class Backend {

    // MARK: Authentification

    class func newUser(first_phone: String, second_phone: String, completionHandler: (String) -> ()) {
        if let endpoint =  defaults.objectForKey("my_endpoint") as? String {
            let invocationRequest = AWSLambdaInvokerInvocationRequest()
            invocationRequest.functionName = "bolt"
            invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
            invocationRequest.payload = ["call": "newUser", "first_phone" : first_phone, "second_phone": second_phone, "endpoint": endpoint]
            let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
            _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                if let payload = task.result?.payload! as? NSDictionary {
                    if payload["error"] != nil { completionHandler("error") }
                    else if payload["endpoint"] != nil {
                        defaults.setObject(payload["id"], forKey: "id")
                        defaults.setObject(payload["endpoint"], forKey: "roommate_endpoint")
                        defaults.setObject(first_phone, forKey: "my_phone")
                        defaults.setObject(second_phone, forKey: "roommate_phone")
                        let owner = ContactMagic.getOwnerOfNumber(makeNumeric(second_phone))
                        if owner == nil { defaults.setObject(nil, forKey: "contact") }
                        else {  defaults.setObject(NSKeyedArchiver.archivedDataWithRootObject(owner!), forKey: "contact") }
                        sendNotification("Your room is ready. Start using Bolt now! 👍", sound: "free.caf") { success in
                            completionHandler("room")
                        }
                    }
                    else {
                        defaults.setObject(payload["id"], forKey: "id")
                        defaults.setObject(first_phone, forKey: "my_phone")
                        defaults.setObject(second_phone, forKey: "roommate_phone")
                        let owner = ContactMagic.getOwnerOfNumber(makeNumeric(second_phone))
                        if owner == nil { defaults.setObject(nil, forKey: "contact") }
                        else {  defaults.setObject(NSKeyedArchiver.archivedDataWithRootObject(owner!), forKey: "contact") }
                        completionHandler("id")
                    }
                }
                else { completionHandler("error") }
                return nil
            }
        }
        else { completionHandler("error") }
    }

    class func cancelRequest(completionHandler: (Bool) -> ()) {
        if let my_phone = defaults.objectForKey("my_phone") as? String {
            let invocationRequest = AWSLambdaInvokerInvocationRequest()
            invocationRequest.functionName = "bolt"
            invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
            invocationRequest.payload = ["call": "cancelRequest", "phone": my_phone]
            let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
            _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                if let _ = task.result?.payload! as? NSDictionary {
                    completionHandler(false)
                }
                else {
                    defaults.setObject(nil, forKey: "roommate_phone")
                    completionHandler(true)
                }
                return nil
            }
        }
        else {
            completionHandler(false)
        }
    }

    class func disbandRoom(completionHandler: (Bool) -> ()) {
        if let room_id = defaults.objectForKey("room_id") as? Int {
            let invocationRequest = AWSLambdaInvokerInvocationRequest()
            invocationRequest.functionName = "bolt"
            invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
            invocationRequest.payload = ["call": "disbandRoom", "room_id": room_id]
            let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
            _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                if let _ = task.result?.payload! as? NSDictionary {
                    completionHandler(false)
                }
                else {
                    sendNotification("Your roommate left you. 💔 We're sorry!", sound: "bolt.caf")  { success in
                        clearDefaults()
                        completionHandler(true)
                    }
                }
                return nil
            }
        }
        else {
            completionHandler(false)
        }
    }

    class func getEndpoint(completionHandler: (Bool) -> ()) {
        if let roommate_phone = defaults.objectForKey("roommate_phone") as? String {
            let invocationRequest = AWSLambdaInvokerInvocationRequest()
            invocationRequest.functionName = "bolt"
            invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
            invocationRequest.payload = ["call": "getEndpoint", "phone": roommate_phone]
            let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
            _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                if let payload = task.result?.payload! as? NSDictionary {
                    if payload["endpoint"] != nil {
                        defaults.setObject(payload["endpoint"], forKey: "roommate_endpoint")
                        completionHandler(true)
                    }
                    else {
                        completionHandler(false)
                    }
                }
                else {
                    completionHandler(false)
                }
                return nil
            }
        }
        else {
            completionHandler(false)
        }
    }

    // MARK: Room State

    class func listRooms(phone: String = defaults.objectForKey("my_phone") as! String, completionHandler: (String) -> ()) {
        let invocationRequest = AWSLambdaInvokerInvocationRequest()
        invocationRequest.functionName = "bolt"
        invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
        invocationRequest.payload = ["call": "listRooms", "phone": phone]
        let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
        _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
            if let payload = task.result?.payload! as? NSDictionary {
                if payload["error"] != nil {
                    completionHandler("error")
                }
                else if payload["first_phone"] == nil {
                    defaults.setObject(payload["id"], forKey: "room_id")
                    defaults.setObject(nil, forKey: "requestedMe")
                    completionHandler("room")
                }
                else {
                    if payload["first_phone"] as! String == phone {
                        defaults.setObject(payload["second_phone"], forKey: "requestedMe")
                    }
                    else {
                        defaults.setObject(payload["first_phone"], forKey: "requestedMe")
                    }
                    completionHandler("requestedMe")
                }
            }
            else {
                defaults.setObject(nil, forKey: "requestedMe")
                completionHandler("noRequests")
            }
            return nil
        }
    }

    class func getState(completionHandler: (String) -> ()) {
        if let room_id = defaults.objectForKey("room_id") as? Int {
            let invocationRequest = AWSLambdaInvokerInvocationRequest()
            invocationRequest.functionName = "bolt"
            invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
            invocationRequest.payload = ["call": "getState", "room_id": room_id]
            let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
            _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                if let payload = task.result?.payload! as? NSDictionary {
                    if payload["error"] != nil {
                        completionHandler("error")
                    }
                    else if payload["state"] != nil {
                        defaults.setObject(payload["state"], forKey: "state")
                        defaults.setObject(payload["by"], forKey: "by")
                        completionHandler("state")
                    }
                }
                else {
                    clearDefaults()
                    completionHandler("empty")
                }
                return nil
            }
        }
        else {
            completionHandler("error")
        }
    }

    class func changeState(state: Int, completionHandler: (Bool) -> ()) {
        if let id = defaults.objectForKey("id") as? Int, room_id = defaults.objectForKey("room_id") as? Int {
            let invocationRequest = AWSLambdaInvokerInvocationRequest()
            invocationRequest.functionName = "bolt"
            invocationRequest.invocationType = AWSLambdaInvocationType.RequestResponse
            let payload: [String:AnyObject] = ["call": "changeState", "state": state, "by": id, "room_id": room_id]
            invocationRequest.payload = payload
            let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
            _ = lambdaInvoker.invoke(invocationRequest).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                if let _ = task.result?.payload! as? NSDictionary {
                    completionHandler(false)
                }
                else {
                    defaults.setObject(state, forKey: "state")
                    defaults.setObject(defaults.integerForKey("id"), forKey: "by")
                    if state == 0 {
                        sendNotification("Your room is free! 🎉", sound: "free.caf") { success in
                            completionHandler(true)
                        }
                    }
                    else {
                        sendNotification("Your room is bolted. 🔑", sound: "bolt.caf", category: "BOLTED")  { success in
                            completionHandler(true)
                        }
                    }
                }
                return nil
            }
        }
        else {
            completionHandler(false)
        }
    }

    class func requestRoom(completionHandler: (Bool) -> ()) {
        sendNotification("Could you free the room? 🙏", sound: "free.caf", category: "REQUESTED") { success in
            completionHandler(success)
        }
    }

    // MARK: Notifications

    class func sendNotification(message: String, sound: String, category: String = "default", completionHandler: (Bool) -> ()) {
        if let roommate_endpoint = defaults.objectForKey("roommate_endpoint") as? String {
            let publishCall = AWSSNS.defaultSNS()
            let payload = AWSSNSPublishInput()
            payload.targetArn = roommate_endpoint
            payload.messageStructure = "json"
            let dict = ["default": "The default message", "APNS": "{\"aps\":{\"alert\": \"" + message + "\",\"sound\":\"" + sound + "\",\"category\":\"" + category + "\",\"badge\":\"1\"} }"]
            do {
                let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: .PrettyPrinted)
                payload.message = (NSString(data: jsonData, encoding: NSUTF8StringEncoding) as! String)
                publishCall.publish(payload).continueWithBlock() { (task: AWSTask) -> AWSTask! in
                    if task.error != nil { completionHandler(false) }
                    else { completionHandler(true) }
                    return nil
                }
            } catch { completionHandler(false) }
        }
        else { completionHandler(false) }
    }

}