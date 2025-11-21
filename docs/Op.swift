import Foundation

public typealias OpAttributes = [String: AnyCodable]

public class OpDto: Codable {
    public var insert: AnyCodable? /// 当前行的内容
    public var delete: Int? /// 从特定位置删除指定数量的字符。
    public var retain: Int? /// 保留特定数量的字符，通常用于跳过这些字符，并可选择性地修改这些字符的属性。
    public var attributes: OpAttributes? /// 当前行的Attributes

    private enum CodingKeys: String, CodingKey {
        case insert, delete, retain, attributes
    }

    public init(insert: AnyCodable? = nil, delete: Int? = nil, retain: Int? = nil, attributes: [String: AnyCodable]? = nil) {
        self.insert = insert
        self.delete = delete
        self.retain = retain
        self.attributes = attributes
    }
}


public class Op: Equatable, CustomStringConvertible {
    public enum Types {
        case insert
        case retain
        case delete
    }

    public var insert: AnyCodable? = nil
    public var delete: Int = 0
    public var retain: Int = 0
    public var attributes: OpAttributes? = nil

    public static func == (lhs: Op, rhs: Op) -> Bool {
        if lhs.delete != rhs.delete {
            return false
        }
        if lhs.retain != rhs.retain {
            return false
        }
        if let lhsInsert = lhs.insert, let rhsInsert = rhs.insert {
            if lhsInsert != rhsInsert {
                return false
            }
        } else if lhs.insert != nil || rhs.insert != nil {
            return false
        }
        
        if let lAtt = lhs.attributes,let rAtt = rhs.attributes,lAtt != rAtt && !(lAtt.count == 0 && rAtt.count == 0) {
            return false
        }
        return true
    }

    public func hashCode() -> Int {
//        var result = insert?.hashValue()
//        result = 31 * result + delete
//        result = 31 * result + retain
//        result = 31 * result
        // todo
        return 0
    }

    public var description: String {
        return "{ insert: \(String(describing: insert)), delete: \(delete), retain: \(retain), attr: \(String(describing: attributes)) }"
    }

    func getAttributeValue(attributeName: String) -> Any? {
        return attributes?[attributeName]
    }

    class Iterator {
        private var ops: [Op]? // 操作的数组
        private var index = 0 // 当前操作的索引
        private var offset = 0 // 当前操作的偏移量
                               
        // 获取当前操作
        private var current: Op {
            return ops![index]
        }

        init(ops: [Op]?) {
            self.ops = ops
        }
        
        /// 检查是否操作数组不为空且当前索引未超出数组范围
        private func notEmptyOrEnd() -> Bool {
            return ops != nil && ops!.count > index
        }
        /// 查看当前操作的剩余长度
        public func peekLength() -> Int {
            return notEmptyOrEnd() ? Op.length(current) - offset : Iterator.INFINITY
        }
        /// 查看当前操作
        public func peek() -> Op? {
            return notEmptyOrEnd() ? current : nil
        }
        /// 检查是否还有下一个操作
        public func hasNext() -> Bool {
            return peekLength() < Iterator.INFINITY
        }
        
        /// 查看当前操作的类型（插入、删除、保留）
        public func peekType() -> Types {
            if notEmptyOrEnd() {
                if current.delete > 0 {
                    return .delete
                } else if current.retain > 0 {
                    return .retain
                } else {
                    return .insert
                }
            }
            return .retain
        }
        /// 获取下一个操作（默认获取整个操作）
        @discardableResult
        public func next() -> Op {
            return self.next(len: nil)
        }
        /// 获取下一个操作（可以指定长度）
        /// 如果指定的长度超过当前操作的剩余长度，则返回当前操作的剩余部分，并移动到下一个操作；否则，返回指定长度的操作部分。
        @discardableResult
        public func next(len: Int?) -> Op {
            var length = len ?? Iterator.INFINITY
            let nextOp = peek()
            let oldOffset = offset
            if let nextOp = nextOp {
                let opLength = Op.length(nextOp)
                /// 如果指定的长度 length 大于或等于当前操作的剩余长度（opLength - offset），则将 length 设置为当前操作的剩余长度，并将索引 index 移动到下一个操作，同时重置 offset 为 0。
                /// 否则，将 offset 增加 length 的值。
                if length >= opLength - offset {
                    length = opLength - offset
                    index += 1
                    offset = 0
                } else {
                    offset += length
                }
                if nextOp.delete > 0 {
                    return Op.deleteOp(delete: length)
                } else {
                    let retOp = Op()
                    retOp.attributes = nextOp.attributes
                    if nextOp.retain > 0 {
                        retOp.retain = length
                    } else if let insert = nextOp.insert?.value as? String {
                        retOp.insert = AnyCodable(String(insert.dropFirst(oldOffset).prefix(length)))
                    } else {
                        retOp.insert = nextOp.insert
                    }
                    return retOp
                }
            } else {
                return Op.retainOp(retain: Iterator.INFINITY)
            }
        }

        static var INFINITY = Int.max
    }

    @discardableResult
    public static func insertOp(insert: AnyCodable) -> Op {
        return self.insertOp(insert: insert, attributes: nil)
    }

    @discardableResult
    public static func insertOp(insert: AnyCodable, attributes: OpAttributes?) -> Op {
        let op = Op()
        op.insert = insert
        op.attributes = attributes
        return op
    }

    @discardableResult
    public static func deleteOp(delete: Int) -> Op {
        let op = Op()
        op.delete = delete
        return op
    }

    @discardableResult
    public static func retainOp(retain: Int) -> Op {
        return self.retainOp(retain: retain, attributes: nil)
    }

    @discardableResult
    public static func retainOp(retain: Int, attributes: OpAttributes?) -> Op {
        let op = Op()
        op.retain = retain
        op.attributes = attributes
        return op
    }

    public static func length(_ op: Op?) -> Int {
        guard let op = op else {
            return 0
        }
        if op.delete > 0 {
            return op.delete
        } else if op.retain > 0 {
            return op.retain
        } else if let insert = op.insert?.value as? String {
            return insert.count
        } else {
            return 1
        }
    }
}


public class OpImage: Codable {
    public var fullScreen: String?
    public var width: String?
    public var height: String?
    public var url: String?

    enum CodingKeys: String, CodingKey {
        case fullScreen = "fullScreen"
        case width = "width"
        case height = "height"
        case url = "url"
    }
    // 便利构造器，从 map 转换为 DeltaImage
    public convenience init?(map: [String: AnyCodable]) {
        self.init()

        // 使用 guard 语句确保所有需要的键都存在
        guard let fullScreen = map["fullScreen"],
              let width = map["width"],
              let height = map["height"],
              let url = map["url"] else {
            return nil
        }

        self.fullScreen = fullScreen.value as? String
        self.width = width.value as? String
        self.height = height.value as? String
        self.url = url.value as? String
    }
}

public class OpMention: Codable {
    public var index: String?
    public var denotationChar: String?
    public var id: String?
    public var name: String?
    public var user_type:String?

    enum CodingKeys: String, CodingKey {
        case index = "index"
        case denotationChar = "denotationChar"
        case id = "id"
        case name = "name"
        case user_type = "user_type"
    }
    
    public convenience init?(map: [String: AnyCodable]) {
        self.init()

        // 使用 guard 语句确保所有需要的键都存在
        guard let index = map["index"],
              let denotationChar = map["denotationChar"],
              let id = map["id"],
              let name = map["name"] else {
            return nil
        }

        self.index = index.value as? String
        self.denotationChar = denotationChar.value as? String
        self.id = id.value as? String
        self.name = name.value as? String
        self.user_type = map["user_type"]?.value as? String
    }
}

public class OpEmoji: Codable {
    public var content: String?

    enum CodingKeys: String, CodingKey {
        case content = "content"
    }
    
    public convenience init?(map: [String: AnyCodable]) {
        self.init()

        // 使用 guard 语句确保所有需要的键都存在
        guard let content = map["content"] else {
            return nil
        }

        self.content = content.value as? String
    }
}
