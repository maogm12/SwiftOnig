//
//  Tree.swift
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
        get {
            return ChildrenSequence(node: self)
        }
    }
}
