import Vapor
import FluentKit
import Cryptos
import DataConvertable
import OrderedCollections

extension Environment.Config: Environment.Template {
    @inlinable
    public static func withEnv(dic origin: inout OrderedDictionary<String, Environment.Types>) {
        origin["id"] = .uuid()
        origin["name"] = .string()
        origin["port"] = .int()
        origin["hostname"] = .string()
        origin["domain"] = .string(optional: true)
        origin["manager_url"] = .url()
        origin["db_services"] = .array(.template(Environment.DBService.self))
        origin["log"] = .template(Environment.Log.self)
    }
    
    @inlinable
    public static func with(driverKeys: [any Environment.DriverKey.Type], dic origin: inout OrderedDictionary<String, Environment.Types>) {
        for key in driverKeys {
            origin[key.label] = key.valueType
        }
    }
    
    @inlinable
    public init(data: [String: Any], driverKeys: [any Environment.DriverKey.Type], extra: [String: Any]) {
        self.id = data["id"] as! UUID
        self.name = data["name"] as! String
        self.port = data["port"] as! Int
        self.hostname = data["hostname"] as! String
        self.domain = data["domain"] as? String
        self.managerUrl = data["manager_url"] as! URL
        self.dbServices = data["db_services"] as! [Environment.DBService]
        self.log = data["log"] as! Environment.Log
        self.driverKeys = driverKeys
        for key in driverKeys {
            self.storage = key.apply(on: storage, value: data[key.label])
        }
    }
}

extension Environment.Log: Environment.Template {
    @inlinable
    public static func withEnv(dic origin: inout OrderedDictionary<String, Environment.Types>) {
        origin["directory"] = .url()
    }
    
    @inlinable
    public init(data: [String : Any], driverKeys: [any Environment.DriverKey.Type], extra: [String: Any]) {
        self.directory = data["directory"] as! URL
    }
}

extension Environment.DBService: Environment.Template {
    @inlinable
    public static func withEnv(dic origin: inout OrderedDictionary<String, Environment.Types>) {
        origin["name"] = .string()
        origin["host"] = .string()
        origin["port"] = .int()
        origin["dbs"] = .array(.template(Environment.DB.self))
    }
    
    @inlinable
    public init(data: [String : Any], driverKeys: [any Environment.DriverKey.Type], extra: [String: Any]) {
        self.id = .init(string: data["name"] as! String)
        self.host = data["host"] as! String
        self.port = data["port"] as! Int
        self.dbs = data["dbs"] as! [Environment.DB]
    }
}

extension Environment.DB: Environment.Template {
    @inlinable
    public static func withEnv(dic origin: inout OrderedDictionary<String, Environment.Types>) {
        origin["name"] = .string()
        origin["user"] = .string()
        origin["password"] = .string()
        origin["file_storage_key"] = .base64Data(optional: true)
    }
    
    @inlinable
    public init(data: [String : Any], driverKeys: [any Environment.DriverKey.Type], extra: [String : Any]) {
        let keyData = data["file_storage_key"]
        self = Self.init(
            dbServiceId: .init(string: extra["name"] as! String),
            host: extra["host"] as! String,
            port: extra["port"] as! Int,
            parameter: .init(
                name: data["name"] as! String,
                user: data["user"] as! String,
                password: data["password"] as! String,
                fileStorageKey: keyData == nil ? nil : .new(data: keyData as! Data)
            )
        )
    }
}

extension Environment {
    @inlinable
    static func get(with prefix: String, driverKeys: [any DriverKey.Type] = []) throws(Errcase.ErrType) -> Config { try .parse(prefix: prefix, driverKeys: driverKeys) }
    
    public indirect enum Types: Sendable {
        case string(optional: Bool = false)
        case int(any (FixedWidthInteger & Sendable).Type = Int.self, optional: Bool = false)
        case base64String(optional: Bool = false)
        case base64Data(optional: Bool = false)
        case url(optional: Bool = false)
        case uri(optional: Bool = false)
        case uuid(optional: Bool = false)
        case template(Template.Type, optional: Bool = false)
        case array(Self, optional: Bool = false)
        
        public var isOptional: Bool {
            switch self {
            case .string(let optional): optional
            case .int(_, let optional): optional
            case .base64String(let optional): optional
            case .base64Data(let optional): optional
            case .url(let optional): optional
            case .uri(let optional): optional
            case .uuid(let optional): optional
            case .template(_, let optional): optional
            case .array(_, let optional): optional
            }
        }
    }

    public protocol Template: Sendable {
        static func envs(driverKeys: [any Environment.DriverKey.Type]) -> OrderedDictionary<String, Environment.Types>
        static func withEnv(dic origin: inout OrderedDictionary<String, Environment.Types>)
        static func with(driverKeys: [any DriverKey.Type], dic origin: inout OrderedDictionary<String, Environment.Types>)
        init(data: [String: Any], driverKeys: [any DriverKey.Type], extra: [String: Any])
    }

    @frozen
    public enum Errcase: String, ErrList {
        case parseFailed = "环境变量解析失败"
        case typeIncorrect = "环境变量配置类型不匹配"
        case missingKey = "环境变量配置字段缺失"
        case internalFailed = "内部错误"
    }
}

public extension Environment.Template {
    @inlinable
    static func envs(driverKeys: [any Environment.DriverKey.Type]) -> OrderedDictionary<String, Environment.Types> {
        var res = OrderedDictionary<String, Environment.Types>()
        withEnv(dic: &res)
        with(driverKeys: driverKeys, dic: &res)
        return res
    }
    
    @inlinable
    static func with(driverKeys: [any Environment.DriverKey.Type], dic origin: inout OrderedDictionary<String, Environment.Types>) {}
}

extension Environment.Template {
    @inlinable
    static func parse(
        prefix: String?,
        driverKeys: [any Environment.DriverKey.Type] = [],
        getValue: @escaping ((String) -> String?) = { Environment.get($0) },
        extra: [String: Any] = [:]
    ) throws(Environment.Errcase.ErrType) -> Self {
        guard let res = try nullableParse(
            prefix: prefix,
            driverKeys: driverKeys,
            getValue: getValue,
            extra: extra,
            nullable: false
        ) else {
            throw Environment.Errcase.internalFailed.d(prefix ?? "<<No prefix>>", category: .inherit)
        }
        return res
    }
    
    @inlinable
    static func nullableParse(
        prefix: String?,
        driverKeys: [any Environment.DriverKey.Type],
        getValue: @escaping ((String) -> String?) = { Environment.get($0) },
        extra: [String: Any] = [:],
        nullable: Bool
    ) throws(Environment.Errcase.ErrType) -> Self? {
        var values: [String: Any] = [:]
        for (key, v) in Self.envs(driverKeys: driverKeys) {
            let k = prefix == nil ? key : "\(prefix!)_\(key.uppercased())"
            let optional = v.isOptional
            
            if let res = try castValue(
                prefix: prefix,
                key: k,
                value: v,
                optional: optional,
                driverKeys: driverKeys,
                getValue: getValue,
                extra: values,
                nullable: nullable
            ) {
                values[key] = res
            } else if !optional {
                return nil
            }
        }
        return Self(data: values, driverKeys: driverKeys, extra: extra)
    }
    
    @inlinable
    static func castValue(
        prefix: String?,
        key k: String,
        value v: Environment.Types,
        optional: Bool,
        driverKeys: [any Environment.DriverKey.Type],
        getValue: @escaping ((String) -> String?),
        extra: [String: Any] = [:],
        nullable: Bool
    ) throws(Environment.Errcase.ErrType) -> Any? {
        let value: String!
        
        switch v {
        case .string, .int, .url, .uri, .uuid, .base64Data, .base64String:
            guard let vv = getValue(k) else {
                if optional || nullable {
                    return nil
                } else {
                    throw Environment.Errcase.missingKey.d(k, category: .external())
                }
            }
            value = vv
        default:
            value = nil
        }
        
        switch v {
        case .string:
            return value
            
        case .int(let type, _):
            guard let v = type.init(value) else { throw Environment.Errcase.typeIncorrect.d(k, category: .external()) }
            return v
            
        case .base64String:
            return Base64String(value)
            
        case .base64Data:
            return try required(throws: Environment.Errcase.parseFailed, k, category: .external()) {
                try Base64String(value).dataRes.get()
            }
            
        case .uri:
            return URI(string: value)
            
        case .url:
            guard let v = URL(string: value) else { throw Environment.Errcase.typeIncorrect.d(k, category: .external()) }
            return v
            
        case .uuid:
            guard let v = UUID(uuidString: value) else { throw Environment.Errcase.typeIncorrect.d(k, category: .external()) }
            return v
            
        case .template(let template, _):
            guard let v = try template.nullableParse(prefix: k, driverKeys: driverKeys, getValue: getValue, extra: extra, nullable: optional) else {
                if optional || nullable {
                    return nil
                } else {
                    throw Environment.Errcase.missingKey.d(k, category: .external())
                }
            }
            return v
            
        case .array(let value, _):
            let isItemOptional = value.isOptional
            
            guard let countStr = getValue(k + "_COUNT") else {
                if optional || nullable {
                    return nil
                } else {
                    throw Environment.Errcase.missingKey.d(k + "_COUNT", category: .external())
                }
            }
            
            guard let count = Int(countStr) else {
                if optional || nullable {
                    return nil
                } else {
                    throw Environment.Errcase.typeIncorrect.d(k, category: .external())
                }
            }
            
            var vs: [Any?] = []
            for i in 0..<count {
                if let item = try castValue(
                    prefix: prefix,
                    key: "\(k)_\(i + 1)",
                    value: value,
                    optional: isItemOptional,
                    driverKeys: driverKeys,
                    getValue: getValue,
                    extra: extra,
                    nullable: false
                ) {
                    vs.append(item)
                } else {
                    if isItemOptional {
                        vs.append(nil)
                    } else {
                        throw Environment.Errcase.missingKey.d("\(k)_\(i + 1)", category: .external())
                    }
                }
            }
            return vs
        }
    }
}
