//
//  Main.swift
//  Bolt
//
//  Created by Elliott Bolzan on 2/27/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import UIKit
import GoogleMobileAds
import NetReachability
import AudioToolbox

class Main: UITableViewController, GADInterstitialDelegate {

    // MARK: Setup and Initialization

    var interstitial: GADInterstitial!
    var adTimer = NSTimer()
    var recent: NSMutableArray = []

    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Main.interacted), name: "interacted", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Main.check), name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Main.stateChanged(_:)), name: "state", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Main.showRequest), name: "request", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Main.disband), name: "alone", object: nil)

        if defaults.objectForKey("recent") == nil { defaults.setObject(NSMutableArray(), forKey: "recent") }
        recent = defaults.objectForKey("recent")!.mutableCopy() as! NSMutableArray

        createAndLoadInterstitial()
    }
    
    override func viewDidAppear(animated: Bool) {
        check()
    }

    override func viewWillDisappear(animated: Bool) {
        UIApplication.sharedApplication().statusBarStyle = .Default
    }

    // MARK: Status Bar

    func setStatusBar() {
        if let state = defaults.objectForKey("state") as? Int {
            if state == 0 { UIApplication.sharedApplication().statusBarStyle = .Default }
            else { UIApplication.sharedApplication().statusBarStyle = .LightContent }
        }
        else {
            startOver()
        }
    }

    // MARK: Checks

    func check() {
        if reachability.currentReachabilityStatus.description == "No Connection" { showInternetAlert() }
        else {
            networkActive(true)
            if defaults.objectForKey("room_id") == nil {
                if defaults.objectForKey("my_phone") != nil {
                    Backend.listRooms() { result in
                        if result == "room" { self.getState() }
                        else {
                            self.networkActive(false)
                            self.disband()
                        }
                    }
                }
                else {
                    self.networkActive(false)
                    self.startOver()
                }
            }
            else { getState() }
        }
    }

    func getState() {
        if defaults.objectForKey("roommate_endpoint") != nil {
            Backend.getState() { result in
                dispatch_async(dispatch_get_main_queue()) {
                    self.networkActive(false)
                    if result == "state" { self.scrollTable() }
                    else if result == "empty" { self.disband() }
                    else { self.showErrorAlert() }
                }
            }
        }
        else {
            Backend.getEndpoint() { success in
                if success { self.getState() }
                else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.networkActive(false)
                        self.showErrorAlert()
                    }
                }
            }
        }
    }

    // MARK: Notifications

    func disband() {
        let alert = UIAlertController(title: "Oops!", message: "You don't have a room anymore. We're sorry!", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: { action in
            self.startOver()
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    func showRequest() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        let alert = UIAlertController(title: "Room Requested", message: "Your roommate wants the room. Consider freeing it!", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    func stateChanged(notification: NSNotification) {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        let state = notification.object as! Bool
        defaults.setObject(state, forKey: "state")
        defaults.setObject(defaults.objectForKey("roommate_id"), forKey: "by")
        scrollTable()
    }

    // MARK: Navigation

    func scrollTable() {
        if let row = defaults.objectForKey("state") as? Int {
            if row == 0 { defaults.setBool(false, forKey: "requestedRoom") }
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: row, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
            setStatusBar()
        }
        else {
            startOver()
        }
    }

    func interacted(notification: NSNotification) {
        let state = notification.object as! Int
        if recent.count == 0 { recent.addObject(NSDate()) }
        let minutesElapsed = minutesSince(recent.objectAtIndex(0) as! NSDate)
        if recent.count > 5 && minutesElapsed < 5 {
            let minutesRemaining = 5 - minutesElapsed
            var dynamicString = ""
            if minutesRemaining == 1 { dynamicString = " minute" }
            else { dynamicString = " minutes" }
            let alert = UIAlertController(title: "Easy There", message: "There's a cap on how much you can Bolt. Try again in " + String(minutesRemaining) + dynamicString + "!", preferredStyle: UIAlertControllerStyle.ActionSheet)
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            dispatch_async(dispatch_get_main_queue()) {
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }
        else {
            if recent.count <= 5 { recent.addObject(NSDate()) }
            if minutesElapsed > 5 { recent = [] }
            adTimer.invalidate()
            if state == 0 { requestChange(1) }
            else { requestChange(0) }
        }
        defaults.setObject(recent, forKey: "recent")
        /*if state == 0 { UIApplication.sharedApplication().statusBarStyle = .LightContent }
        else { UIApplication.sharedApplication().statusBarStyle = .Default }
        if state == 0 {
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 1, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
        }
        else {
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
        }*/
    }

    func requestChange(nextRow: Int) {
        if reachability.currentReachabilityStatus.description == "No Connection" { showInternetAlert() }
        else {
            if nextRow == 1 || (defaults.objectForKey("id") as? Int == defaults.objectForKey("by") as? Int) {
                networkActive(true)
                Backend.changeState(nextRow) { success in
                    dispatch_async(dispatch_get_main_queue()) {
                        self.networkActive(false)
                        if success {
                            if nextRow == 1 {
                                self.startAdTimer()
                                let scheduled = defaults.objectForKey("scheduled")
                                if scheduled != nil {
                                    let notification = UILocalNotification()
                                    notification.fireDate = NSDate(timeIntervalSinceNow: scheduled as! NSTimeInterval)
                                    notification.alertBody = "Time to free the room."
                                    notification.category = "REMINDER"
                                    notification.soundName = "free.caf"
                                    UIApplication.sharedApplication().scheduleLocalNotification(notification)
                                }
                            }
                            else { UIApplication.sharedApplication().cancelAllLocalNotifications() }
                            self.scrollTable()
                        }
                        else { self.showErrorAlert() }
                    }
                }
            }
            else {
                if defaults.objectForKey("requestedRoom") == nil || defaults.boolForKey("requestedRoom") == false {
                    networkActive(true)
                    Backend.requestRoom() { success in
                        dispatch_async(dispatch_get_main_queue()) {
                            self.networkActive(false)
                            if success {
                                defaults.setBool(true, forKey: "requestedRoom")
                                let alert = UIAlertController(title: "Good job!", message: "You requested the room.", preferredStyle: UIAlertControllerStyle.ActionSheet)
                                alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                                self.presentViewController(alert, animated: true, completion: nil)
                            }
                            else { self.showErrorAlert() }
                        }
                    }
                }
                else {
                    let alert = UIAlertController(title: "Sorry!", message: "You've already requested the room.", preferredStyle: UIAlertControllerStyle.ActionSheet)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            }
        }
    }

    func presentSettings(sender: UIButton!) {
        let navigationVC = self.storyboard?.instantiateViewControllerWithIdentifier("Navigation") as! UINavigationController
        navigationVC.viewControllers = [(self.storyboard?.instantiateViewControllerWithIdentifier("Settings"))!]
        self.presentViewController(navigationVC, animated: true, completion: nil)
    }

    func startOver() {
        clearDefaults()
        let navigationVC = self.storyboard!.instantiateViewControllerWithIdentifier("Navigation") as! UINavigationController
        navigationVC.viewControllers = [self.storyboard!.instantiateViewControllerWithIdentifier("Setup")]
        self.presentViewController(navigationVC, animated: true, completion: nil)
    }

    // MARK: UI Helpers

    func networkActive(active: Bool) {
        if active {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            self.view.userInteractionEnabled = false
        }
        else {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            self.view.userInteractionEnabled = true
        }
    }

    // MARK: AdMob

    func createAndLoadInterstitial() -> GADInterstitial {
        self.interstitial = GADInterstitial(adUnitID: "ca-app-pub-3663279632633044/5520661217")
        interstitial.delegate = self
        interstitial.loadRequest(GADRequest())
        return interstitial
    }

    func startAdTimer() {
        if self.interstitial.isReady {
            adTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(Main.requestAd), userInfo: nil, repeats: false)
            defaults.setObject(0, forKey: "taps")
        }
    }

    func requestAd() {
        self.interstitial.presentFromRootViewController(self)
    }

    func interstitialDidDismissScreen(ad: GADInterstitial!) {
        self.interstitial = createAndLoadInterstitial()
    }

    // MARK: Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UIScreen.mainScreen().bounds.size.height
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let stateCellIdentifier = "State"
        let cell = tableView.dequeueReusableCellWithIdentifier(stateCellIdentifier, forIndexPath: indexPath) as! State
        if indexPath.row == 0 {
            cell.backgroundColor = UIColor.whiteColor()
            cell.stateImageView.image = UIImage(named: "free")
            cell.settingsButton.layer.borderColor = matteBlack.CGColor
            cell.settingsButton.setTitleColor(matteBlack, forState: .Normal)
        }
        else if indexPath.row == 1 {
            cell.backgroundColor = matteBlack
            cell.stateImageView.image = UIImage(named: "bolt")
            cell.settingsButton.layer.borderColor = UIColor.whiteColor().CGColor
            cell.settingsButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        }
        cell.setType(indexPath.row)
        cell.settingsButton.layer.borderWidth = 1;
        cell.settingsButton.addTarget(self, action: #selector(Main.presentSettings(_:)), forControlEvents: .TouchUpInside)
        return cell
    }

    // MARK: Date Helpers

    func minutesSince(startDate: NSDate) -> Int {
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Minute], fromDate: startDate, toDate: NSDate(), options: [])
        return components.minute
    }

    // MARK: Alerts

    func showErrorAlert() {
        let errorAlert = UIAlertController(title: "There was an error.", message: "We apologize and recommend you try again later.", preferredStyle: .ActionSheet)
        errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
        self.presentViewController(errorAlert, animated: true, completion: nil)
    }

    func showInternetAlert() {
        let internetAlert = UIAlertController(title: "No Connection!", message: "Try again when you have access to the Internet.", preferredStyle: .ActionSheet)
        internetAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
        self.presentViewController(internetAlert, animated: true, completion: nil)
    }

}
