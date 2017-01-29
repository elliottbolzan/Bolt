//
//  Settings.swift
//  Bolt
//
//  Created by Elliott Bolzan on 2/27/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import UIKit
import Contacts

class Settings: UITableViewController {

    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var detail: UILabel?

    @IBOutlet weak var remindLabel: UILabel?
    @IBOutlet weak var toggle: UISwitch?
    @IBOutlet weak var picker: UIDatePicker?

    var showingPicker = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let doneButton = UIBarButtonItem(title: "Done", style: .Plain, target: self, action: #selector(Settings.done))
        self.navigationItem.rightBarButtonItem = doneButton

        toggle!.addTarget(self, action: #selector(Settings.toggled(_:)), forControlEvents: UIControlEvents.ValueChanged)

        checkScheduled()

        /*if let data = defaults.objectForKey("contact") as? NSData {
            if let contact = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? CNContact {
                label!.text = contact.givenName + " " + contact.familyName
                detail!.text = formatNumber(String(defaults.objectForKey("roommate_phone")!))
            }
        }
        else {
            label!.text = formatNumber(String(defaults.objectForKey("roommate_phone")!))
            detail!.text = ""
        }*/
    }

    // MARK: Navigation

    func done() {
        defaults.setObject(picker?.countDownDuration, forKey: "scheduled")
        self.dismissViewControllerAnimated(true, completion: {})
    }

    // MARK: Switching

    func toggled(mySwitch: UISwitch) {
        if mySwitch.on { on() }
        else { off() }
    }

    func checkScheduled() {
        let scheduled = defaults.objectForKey("scheduled")
        if scheduled == nil {
            toggle!.on = false
            off()
        }
        else {
            toggle!.on = true
            on()
            picker?.countDownDuration = scheduled as! NSTimeInterval
        }

    }

    func on() {
        let scheduled = defaults.objectForKey("scheduled")
        showingPicker = true
        remindLabel?.text = "Remind Me After"
        if scheduled != nil { picker?.countDownDuration = scheduled as! NSTimeInterval }
        else { picker?.countDownDuration = 1800 }
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    func off() {
        showingPicker = false
        remindLabel?.text = "Remind Me"
        defaults.setObject(nil, forKey: "scheduled")
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    // MARK: Table View

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 && indexPath.row == 1 {
            print(defaults.objectForKey("scheduled"))
            if reachability.currentReachabilityStatus.description == "No Connection" {
                let internetAlert = UIAlertController(title: "No Connection!", message: "Try again when you have access to the Internet.", preferredStyle: .ActionSheet)
                internetAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
                self.presentViewController(internetAlert, animated: true, completion: nil)
                return
            }
            networkActive(true)
            Backend.disbandRoom() { success in
                dispatch_async(dispatch_get_main_queue()) {
                    self.networkActive(false)
                    if success {
                        clearDefaults()
                        let navigationVC = self.storyboard!.instantiateViewControllerWithIdentifier("Navigation") as! UINavigationController
                        navigationVC.viewControllers = [self.storyboard!.instantiateViewControllerWithIdentifier("Setup")]
                        self.presentViewController(navigationVC, animated: true, completion: nil)
                    }
                    else {
                        let errorAlert = UIAlertController(title: "There was an error.", message: "We apologize and recommend you try again later.", preferredStyle: .ActionSheet)
                        errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
                        self.presentViewController(errorAlert, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 1 && indexPath.row == 1 {
            if showingPicker { return 180 }
            else { return 0 }
        }
        else { return 44 }
    }

    // MARK: Helper

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

}

