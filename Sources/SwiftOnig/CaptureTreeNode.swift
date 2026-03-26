//
//  CaptureTreeNode.swift
//  
//
//  Created by Guangming Mao on 3/29/21.
//

import COnig

public struct CaptureTreeNode: Sendable {
    nonisolated(unsafe) let rawValue: OnigCaptureTreeNode
    
    /**
     The capture group number for this capture group.
     */
    public var groupNumber: Int {
        Int(self.rawValue.group)
    }

    /**
     The extent of this capture group.
     */
    public var range: Range<Int> {
        Int(self.rawValue.beg) ..< Int(self.rawValue.end)
    }
}

// Children
extension CaptureTreeNode {
    /**
     A collection of children `CaptureTreeNode`.
     */
    public struct ChildrenCollection: RandomAccessCollection, Sendable {
        public let parent: CaptureTreeNode

        public typealias Index = Int
        public typealias Element = CaptureTreeNode
        
        public var startIndex: Int {
            0
        }
        
        public var endIndex: Int {
            self.parent.childrenCount
        }
        
        public subscript(position: Int) -> CaptureTreeNode {
            guard let child = self.parent.rawValue.childs.advanced(by: position).pointee?.pointee else {
                fatalError("Nil capture tree node child")
            }

            return CaptureTreeNode(rawValue: child)
        }
    }

    /**
     The number of child capture groups this capture group contains.
     */
    public var childrenCount: Int {
        Int(self.rawValue.num_childs)
    }

    /**
     Does the node have any child capture groups?
     */
    public var hasChildren: Bool {
        return self.childrenCount == 0
    }

    /**
     Get the collection of children nodes of this capture group.
     */
    public var children: ChildrenCollection {
        ChildrenCollection(parent: self)
    }
}

extension Region {
    /**
     Get Capture Tree
     - Returns: the capture tree for this region, if there is one, otherwise `nil`.
     */
    public var captureTree: CaptureTreeNode? {
        if let tree = onig_get_capture_tree(self.rawValue) {
            return CaptureTreeNode(rawValue: tree.pointee)
        }
        
        return nil
    }

    /**
     Traverse and call callbacks in capture history data tree.
     - Parameters:
        - beforeTraversingChildren: the callback will be called before traversing children tree nodes.
        - afterTraversingChildren: the callback will be called after traversing children tree nodes.
     */
    public func enumerateCaptureTreeNodes(beforeTraversingChildren: @escaping (_ groupNumber: Int, _ bytesRange: Range<Int>, _ level: Int) -> Bool = { _,_,_ in true },
                                          afterTraversingChildren: @escaping (_ groupNumber: Int, _ bytesRange: Range<Int>, _ level: Int) -> Bool = { _,_,_ in true }) {
        typealias CallbackType = (Int, Range<Int>, Int) -> Bool
        
        class Context {
            let before: CallbackType
            let after: CallbackType
            init(before: @escaping CallbackType, after: @escaping CallbackType) {
                self.before = before
                self.after = after
            }
        }
        
        let context = Context(before: beforeTraversingChildren, after: afterTraversingChildren)
        let contextPtr = Unmanaged.passUnretained(context).toOpaque()

        onig_capture_tree_traverse(self.rawValue, ONIG_TRAVERSE_CALLBACK_AT_BOTH, { (groupNumber, start, end, level, at, refPtr) -> Int32 in
            guard let refPtr = refPtr else { return ONIG_NORMAL }
            let context = Unmanaged<Context>.fromOpaque(refPtr).takeUnretainedValue()

            var shouldContinue = false
            switch at {
            case ONIG_TRAVERSE_CALLBACK_AT_FIRST:
                shouldContinue = context.before(Int(groupNumber), Int(start) ..< Int(end), Int(level))
            case ONIG_TRAVERSE_CALLBACK_AT_LAST:
                shouldContinue = context.after(Int(groupNumber), Int(start) ..< Int(end), Int(level))
            default:
                // Unexpected position, just go on
                shouldContinue = true
            }
            
            return shouldContinue ? ONIG_NORMAL : ONIG_ABORT
        }, contextPtr)
    }
}
