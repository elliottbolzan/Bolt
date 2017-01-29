//
//  AppDelegate.swift
//  Bolt
//
//  Created by Elliott Bolzan on 2/27/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import UIKit
import AWSSNS
import NetReachability

var reachability: NetReachability = NetReachability(hostname: "www.google.com")
let defaults = NSUserDefaults.standardUserDefaults()
let matteBlack = UIColor(red: 29.0/255, green: 29.0/255, blue: 29.0/256, alpha: 1)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // Launch and Setup

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Use Cognito

        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: CognitoRegionType,
            identityPoolId: CognitoIdentityPoolId)
        let defaultServiceConfiguration = AWSServiceConfiguration(
            region: DefaultServiceRegionType,
            credentialsProvider: credentialsProvider)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = defaultServiceConfiguration

        // Reset Badge

        UIApplication.sharedApplication().applicationIconBadgeNumber = 0

        // Register for Interactive Notifications

        if defaults.objectForKey("1.0.1") == nil { self.register() }

        return true
    }

    func applicationWillEnterForeground(application: UIApplication) {
        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
    }

    // Handle Notifications

    func application(application: UIApplication, handleActionWithIdentifier identifier: String?,  forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if notification.category == "REMINDER" || notification.category == "REQUESTED" {
            if identifier == "FREE" {
                Backend.changeState(0) { success in
                    print(success)
                }
            }
        }
        else if notification.category == "BOLTED" {
            if identifier == "REQUEST" {
                Backend.requestRoom() { success in
                    print(success)
                }
            }
        }
        completionHandler()
    }

    // Register for Notifications

    func register() {

        let notificationActionFree: UIMutableUserNotificationAction = UIMutableUserNotificationAction()
        notificationActionFree.identifier = "FREE"
        notificationActionFree.title = "Free"
        notificationActionFree.destructive = false
        notificationActionFree.authenticationRequired = false
        notificationActionFree.activationMode = UIUserNotificationActivationMode.Background

        let notificationActionRequest: UIMutableUserNotificationAction = UIMutableUserNotificationAction()
        notificationActionRequest.identifier = "REQUEST"
        notificationActionRequest.title = "Request"
        notificationActionRequest.destructive = false
        notificationActionRequest.authenticationRequired = false
        notificationActionRequest.activationMode = UIUserNotificationActivationMode.Background

        let notificationActionCancel: UIMutableUserNotificationAction = UIMutableUserNotificationAction()
        notificationActionCancel.identifier = "NOT_NOW"
        notificationActionCancel.title = "Not Now"
        notificationActionCancel.destructive = true
        notificationActionCancel.authenticationRequired = false
        notificationActionCancel.activationMode = UIUserNotificationActivationMode.Background

        let reminderCategory: UIMutableUserNotificationCategory = UIMutableUserNotificationCategory()
        reminderCategory.identifier = "REMINDER"
        reminderCategory.setActions([notificationActionFree, notificationActionCancel], forContext: UIUserNotificationActionContext.Default)
        reminderCategory.setActions([notificationActionFree, notificationActionCancel], forContext: UIUserNotificationActionContext.Minimal)

        let requestedCategory: UIMutableUserNotificationCategory = UIMutableUserNotificationCategory()
        requestedCategory.identifier = "REQUESTED"
        requestedCategory.setActions([notificationActionFree, notificationActionCancel], forContext: UIUserNotificationActionContext.Default)
        requestedCategory.setActions([notificationActionFree, notificationActionCancel], forContext: UIUserNotificationActionContext.Minimal)

        let boltedCategory: UIMutableUserNotificationCategory = UIMutableUserNotificationCategory()
        boltedCategory.identifier = "BOLTED"
        boltedCategory.setActions([notificationActionRequest, notificationActionCancel], forContext: UIUserNotificationActionContext.Default)
        boltedCategory.setActions([notificationActionRequest, notificationActionCancel], forContext: UIUserNotificationActionContext.Minimal)

        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: (NSSet(array:[reminderCategory, requestedCategory, boltedCategory]) as! Set<UIUserNotificationCategory>)
            ))
        UIApplication.sharedApplication().registerForRemoteNotifications()
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let deviceTokenString = "\(deviceToken)"
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString:"<>"))
            .stringByReplacingOccurrencesOfString(" ", withString: "")
        defaults.setObject(deviceTokenString, forKey: "deviceToken")
        let sns = AWSSNS.defaultSNS()
        let request = AWSSNSCreatePlatformEndpointInput()
        request.token = deviceTokenString
        request.platformApplicationArn = SNSPlatformApplicationArn
        sns.createPlatformEndpoint(request).continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print("Error: \(task.error)")
            } else {
                let createEndpointResponse = task.result as! AWSSNSCreateEndpointResponse
                defaults.setObject(createEndpointResponse.endpointArn, forKey: "my_endpoint")
            }
            return nil
        })
    }

    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print("Failed to register with error: \(error)")
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        if let result = userInfo["aps"]! as? NSDictionary {
            let notification = String(result["alert"]!)
            print(notification)
            if notification == "Your room is ready. Start using Bolt now! 👍" {
                NSNotificationCenter.defaultCenter().postNotificationName("roomCreated", object: nil);
            }
            else if notification == "Your room is bolted. 🔑" {
                NSNotificationCenter.defaultCenter().postNotificationName("state", object: 1);
            }
            else if notification == "Your room is free! 🎉" {
                NSNotificationCenter.defaultCenter().postNotificationName("state", object: 0);
            }
            else if notification == "Could you free the room? 🙏" {
                NSNotificationCenter.defaultCenter().postNotificationName("request", object: nil);
            }
            else if notification == "Your roommate left you. 💔 We're sorry!" {
                NSNotificationCenter.defaultCenter().postNotificationName("alone", object: nil);
            }
        }
    }

}

extension String {
    func insert(string:String,ind:Int) -> String {
        return  String(self.characters.prefix(ind)) + string + String(self.characters.suffix(self.characters.count-ind))
    }
    var length: Int {
        return characters.count
    }
}

func formatNumber(input: String) -> String {
    if input.length != 10 { return input }
    return ((input.insert("(", ind: 0)).insert(") ", ind: 4)).insert("-", ind: 9)
}

func makeNumeric(input: String) -> String {
    let components = input.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet().invertedSet)
    return components.joinWithSeparator("")
}

func removeLeadingOne(input: String) -> String {
    if input.characters.first == "1" { return String(input.characters.dropFirst()) }
    return input
}

func clearDefaults() {
    let dict = defaults.dictionaryRepresentation()
    for (key, _) in dict {
        if key != "viewedIntro" && key != "my_endpoint" && key != "my_phone" {
            defaults.removeObjectForKey(key)
        }
    }
}



