//
//  Intro.swift
//  
//
//  Created by Elliott Bolzan on 3/23/16.
//
//

import UIKit
import PermissionScope

class Intro: UIViewController {

    @IBOutlet weak var startButton: UIButton?

    let pscope = PermissionScope()

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI

        startButton!.layer.borderColor = matteBlack.CGColor
        startButton!.layer.borderWidth = 1;

        // Permissions

        pscope.addPermission(ContactsPermission(),
                             message: "We use this to pair you with your roommate.")
        pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                             message: "We use to this keep you posted\r\non your room's status.")
        pscope.closeButtonTextColor = matteBlack
        pscope.permissionButtonTextColor = matteBlack
        pscope.permissionButtonBorderColor = matteBlack
        pscope.buttonFont = UIFont(name: "HelveticaNeue", size: 12)!
        pscope.authorizedButtonColor = matteBlack
        pscope.permissionButtonCornerRadius = 0

        // Reset Defaults

        clearDefaults()

    }

    @IBAction func startClicked(sender: UIButton) {
        pscope.show( { finished, results in
            if results[1].status == .Authorized {
                (UIApplication.sharedApplication().delegate as! AppDelegate).register()
            }
            if results[0].status == .Authorized && results[1].status == .Authorized {
                dispatch_async(dispatch_get_main_queue()) {
                    defaults.setObject(true, forKey: "viewedIntro")
                    let next = self.storyboard!.instantiateViewControllerWithIdentifier("Navigation") as! UINavigationController
                    next.viewControllers = [self.storyboard!.instantiateViewControllerWithIdentifier("Setup")]
                    self.presentViewController(next, animated:true, completion:nil)
                }
            }
            }, cancelled: { (results) -> Void in
                // Dismissed the Alert View.
        })

    }

}
