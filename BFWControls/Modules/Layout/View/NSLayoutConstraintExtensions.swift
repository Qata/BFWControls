//
//  NSLayoutConstraintExtensions.swift
//  BFWControls
//
//  Created by Tom Brodhurst-Hill on 11/02/2016.
//  Copyright © 2016 BareFeetWare.
//  Free to use at your own risk, with acknowledgement to BareFeetWare.
//

import UIKit

extension UIView {
    
    func copyDescendantConstraints(from fromView: UIView) {
        var fromItems: [NSObject] = [fromView]
        var toItems: [NSObject] = [self]
        var toSubviewConstraints = [NSLayoutConstraint]()
        for fromSubview in fromView.subviews {
            if let toSubview = subview(matching: fromSubview) {
                fromItems.append(fromSubview)
                toItems.append(toSubview)
                toSubviewConstraints += toSubview.constraints
            }
        }
        let oldConstraints = (constraints + toSubviewConstraints).filter { constraint in
            constraint.onlyIncludes(items: toItems)
        }
        let copiedConstraints = oldConstraints.map { oldConstraint in
            oldConstraint.constraint(byReplacing: toItems, with: fromItems)
        }
        NSLayoutConstraint.deactivate(oldConstraints)
        NSLayoutConstraint.activate(copiedConstraints)
    }

    func pinToSuperviewEdges() {
        pin(to: superview!,
            attributes: [.left, .right, .top, .bottom],
            secondAttributes: [.left, .right, .top, .bottom]
        )
    }

    func pinToSuperviewMargins() {
        pin(to: superview!,
            attributes: [.left, .right, .top, .bottom],
            secondAttributes: [.leftMargin, .rightMargin, .topMargin, .bottomMargin]
        )
    }
    
    func pinToSuperview(with inset: CGFloat) {
        pin(to: superview!,
            attributes: [.left, .right, .top, .bottom],
            secondAttributes: [.left, .right, .top, .bottom],
            constants: [inset, -inset, inset, -inset])
    }
    
    func pin(to view: UIView,
             attributes: [NSLayoutAttribute],
             secondAttributes: [NSLayoutAttribute],
             constants: [CGFloat] = [0, 0, 0, 0])
    {
        var constraints = [NSLayoutConstraint]()
        for attributeN in 0 ..< attributes.count {
            let constraint = NSLayoutConstraint(
                item: self,
                attribute: attributes[attributeN],
                relatedBy: .equal,
                toItem: view,
                attribute: secondAttributes[attributeN],
                multiplier: 1.0,
                constant: constants[attributeN]
            )
            constraints.append(constraint)
        }
        NSLayoutConstraint.activate(constraints)
        translatesAutoresizingMaskIntoConstraints = false
    }

    func activateOnlyConstraintsWithFirstVisible(in views: [UIView]) {
        var firstMatchedView: UIView?
        for view in views {
            let isFirstMatch = firstMatchedView == nil && !(view.isHidden)
            if let constraints = constraints(with: view) {
                if isFirstMatch {
                    firstMatchedView = view
                    NSLayoutConstraint.activate(constraints)
                } else {
                    NSLayoutConstraint.deactivate(constraints)
                }
            }
        }
    }
    
    func commonAncestor(with view: UIView) -> UIView? {
        var ancestor: UIView?
        if isDescendant(of: view) {
            ancestor = view
        } else if view.isDescendant(of: self) {
            ancestor = self
        } else {
            var superview: UIView? = self
            while ancestor == nil && superview != nil {
                superview = superview!.superview
                if view.isDescendant(of: superview!) {
                    ancestor = superview
                }
            }
        }
        return ancestor
    }
    
    func constraints(with view: UIView) -> [NSLayoutConstraint]? {
        return commonAncestor(with: view)?.constraints.filter { constraint in
            constraint.isBetween(item: self, otherItem: view)
        }
    }
    
    var siblingAndSuperviewConstraints: [NSLayoutConstraint]? {
        return superview?.constraints.filter { constraint in
            var include = false
            if let firstItem = constraint.firstItem as? NSObject,
                let secondItem = constraint.secondItem as? NSObject,
                firstItem == self || secondItem == self
            {
                include = true
            }
            return include
        }
    }
    
    func deactivateConstraintsIfHidden() {
        if let siblingAndSuperviewConstraints = siblingAndSuperviewConstraints {
            if isHidden {
                NSLayoutConstraint.deactivate(siblingAndSuperviewConstraints)
            } else {
                NSLayoutConstraint.activate(siblingAndSuperviewConstraints)
            }
        }
    }

    var widthMultiplier: CGFloat? {
        get {
            return widthConstraint?.multiplier
        }
        set {
            if let widthConstraint = widthConstraint {
                if let width = newValue {
                    let newConstraint = widthConstraint.constraint(with: width)
                    superview!.removeConstraint(widthConstraint)
                    superview!.addConstraint(newConstraint)
                }
            }
        }
    }
    
    var widthConstraint: NSLayoutConstraint? {
        get {
            var widthConstraint: NSLayoutConstraint?
            if let superview = superview {
                for constraint in superview.constraints {
                    if let firstItem = constraint.firstItem as? UIView,
                        let secondItem = constraint.secondItem as? UIView
                    {
                        if [firstItem, secondItem].contains(self)
                            && [firstItem, secondItem].contains(superview)
                            && constraint.firstAttribute == .width
                            && constraint.secondAttribute == .width
                        {
                            widthConstraint = constraint
                            break
                        }
                    }
                }
            }
            return widthConstraint
        }
    }

}

extension NSLayoutConstraint {
    
    func constraint(with multiplier: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant
        )
        return constraint
    }
    
    func constraint(byReplacing oldItems: [NSObject], with newItems: [NSObject]) -> NSLayoutConstraint {
        let firstIndex = oldItems.index(of: self.firstItem as! NSObject)!
        let firstItem = newItems[firstIndex]
        var newSecondItem: NSObject?
        if let secondItem = secondItem {
            if let secondIndex = oldItems.index(of: secondItem as! NSObject) {
                newSecondItem = newItems[secondIndex]
            }
        }
        let constraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: newSecondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant
        )
        return constraint
    }
    
    func isBetween(item: NSObject, otherItem: NSObject) -> Bool {
        var isBetween = false
        if let firstItem = firstItem as? NSObject,
            let secondItem = secondItem as? NSObject
        {
            isBetween = (firstItem == item && secondItem == otherItem)
                || (firstItem == otherItem && secondItem == item)
        }
        return isBetween
    }

    func otherItem(if view: UIView) -> AnyObject? {
        var otherItem: AnyObject?
        if firstItem as? UIView == view {
            otherItem = secondItem
        } else if secondItem as? UIView == view {
            otherItem = firstItem
        }
        return otherItem
    }
    
    func onlyIncludes(items: [NSObject]) -> Bool {
        var include = false
        if let firstItem = firstItem as? NSObject,
            items.contains(firstItem)
        {
            if secondItem == nil {
                include = true
            } else if let secondItem = secondItem as? NSObject,
                items.contains(secondItem)
            {
                include = true
            }
        }
        return include
    }
    
}
