//
//  Node.swift
//  RongEnterpriseApp
//
//  Created by LGQ on 5/21/24.
//  Copyright © 2024 奇富科技. All rights reserved.
//

import Foundation
import DiffMatchPatch

public class DeltaDto: Codable {
    var ops: [OpDto]?

    enum CodingKeys: String, CodingKey {
        case ops = "content"
    }
}

public class DeltaJson {
    
    public static func fromJson(_ text: String?) -> Delta? {
        guard let text = text, let data = text.data(using: .utf8) else {
            return nil
        }
        
        do {
            let deltaDto = try JSONDecoder().decode(DeltaDto.self, from: data)
            return DataMapper.toDelta(deltaDto)
        } catch {
            print("Error decoding JSON: \(error)")
            return nil
        }
    }
    
    public static func opsFromJson(_ text: String?) -> [Op]? {
        guard let text = text, let data = text.data(using: .utf8) else {
            return nil
        }
        do {
            let ops = try JSONDecoder().decode([OpDto].self, from: data)
            return DataMapper.toOps(ops)
        } catch {
            print("Error decoding JSON: \(error)")
            return nil
        }
    }
    
    public static func toJson(_ delta: Delta?) -> String? {
        guard let delta = delta else {
            return nil
        }
        
        do {
            let deltaDto = DataMapper.toDeltaDto(delta)
            let jsonData = try JSONEncoder().encode(deltaDto)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error encoding JSON: \(error)")
            return nil
        }
    }
    
    public static func toJson(_ ops: [Op]?) -> String? {
        guard let ops = ops else {
            return nil
        }
        
        do {
            let opDtos = DataMapper.toOpDtos(ops)
            let jsonData = try JSONEncoder().encode(opDtos)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error encoding JSON: \(error)")
            return nil
        }
    }
}


public class DataMapper {
    
    public static func toDelta(_ deltaDto: DeltaDto?) -> Delta {
        let delta = Delta()
        if let ops = deltaDto?.ops {
            delta.ops = ops.map { toOp($0) }
        }
        return delta
    }
    
    public static func toOpDtos(_ ops: [Op]?) -> [OpDto] {
        var opsDtos:[OpDto] = []
        if let ops = ops {
            opsDtos = ops.map { toOpDto($0) }
        }
        return opsDtos
    }
    
    public static func toOps(_ opDtos: [OpDto]?) -> [Op] {
        var ops:[Op] = []
        if let opDtos = opDtos {
            ops = opDtos.map { toOp($0) }
        }
        return ops
    }
    
    public static func toDeltaDto(_ delta: Delta?) -> DeltaDto {
        let deltaDto = DeltaDto()
        if let ops = delta?.ops {
            deltaDto.ops = ops.map { toOpDto($0) }
        }
        return deltaDto
    }
    
    public static func toOp(_ opDto: OpDto?) -> Op {
        let op = Op()
        if let opDto = opDto {
            if let delete = opDto.delete {
                op.delete = delete
            }
            if let retain = opDto.retain {
                op.retain = retain
            }
            op.insert = opDto.insert
            if let attributes = opDto.attributes {
                op.attributes = attributes
            }
        }
        return op
    }
    
    public static func toOpDto(_ op: Op?) -> OpDto {
        let opDto = OpDto()
        if let op = op {
            if op.delete > 0 {
                opDto.delete = op.delete
            }
            if op.retain > 0 {
                opDto.retain = op.retain
            }
            opDto.insert = op.insert
            if let attributes = op.attributes {
                opDto.attributes = attributes
            }
        }
        return opDto
    }
}

public class Delta: Equatable, CustomStringConvertible {
    static let NULL_CODE = 0
    static let NULL_CHARACTER = String(NULL_CODE)
    
    public var ops: [Op]
    
    public init(ops: [Op] = []) {
        self.ops = ops
    }
    
    public init(delta: Delta) {
        self.ops = delta.ops
    }
    
    public init(text: String) {
        if let delta = DeltaJson.fromJson(text) {
            self.ops = delta.ops
        } else {
            self.ops = []
        }
    }
    
    public static func == (lhs: Delta, rhs: Delta) -> Bool {
        return lhs.ops == rhs.ops
    }
    
    public var description: String {
        return ops.description
    }
    
    @discardableResult
    public func insert(num: Int, attributes: OpAttributes? = nil) -> Delta {
        guard num > 0 else { return self }
        return push(Op.insertOp(insert: AnyCodable(num), attributes: attributes))
    }
    
    @discardableResult
    public func insert(obj: [String: AnyCodable], attributes: OpAttributes? = nil) -> Delta {
        return push(Op.insertOp(insert: AnyCodable(obj), attributes: attributes))
    }
    
    @discardableResult
    public func insert(text: String, attributes: OpAttributes? = nil) -> Delta {
        guard !text.isEmpty else { return self }
        return push(Op.insertOp(insert: AnyCodable(text),attributes: attributes))
    }
    
    @discardableResult
    public func delete(length: Int) -> Delta {
        guard length > 0 else { return self }
        return push(Op.deleteOp(delete: length))
    }
    
    @discardableResult
    public func retain(retain: Int, attributes: OpAttributes? = nil) -> Delta {
        guard retain > 0 else { return self }
        return push(Op.retainOp(retain: retain,attributes: attributes))
    }
    
    @discardableResult
    public func push(_ newOp: Op) -> Delta {
        var index = self.ops.count
        var lastOp: Op? = index > 0 ? self.ops[index - 1] : nil
        if let lastOpA = lastOp {
            if newOp.delete > 0, lastOpA.delete > 0 {
                lastOpA.delete += newOp.delete
                return self
            }
            
            if lastOpA.delete > 0, newOp.insert != nil {
                index -= 1
                lastOp = index > 0 ? self.ops[index - 1] : nil
                if lastOp == nil {
                    self.ops.insert(newOp, at: 0)
                    return self
                }
            }
            
            if newOp.attributes == lastOpA.attributes {
                if let newInsert = newOp.insert?.value as? String, let lastInsert = lastOpA.insert?.value as? String {
                    self.ops[index - 1] = Op.insertOp(insert:AnyCodable(lastInsert + newInsert))
                    if let attributes = newOp.attributes {
                        self.ops[index - 1].attributes = attributes
                    }
                    return self
                } else if newOp.retain > 0, lastOpA.retain > 0 {
                    self.ops[index - 1] = Op.retainOp(retain: lastOpA.retain + newOp.retain)
                    if let attributes = newOp.attributes {
                        self.ops[index - 1].attributes = attributes
                    }
                    return self
                }
            }
        }
        self.ops.insert(newOp, at: index)
        return self
    }
    
    @discardableResult
    public func chop() -> Delta {
        if let lastOp = self.ops.last, lastOp.retain > 0, lastOp.attributes?.isEmpty ?? true {
            self.ops.removeLast()
        }
        return self
    }
    
    public func length() -> Int {
        return ops.reduce(0) { $0 + Op.length($1) }
    }
    
    public func changeLength() -> Int {
        return ops.reduce(0) {
            $0 + (Op.length($1) * ($1.insert != nil ? 1 : $1.delete > 0 ? -1 : 0))
        }
    }
    
    public func reduce<R>(_ initial: R, operation: (R, Op) -> R) -> R {
        return ops.reduce(initial, operation)
    }
    
    public func map<R>(_ transform: (Op) -> R) -> [R] {
        return ops.map(transform)
    }
    
    public func filter(_ predicate: (Op) -> Bool) -> [Op] {
        return ops.filter(predicate)
    }
    
    public func forEach(_ action: (Op) -> Void) {
        ops.forEach(action)
    }
    
    public func partition(_ predicate: (Op) -> Bool) -> ([Op], [Op]) {
        var first: [Op] = []
        var second: [Op] = []
        forEach { if predicate($0) { first.append($0) } else { second.append($0) } }
        return (first, second)
    }
    
    public func compose(_ other: Delta) -> Delta {
        let thisIter = Op.Iterator(ops: self.ops)
        let otherIter = Op.Iterator(ops: other.ops)
        let delta = Delta()
        
        while thisIter.hasNext() || otherIter.hasNext() {
            if otherIter.peekType() == .insert {
                delta.push(otherIter.next())
            } else if thisIter.peekType() == .delete {
                delta.push(thisIter.next())
            } else {
                let length = min(thisIter.peekLength(), otherIter.peekLength())
                let thisOp = thisIter.next(len: length)
                let otherOp = otherIter.next(len: length)
                if otherOp.retain > 0 {
                    let newOp = Op()
                    if thisOp.retain > 0 {
                        newOp.retain = length
                    } else {
                        newOp.insert = thisOp.insert
                    }
                    newOp.attributes = AttributesUtil.compose(a: thisOp.attributes, b: otherOp.attributes, keepNull: thisOp.retain > 0)
                    delta.push(newOp)
                } else if otherOp.delete > 0, thisOp.retain > 0 {
                    delta.push(otherOp)
                }
            }
        }
        
        return delta.chop()
    }
    
    public func diff(_ other: Delta) -> Delta {
        guard self.ops != other.ops else { return Delta() }
        
        let stringBuilder1 = ops.compactMap { $0.insert?.value as? String ?? Delta.NULL_CHARACTER }.joined()
        let stringBuilder2 = other.ops.compactMap { $0.insert?.value as? String ?? Delta.NULL_CHARACTER }.joined()
        
        let thisIter = Op.Iterator(ops: self.ops)
        let otherIter = Op.Iterator(ops: other.ops)
        let diffResult = computeDiff(a: stringBuilder1, b: stringBuilder2)
        let delta = Delta()
        
        diffResult.forEach {
            var length = $0.text.count
            while length > 0 {
                var opLength = 0
                switch $0.operation {
                    case DIFF_INSERT:
                        opLength = min(otherIter.peekLength(), length)
                        delta.push(otherIter.next(len: opLength))
                    case DIFF_DELETE:
                        opLength = min(length, thisIter.peekLength())
                        thisIter.next(len: opLength)
                        delta.delete(length: opLength)
                    case DIFF_EQUAL:
                        opLength = min(min(thisIter.peekLength(), otherIter.peekLength()), length)
                        let thisOp = thisIter.next(len: opLength)
                        let otherOp = otherIter.next(len: opLength)
                        if let thisOpV = thisOp.insert?.value as? String,let otherOpV = otherOp.insert?.value as? String, thisOpV == otherOpV {
                            delta.retain(retain: opLength, attributes: AttributesUtil.diff(a: thisOp.attributes, b: otherOp.attributes))
                        } else {
                            delta.push(otherOp).delete(length: opLength)
                        }
                    default: break
                        
                }
                length -= opLength
            }
        }
        
        return delta.chop()
    }
    
    public func transform(_ other: Delta, priority: Bool = false) -> Delta {
        let thisIter = Op.Iterator(ops: self.ops)
        let otherIter = Op.Iterator(ops: other.ops)
        let delta = Delta()
        
        while thisIter.hasNext() || otherIter.hasNext() {
            if thisIter.peekType() == .insert, priority || otherIter.peekType() != .insert {
                delta.retain(retain: Op.length(thisIter.next()))
            } else if otherIter.peekType() == .insert {
                delta.push(otherIter.next())
            } else {
                let length = min(thisIter.peekLength(), otherIter.peekLength())
                let thisOp = thisIter.next(len: length)
                let otherOp = otherIter.next(len: length)
                if thisOp.delete > 0 {
                    continue
                } else if otherOp.delete > 0 {
                    delta.push(otherOp)
                } else {
                    delta.retain(retain: length, attributes: AttributesUtil.transform(a: thisOp.attributes, b: otherOp.attributes, priority: priority))
                }
            }
        }
        
        return delta.chop()
    }
    
    public func transformPosition(_ indexFrom: Int, priority: Bool = false) -> Int {
        let thisIter = Op.Iterator(ops: self.ops)
        var offset = 0
        var index = indexFrom
        while thisIter.hasNext(), offset <= index {
            let length = thisIter.peekLength()
            let nextType = thisIter.peekType()
            thisIter.next()
            if nextType == .delete {
                index -= min(length, index - offset)
            } else if nextType == .insert, offset < index || !priority {
                index += length
            }
            offset += length
        }
        return index
    }
    
    public func concat(_ other: Delta) -> Delta {
        let delta = Delta(ops: self.ops)
        if !other.ops.isEmpty {
            delta.push(other.ops[0])
            if other.ops.count > 1 {
                delta.ops.append(contentsOf: other.ops.dropFirst())
            }
        }
        return delta
    }
    
    public func slice(start: Int = 0, end: Int = Int.max) -> Delta {
        var ops: [Op] = []
        let iter = Op.Iterator(ops: self.ops)
        var index = 0
        while index < end, iter.hasNext() {
            var nextOp: Op
            if index < start {
                nextOp = iter.next(len: start - index)
            } else {
                nextOp = iter.next(len: end - index)
                ops.append(nextOp)
            }
            index += Op.length(nextOp)
        }
        return Delta(ops: ops)
    }
    /**
     [{"insert":"有序列表\n有序项1"},{"attributes":{"list":"ordered"},"insert":"\n"},{"insert":"有序项2"},{"attributes":{"list":"ordered"},"insert":"\n"},{"insert":"有序项3"},{"attributes":{"list":"ordered"},"insert":"\n"}]
     */
    // 遍历每一行
    public func eachLine(action: (Delta, OpAttributes, Int) -> Bool, newline: String = "\n") {
        let iter = Op.Iterator(ops: self.ops)
        var line = Delta()
        var i = 0
        while iter.hasNext() {
            // 如果下一个操作不是插入操作，退出循环
            guard iter.peekType() == .insert else { return }
            let thisOp = iter.peek()
            let start = Op.length(thisOp) - iter.peekLength()
            var index = -1
            // 查找从位置 start 开始的下一个换行符(newline)的位置
            if let insertString = thisOp?.insert?.value as? String {
                if let startIdx = insertString.index(insertString.startIndex, offsetBy: start, limitedBy: insertString.endIndex),
                   let range = insertString.range(of: newline, options: [], range: startIdx..<insertString.endIndex) {
                    index = insertString.distance(from: insertString.startIndex, to: range.lowerBound)-start
                }
            }
            if index < 0 {            
                // 如果没有找到换行符，当前操作全部添加到当前行
                line.push(iter.next())
            } else if index > 0 { 
                // 如果在当前操作中找到换行符，将换行符之前的部分添加到当前行
                line.push(iter.next(len: index))
            } else {
                // 如果换行符在当前操作的开头，执行回调函数
                if !action(line, iter.next(len: 1).attributes ?? OpAttributes(), i) {
                    return
                }
                i += 1
                line = Delta()
            }
        }
        if line.length() > 0 {
            _ = action(line, OpAttributes(), i)
        }
    }
}
