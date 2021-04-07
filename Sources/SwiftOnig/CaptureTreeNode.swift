//
//  CaptureTreeNode.swift
//  
//
//  Created by Gavin Mao on 3/29/21.
//

import COnig

public struct CaptureTreeNode {
    let rawValue: OnigCaptureTreeNode
    
    /**
     The capture group number for this capture.
     */
    public var group: Int {
        get {
            return Int(self.rawValue.group)
        }
    }
    
    /**
     The extent of this capture.
     */
    public var utf8BytesRange: Range<Int> {
        get {
            return Int(self.rawValue.beg) ..< Int(self.rawValue.end)
        }
    }
    
    /**
     The number of child captures this group contains.
     */
    public var count: Int {
        get {
            return Int(self.rawValue.num_childs)
        }
    }
    
    /**
     Does the node have any child captures?
     */
    public var isEmpty: Bool {
        get {
            return self.count == 0
        }
    }
    
    subscript(index: Int) -> CaptureTreeNode {
        if index >= self.count {
            fatalError("Capture tree node index overflow")
        }
        
        if let child = self.rawValue.childs.advanced(by: index).pointee?.pointee {
            return CaptureTreeNode(rawValue: child)
        }
        
        fatalError("Null capture tree node child")
    }
}

extension CaptureTreeNode {
    public struct ChildrenSequence: Sequence {
        private let node: CaptureTreeNode
        
        public init(node: CaptureTreeNode) {
            self.node = node
        }
        
        public func makeIterator() -> CaptureTreeNode.Iterator {
            return CaptureTreeNode.Iterator(node: self.node)
        }
    }
    
    public struct Iterator: IteratorProtocol {
        private let node: CaptureTreeNode
        private var index: Int = 0
        
        public init(node: CaptureTreeNode) {
            self.node = node
        }
        
        public mutating func next() -> CaptureTreeNode? {
            if self.index < self.node.count {
                self.index = self.index + 1
                return self.node[self.index - 1]
            } else {
                return nil
            }
        }
    }

    /**
     An iterator over thie children of this capture group.
     */
    public var children: ChildrenSequence {
        return ChildrenSequence(node: self)
    }
}

extension Region {
    /**
     Get Capture Tree
     - Returns: the capture tree for this region, if there is one, otherwise `nil`.
     */
    public var tree: CaptureTreeNode? {
        if let tree = onig_get_capture_tree(&self.rawValue) {
            return CaptureTreeNode(rawValue: tree.pointee)
        }
        
        return nil
    }

    /**
     Traverse and call callbacks in capture history data tree.
     - Parameters:
        - beforeTraversingChildren: the callback will be called before traversing children tree nodes.
        - afterTraversingChildren: the callback will be called after traversing children tree nodes.
        - group: The group number of of the capture.
        - utf8BytesRange: The range of this capture.
        - level: The level of the capture tree node.
     */
    public func forEachCaptureTreeNode(beforeTraversingChildren: @escaping (_ group: Int, _ utf8BytesRange: Range<Int>, _ level: Int) -> Bool = { _,_,_ in true },
                                       afterTraversingChildren: @escaping (_ group: Int, _ utf8BytesRange: Range<Int>, _ level: Int) -> Bool = { _,_,_ in true }) {
        typealias CallbackType = (Int, Range<Int>, Int) -> Bool
        var callbackRef = (beforeTraversingChildren, afterTraversingChildren)
        
        var onigRegion = self.rawValue
        onig_capture_tree_traverse(&onigRegion, ONIG_TRAVERSE_CALLBACK_AT_BOTH, { (group, start, end, level, at, refPtr) -> Int32 in
            guard let (beforeChildren, afterChildren) = refPtr?.assumingMemoryBound(to: (CallbackType, CallbackType).self).pointee else {
                fatalError("Failed to get callbacks")
            }

            var shouldContinue = false
            switch at {
            case ONIG_TRAVERSE_CALLBACK_AT_FIRST:
                shouldContinue = beforeChildren(Int(group), Int(start) ..< Int(end), Int(level))
            case ONIG_TRAVERSE_CALLBACK_AT_LAST:
                shouldContinue = afterChildren(Int(group), Int(start) ..< Int(end), Int(level))
            default:
                // Unexpected position, just go on
                shouldContinue = true
            }
            
            return shouldContinue ? ONIG_NORMAL : ONIG_ABORT
        }, &callbackRef)
    }
}
