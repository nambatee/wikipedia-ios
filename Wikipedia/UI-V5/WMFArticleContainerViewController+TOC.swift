//
//  WMFArticleContainerViewController+TOC.swift
//  Wikipedia
//
//  Created by Brian Gerstle on 10/23/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

import Foundation
import BlocksKit

extension WMFArticleContainerViewController : WMFTableOfContentsViewControllerDelegate {
    public func tableOfContentsController(controller: WMFTableOfContentsViewController,
                                          didSelectItem item: TableOfContentsItem) {
        // Don't dismiss immediately - it looks jarring - let the user see the ToC selection before dismissing
        dispatchOnMainQueueAfterDelayInSeconds(0.25) {
            self.dismissViewControllerAnimated(true, completion: nil)
            if let section = item as? MWKSection {
                self.webViewController.scrollToSection(section)
            } else if let _ = item as? TableOfContentsReadMoreItem {
                self.webViewController.scrollToFooterAtIndex(0)
            }
        }
    }

    public func tableOfContentsControllerDidCancel(controller: WMFTableOfContentsViewController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}

extension WMFArticleContainerViewController {
    /**
    Create a new instance of `WMFTableOfContentsViewController` which is configured to be used with the receiver.
    
    - note: This must be done in Swift because `WMFTableOfContentsViewControllerDelegate` is not an ObjC protocol, 
            and therefore cannot be referenced in Objective-C.

    - returns: A new view controller or `nil` if the receiver's `article.sections` is `nil`.
    */
    public func createTableOfContentsViewController() -> WMFTableOfContentsViewController? {
        if let sections = self.article?.sections {
           return WMFTableOfContentsViewController(sectionList: sections, delegate: self)
        } else {
            return nil
        }
    }

    public var tableOfContentsToolbarItem: UIBarButtonItem  {
        get {
            // unfortunately BlocksKit "handler" API doesn't port to Swift well due to "bk_" prefix
            let tocToolbarItem = UIBarButtonItem(image: UIImage(named:"toc"),
                                                 style: UIBarButtonItemStyle.Plain,
                                                 target: self,
                                                 action: Selector("didTapTableOfContentsButton:"))
            tocToolbarItem.tintColor = UIColor.blackColor()
            return tocToolbarItem
        }
    }

    public func didTapTableOfContentsButton(sender: AnyObject?) {
        if let item: TableOfContentsItem = webViewController.currentVisibleSection() {
            self.tableOfContentsViewController!.selectAndScrollToItem(item, animated: true)
            presentViewController(self.tableOfContentsViewController!, animated: true, completion: nil)
        }
    }
}
