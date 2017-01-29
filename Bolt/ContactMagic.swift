//
//  ContactMagic.swift
//  Bolt
//
//  Created by Elliott Bolzan on 3/16/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import Foundation
import Contacts

extension String {
    var trimmedString: String {
        return stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
}

class ContactMagic {

    // Get Me

    class func getMe() -> String {
        let ownerName = getOwnerName()
        let store = CNContactStore()
        do {
            let contacts = try store.unifiedContactsMatchingPredicate(CNContact.predicateForContactsMatchingName(ownerName), keysToFetch:[CNContactPhoneNumbersKey])
            if contacts.count <= 1 {
                if let contact = contacts.first {
                    if (contact.isKeyAvailable(CNContactPhoneNumbersKey)) {
                        for number in contact.phoneNumbers {
                            if number.label == CNLabelPhoneNumberiPhone || number.label == CNLabelPhoneNumberMobile {
                                let property = number.value as! CNPhoneNumber
                                return formatNumber(makeNumeric(property.stringValue))
                            }
                        }
                    }
                }
            }
        }
        catch let e as NSError {
            print(e.localizedDescription)
        }
        return ""
    }

    class func getOwnerName() -> String {
        var ownerName = UIDevice.currentDevice().name.trimmedString.stringByReplacingOccurrencesOfString("'", withString: "")
        ownerName = ownerName.stringByReplacingOccurrencesOfString("’", withString: "")
        let model = UIDevice.currentDevice().model
        if let t = ownerName.rangeOfString("s \(model)") {
            ownerName = ownerName.substringToIndex(t.startIndex)
        }
        return ownerName.trimmedString
    }

    // Get Owner of Number

    class func getOwnerOfNumber(number: String) -> CNContact? {
        let store = CNContactStore()
        let request = CNContactFetchRequest(keysToFetch: [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactImageDataAvailableKey, CNContactImageDataKey, CNContactPhoneNumbersKey])
        var output: CNContact?
        do {
            try store.enumerateContactsWithFetchRequest(request) { contact, stop in
                for result in contact.phoneNumbers {
                    let property = result.value as! CNPhoneNumber
                    let set = NSCharacterSet.decimalDigitCharacterSet().invertedSet
                    let decimal = removeLeadingOne(property.stringValue.componentsSeparatedByCharactersInSet(set).joinWithSeparator(""))
                    if decimal == number { output = contact }
                }
            }
        }
        catch {
            print(error)
        }
        return output
    }

}
