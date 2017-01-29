//
//  Setup.swift
//  Bolt
//
//  Created by Elliott Bolzan on 3/15/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import UIKit
import ContactsUI
import MessageUI
import NetReachability

class Setup: UITableViewController, UITextFieldDelegate, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate {

    var artificialMe = false
    var artificialRoommate = false

    var showContacts = false
    var showPickDifferent = false

    var shownTip = false

    var myLength = false
    var roommateLength = false

    var blurEffectView = UIVisualEffectView()

    @IBOutlet weak var myLabel: UILabel?
    @IBOutlet weak var roommateLabel: UILabel?

    @IBOutlet weak var myPhoneField: UITextField?
    @IBOutlet weak var roommatePhoneField: UITextField?

    @IBOutlet weak var myCell: UITableViewCell?
    @IBOutlet weak var roommateCell: UITableViewCell?
    @IBOutlet weak var accountCell: UITableViewCell?
    @IBOutlet weak var differentCell: UITableViewCell?

    var pairButton = UIBarButtonItem()

    override func viewDidLoad() {
        super.viewDidLoad()

        check()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Setup.check), name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Setup.check), name: "roomCreated", object: nil)

        self.title = "Getting Started"

        myPhoneField!.keyboardType = .PhonePad
        myPhoneField!.delegate = self
        myPhoneField!.addObserver(self, forKeyPath: "text", options: .New, context: nil)

        roommatePhoneField!.keyboardType = .PhonePad
        roommatePhoneField!.delegate = self
        roommatePhoneField!.addObserver(self, forKeyPath: "text", options: .New, context: nil)

        pairButton = UIBarButtonItem(title: "Pair", style: .Plain, target: self, action: #selector(Setup.pair))
        pairButton.enabled = false
        self.navigationItem.rightBarButtonItem = pairButton

        configure()
    }

    override func viewWillAppear(animated: Bool) {
        if myLength { roommatePhoneField!.becomeFirstResponder() }
        else { myPhoneField!.becomeFirstResponder() }
        super.viewWillAppear(animated)
    }

    func configure() {
        if defaults.objectForKey("my_phone") != nil && defaults.objectForKey("roommate_phone") != nil {
            pairButton.enabled = false
            showPickDifferent = true
            myPhoneField!.text = formatNumber(defaults.objectForKey("my_phone") as! String)
            roommatePhoneField!.text = formatNumber(defaults.objectForKey("roommate_phone") as! String)
            myPhoneField!.textColor = UIColor.grayColor()
            roommatePhoneField!.textColor = UIColor.grayColor()
            roommateCell!.tintColor = UIColor.grayColor()
            myCell!.tintColor = UIColor.grayColor()
            myPhoneField!.enabled = false
            roommatePhoneField!.enabled = false
            updateFooter("Now, your roommate must add you back.")
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        else {
            myCell!.accessoryType = .None
            roommateCell!.accessoryType = .None
            var myNumber = ""
            if defaults.objectForKey("my_phone") == nil { myNumber = ContactMagic.getMe() }
            else { myNumber = defaults.objectForKey("my_phone") as! String }
            myPhoneField!.text = ""
            roommatePhoneField?.text = ""
            myPhoneField!.enabled = true
            roommatePhoneField!.enabled = true
            myPhoneField!.textColor = UIColor.blackColor()
            roommatePhoneField!.textColor = UIColor.blackColor()
            roommateCell!.tintColor = UIColor.blackColor()
            myCell!.tintColor = UIColor.blackColor()
            if myNumber != "" {
                myCell!.accessoryType = .Checkmark
                myPhoneField!.text = formatNumber(myNumber)
                artificialMe = true
                updateFooter("Bolt got this info from your contacts.")
                roommatePhoneField!.becomeFirstResponder()
            }
            else {
                updateFooter("Bolt needs these to pair you.")
                myPhoneField!.becomeFirstResponder()
            }
            showPickDifferent = false
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }

    // MARK: Check and Notifications

    func check() {
        if reachability.currentReachabilityStatus.description == "No Connection" { showInternetAlert() }
        else {
            if defaults.objectForKey("id") != nil && defaults.objectForKey("my_phone") != nil {
                networkActive(true)
                Backend.listRooms() { result in
                    dispatch_async(dispatch_get_main_queue()) {
                        self.networkActive(false)
                        if result == "room" {
                                let mainVC = self.storyboard!.instantiateViewControllerWithIdentifier("Main")
                                self.presentViewController(mainVC, animated: true, completion: nil)
                            }
                        else if result == "error" { self.showErrorAlert() }
                    }
                }
            }
        }
    }

    // MARK: Backend

    func pair() {
        view.endEditing(true)
        let first_phone = makeNumeric(myPhoneField!.text!)
        let second_phone = makeNumeric(roommatePhoneField!.text!)
        if first_phone == second_phone {
            let alert = UIAlertController(title: "Hold your horses!", message: "We think adding yourself as your own roommate is a bit narcissistic and boring.", preferredStyle: UIAlertControllerStyle.ActionSheet)
            alert.addAction(UIAlertAction(title: "Nevermind", style: UIAlertActionStyle.Default, handler: {(alert: UIAlertAction!) in self.roommatePhoneField?.becomeFirstResponder()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        if reachability.currentReachabilityStatus.description == "No Connection" { showInternetAlert() }
        else {
            networkActive(true)
            if defaults.objectForKey("my_endpoint") != nil {
                Backend.newUser(first_phone, second_phone: second_phone) { result in
                    dispatch_async(dispatch_get_main_queue()) {
                        self.networkActive(false)
                        if result == "error" { self.showErrorAlert(true) }
                        else if result == "id" { self.sendMessage() }
                        else if result == "room" {
                            let mainVC = self.storyboard?.instantiateViewControllerWithIdentifier("Main")
                            self.presentViewController(mainVC!, animated: true, completion: nil)
                        }
                    }
                }
            }
            else {
                (UIApplication.sharedApplication().delegate as! AppDelegate).register()
                networkActive(false)
                self.showErrorAlert(true)
            }
        }

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

    // Text Message

    func sendMessage() {
        let messageVC = MFMessageComposeViewController()
        messageVC.body = "Hey! I added you as my roommate on Bolt. 👬 Download the app here: http://appstore.com/boltgetaroom."
        messageVC.recipients = [makeNumeric(roommatePhoneField!.text!)]
        messageVC.messageComposeDelegate = self
        self.presentViewController(messageVC, animated: true, completion: nil)
    }

    func messageComposeViewController(controller: MFMessageComposeViewController, didFinishWithResult result: MessageComposeResult) {
        self.configure()
        controller.dismissViewControllerAnimated(true, completion: nil)
    }

    // Table View Delegate

    override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if showPickDifferent { return "Now, your roommate must add you back." }
        return "Bolt needs these to pair you."
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row == 2 && !showContacts { return 0 }
        else if indexPath.row == 3 && !showPickDifferent { return 0 }
        else { return 44 }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == 2 {
            let contactPicker = CNContactPickerViewController()
            contactPicker.delegate = self
            contactPicker.predicateForSelectionOfProperty = NSPredicate(value: true)
            contactPicker.displayedPropertyKeys =
                [CNContactPhoneNumbersKey]
            self.presentViewController(contactPicker, animated: true, completion: nil)
        }
        else if indexPath.row == 3 {
            if reachability.currentReachabilityStatus.description == "No Connection" { showInternetAlert() }
            else {
                networkActive(true)
                Backend.cancelRequest() { success in
                    dispatch_async(dispatch_get_main_queue()) {
                        self.networkActive(false)
                        if success { self.configure() }
                        else { self.showErrorAlert() }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    func setPairButton() {
        if myLength && roommateLength && !showPickDifferent {
            pairButton.enabled = true
        }
        else {
            self.showContacts = false
            pairButton.enabled = false
        }
    }

    func updateFooter(string: String) {
        self.tableView.footerViewForSection(0)?.textLabel?.text = string
        self.tableView.footerViewForSection(0)?.textLabel?.numberOfLines = 1
        self.tableView.footerViewForSection(0)?.textLabel?.sizeToFit()
    }

    // MARK: Contacts Delegate

    func contactPicker(picker: CNContactPickerViewController, didSelectContactProperty contactProperty: CNContactProperty) {
        picker.dismissViewControllerAnimated(true, completion: nil)
        var number = makeNumeric(contactProperty.value!.stringValue)
        if number.characters.count == 11 && number.characters.first == "1" {
            number = String(number.characters.dropFirst())
        }
        if number.characters.count == 10 {
            roommatePhoneField?.text = formatNumber(makeNumeric(number))
        }
    }

    // MARK: Text Field Delegate

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if object as? UITextField == roommatePhoneField && roommatePhoneField?.text!.length >= 14 {
            roommateLength = true
            roommateCell!.accessoryType = .Checkmark
            setPairButton()
        }
        else if object as? UITextField == myPhoneField && myPhoneField?.text!.length >= 14 {
            myLength = true
            myCell!.accessoryType = .Checkmark
            setPairButton()
        }
    }

    func textFieldDidBeginEditing(textField: UITextField) {
        if textField == roommatePhoneField {
            showContacts = true
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            if reachability.currentReachabilityStatus.description != "No Connection" {
                if myLength && !shownTip {
                    let number = makeNumeric(myPhoneField!.text!)
                    Backend.listRooms(number) { result in
                        if result == "requestedMe" {
                            dispatch_async(dispatch_get_main_queue()) {
                                if self.roommatePhoneField!.text == "" {
                                    self.roommatePhoneField!.text = formatNumber(defaults.objectForKey("requestedMe") as! String)
                                    self.updateFooter("This person added you as their roommate.")
                                    let roommate = ContactMagic.getOwnerOfNumber(makeNumeric(self.roommatePhoneField!.text!))
                                    if roommate != nil {
                                        self.updateFooter(roommate!.givenName + " " + roommate!.familyName + " wants to be your roommate.")
                                    }
                                    self.shownTip = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func textFieldDidEndEditing(textField: UITextField) {
        if textField == roommatePhoneField {
            showContacts = false
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {

        let newString = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString: string)
        let components = newString.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet().invertedSet)

        let decimalString = components.joinWithSeparator("") as NSString
        let length = decimalString.length
        let hasLeadingOne = length > 0 && decimalString.characterAtIndex(0) == (1 as unichar)

        if length >= 10 {
            if textField == myPhoneField {
                myLength = true
                myCell!.accessoryType = .Checkmark
            }
            else if textField == roommatePhoneField {
                roommateLength = true
                roommateCell!.accessoryType = .Checkmark
            }
        }
        else {
            if textField == myPhoneField {
                myLength = false
                myCell!.accessoryType = .None
            }
            else if textField == roommatePhoneField {
                roommateLength = false
                roommateCell!.accessoryType = .None
            }
        }

        setPairButton()

        if length == 0 || (length > 10 && !hasLeadingOne) || length > 11 {
            let newLength = (textField.text! as NSString).length + (string as NSString).length - range.length as Int
            return (newLength > 10) ? false : true
        }
        var index = 0 as Int
        let formattedString = NSMutableString()

        if hasLeadingOne {
            formattedString.appendString("1 ")
            index += 1
        }
        if (length - index) > 3 {
            let areaCode = decimalString.substringWithRange(NSMakeRange(index, 3))
            formattedString.appendFormat("(%@) ", areaCode)
            index += 3
        }
        if length - index > 3 {
            let prefix = decimalString.substringWithRange(NSMakeRange(index, 3))
            formattedString.appendFormat("%@-", prefix)
            index += 3
        }

        let remainder = decimalString.substringFromIndex(index)
        formattedString.appendString(remainder)
        textField.text = formattedString as String
        return false
    }

    // MARK: Alerts

    func showErrorAlert(keyboard: Bool = false) {
        let errorAlert = UIAlertController(title: "There was an error.", message: "We apologize and recommend you try again later.", preferredStyle: .ActionSheet)
        if keyboard {
            errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: {(alert: UIAlertAction!) in self.roommatePhoneField?.becomeFirstResponder()
            }))
        }
        else { errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil)) }
        self.presentViewController(errorAlert, animated: true, completion: nil)
    }

    func showInternetAlert() {
        let internetAlert = UIAlertController(title: "No Connection!", message: "Try again when you have access to the Internet.", preferredStyle: .ActionSheet)
        internetAlert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
        self.presentViewController(internetAlert, animated: true, completion: nil)
    }

}
