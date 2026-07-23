import Testing
import Foundation
@testable import VaporTube

extension Environment.Config {
    var extras: [ExtraTestingEnvConfig] { self.storage[ExtraKey.self]! }
}

extension Environment.Config {
    var optionalExtras: ExtraTestingEnvConfigItem? { self.storage[OptionalExtraKey.self] ?? nil }
}

struct ExtraKey: Environment.DriverKey {
    typealias Value = [ExtraTestingEnvConfig]
    static let label = "extra"
    static let valueType: Vapor.Environment.Types = .array(.template(ExtraTestingEnvConfig.self))
    static func loggerStrategies(for directory: URL) -> [LoggerStrategy] { [] }
}

struct OptionalExtraKey: Environment.DriverKey {
    typealias Value = ExtraTestingEnvConfigItem?
    static let label = "optional_extra"
    static let valueType: Vapor.Environment.Types = .template(ExtraTestingEnvConfigItem.self, optional: true)
    static func loggerStrategies(for directory: URL) -> [LoggerStrategy] { [] }
}

struct ExtraTestingEnvConfig: Environment.Template {
    let optionalArray: [String?]?
    let optionalNestedArray: [[Int]?]
    let nestedArray: [[Int]]
    let complexItems: [[[ExtraTestingEnvConfigItem]]]
    
    init() { self.init(optionalArray: nil) }
    
    init(
        optionalArray: [String?]?,
        optionalNestedArray: [[Int]?] = [],
        nestedArray: [[Int]] = [],
        complexItems: [[[ExtraTestingEnvConfigItem]]] = []
    ) {
        self.optionalArray = optionalArray
        self.optionalNestedArray = optionalNestedArray
        self.nestedArray = nestedArray
        self.complexItems = complexItems
    }
    
    static func withEnv(dic origin: inout OrderedDictionary<String, Vapor.Environment.Types>) {
        origin["optional_array"] = .array(.string(optional: true), optional: true)
        origin["optional_nested_array"] = .array(.array(.int(), optional: true))
        origin["nested_array"] = .array(.array(.int()))
        origin["complex_items"] = .array(.array(.array(.template(ExtraTestingEnvConfigItem.self))))
    }
    
    init(data: [String : Any], driverKeys: [any Vapor.Environment.DriverKey.Type], extra: [String : Any]) {
        self.optionalArray = data["optional_array"] as? [String?]
        self.optionalNestedArray = data["optional_nested_array"] as! [[Int]?]
        self.nestedArray = data["nested_array"] as! [[Int]]
        self.complexItems = data["complex_items"] as! [[[ExtraTestingEnvConfigItem]]]
    }
}

struct ExtraTestingEnvConfigItem: Environment.Template {
    let data: String
    let index: Int
    
    init() { self.init(data: "", index: 0) }
    
    init(
        data: String,
        index: Int
    ) {
        self.data = data
        self.index = index
    }
    
    static func withEnv(dic origin: inout OrderedDictionary<String, Vapor.Environment.Types>) {
        origin["data"] = .string()
        origin["index"] = .int()
    }
    
    init(data: [String : Any], driverKeys: [any Vapor.Environment.DriverKey.Type], extra: [String : Any]) {
        self.data = data["data"] as! String
        self.index = data["index"] as! Int
    }
}

@Suite("驱动环境变量解析测试集", .serialized)
struct DriverEnvParsingTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .driverEnvParsing {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let TestToken = SendableSymmKey(key: .init(data: Data(base64Encoded: TestTokenStr)!))
    static let TestTokenStr = "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI="
    
    @Test("无 Extra 所需的环境变量，应当失败")
    func noExtraEnvShouldFail() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_DOMAIN": "testing.whooshing.space",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                
                "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
                
                "WHOOSHING_API_SERVICE_FILE_STORAGE_DIR": "~/testing",
                "WHOOSHING_API_SERVICE_FILE_STORAGE_UNIX_PERMISSION_OWNER_ID": "1001",
                "WHOOSHING_API_SERVICE_FILE_STORAGE_UNIX_PERMISSION_GROUP_ID": "1002",
                "WHOOSHING_API_SERVICE_FILE_STORAGE_UNIX_PERMISSION_RWX": "480",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_FILE_STORAGE_KEY": "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI=",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_FILE_STORAGE_KEY": "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI=",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_NAME": "woo_db_2_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_USER": "woo_2_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_PASSWORD": "woo_test_2_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_FILE_STORAGE_KEY": "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI=",
            ][key] }
        })
    }
    
    @Test("测试环境变量读取")
    func testEnvironmentDetect() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self, OptionalExtraKey.self]) { key in [
            "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
            "WHOOSHING_API_SERVICE_NAME": "Testing Project",
            "WHOOSHING_API_SERVICE_PORT": "7777",
            "WHOOSHING_API_SERVICE_DOMAIN": "testing.whooshing.space",
            "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
            "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
            
            "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
            
            "WHOOSHING_API_SERVICE_FILE_STORAGE_DIR": "~/testing",
            "WHOOSHING_API_SERVICE_FILE_STORAGE_UNIX_PERMISSION_OWNER_ID": "1001",
            "WHOOSHING_API_SERVICE_FILE_STORAGE_UNIX_PERMISSION_GROUP_ID": "1002",
            "WHOOSHING_API_SERVICE_FILE_STORAGE_UNIX_PERMISSION_RWX": "480",
            
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
            
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_FILE_STORAGE_KEY": "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI=",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
            
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_FILE_STORAGE_KEY": "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI=",
                    
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_NAME": "woo_db_2_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_USER": "woo_2_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_PASSWORD": "woo_test_2_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_FILE_STORAGE_KEY": "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI=",
            
            "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
                 
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "0",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                    "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "1",
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345"
        ][key] }
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.name == "Testing Project")
        #expect(project.domain == "testing.whooshing.space")
        #expect(project.port == 7777)
        #expect(project.hostname == "localhost")
        
        #expect(project.log.directory.absoluteString == "/User/tester/logfile.log")
        
        #expect(project.dbServices.count == 2)
        #expect(project.managerUrl.absoluteString == "https://example.com")
        
        #expect(project.dbServices[0].id == .init(string: "service_1"))
        #expect(project.dbServices[0].port == 5432)
        #expect(project.dbServices[0].dbs.count == 1)
        #expect(project.dbServices[0].dbs[0].id.string == "service_1/woo_db")
        #expect(project.dbServices[0].dbs[0].parameter.user == "woo")
        #expect(project.dbServices[0].dbs[0].parameter.password == "woo_test")
        #expect(project.dbServices[0].dbs[0].parameter.fileStorageKey == Self.TestToken)
        
        #expect(project.dbServices[1].id == .init(string: "service_2"))
        #expect(project.dbServices[1].port == 5433)
        #expect(project.dbServices[1].dbs.count == 2)
        #expect(project.dbServices[1].dbs[0].id.string == "service_2/woo_db_2")
        #expect(project.dbServices[1].dbs[0].parameter.user == "woo_2")
        #expect(project.dbServices[1].dbs[0].parameter.password == "woo_test_2")
        #expect(project.dbServices[1].dbs[0].parameter.fileStorageKey == Self.TestToken)
        #expect(project.dbServices[1].dbs[1].id.string == "service_2/woo_db_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.user == "woo_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.password == "woo_test_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.fileStorageKey == Self.TestToken)
        
        #expect(project.optionalExtras == nil)
        
        #expect(project.extras.count == 1)
        #expect(project.extras[0].optionalArray == nil)
        #expect(project.extras[0].nestedArray.count == 1)
        #expect(project.extras[0].nestedArray[0].count == 1)
        #expect(project.extras[0].nestedArray[0][0] == 100)
        #expect(project.extras[0].optionalNestedArray.count == 0)
        #expect(project.extras[0].complexItems.count == 1)
        #expect(project.extras[0].complexItems[0].count == 1)
        #expect(project.extras[0].complexItems[0][0].count == 1)
        #expect(project.extras[0].complexItems[0][0][0].data == "Hello World!")
        #expect(project.extras[0].complexItems[0][0][0].index == 2345)
    }
    
    @Test("测试环境变量读取2")
    func testEnvironmentDetect2() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self, OptionalExtraKey.self]) { key in [
            "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
            "WHOOSHING_API_SERVICE_NAME": "Testing Project",
            "WHOOSHING_API_SERVICE_PORT": "7777",
            "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
            "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
            
            "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
            
            "WHOOSHING_API_SERVICE_OPTIONAL_EXTRA_DATA": "extra",
            "WHOOSHING_API_SERVICE_OPTIONAL_EXTRA_INDEX": "28",
            
            "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_COUNT": "2",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_2": "YOU!",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "0",
                 
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                    "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "1",
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345"
        ][key] }
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.name == "Testing Project")
        #expect(project.domain == nil)
        #expect(project.port == 7777)
        #expect(project.hostname == "localhost")
        #expect(project.dbServices.count == 2)
        #expect(project.managerUrl.absoluteString == "https://example.com")
        #expect(project.log.directory.absoluteString == "/User/tester/logfile.log")
        #expect(project.dbServices[0].id == .init(string: "service_1"))
        #expect(project.dbServices[0].host == "example.host.com")
        #expect(project.dbServices[0].port == 5432)
        #expect(project.dbServices[0].dbs.count == 0)
        #expect(project.dbServices[1].id == .init(string: "service_2"))
        #expect(project.dbServices[1].host == "example.host.com")
        #expect(project.dbServices[1].port == 5433)
        #expect(project.dbServices[1].dbs.count == 0)
        
        let optionalExtras = try #require(project.optionalExtras)
        #expect(optionalExtras.data == "extra")
        #expect(optionalExtras.index == 28)
        
        #expect(project.extras.count == 1)
        let optionalArray = try #require(project.extras[0].optionalArray)
        #expect(optionalArray.count == 2)
        #expect(optionalArray[0] == nil)
        #expect(optionalArray[1] == "YOU!")
        #expect(project.extras[0].nestedArray.count == 1)
        #expect(project.extras[0].nestedArray[0].count == 1)
        #expect(project.extras[0].nestedArray[0][0] == 100)
        #expect(project.extras[0].optionalNestedArray.count == 0)
        #expect(project.extras[0].complexItems.count == 1)
        #expect(project.extras[0].complexItems[0].count == 1)
        #expect(project.extras[0].complexItems[0][0].count == 1)
        #expect(project.extras[0].complexItems[0][0][0].data == "Hello World!")
        #expect(project.extras[0].complexItems[0][0][0].index == 2345)
    }
    
    @Test("测试环境变量读取3")
    func testEnvironmentDetect3() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
            "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
            "WHOOSHING_API_SERVICE_NAME": "Testing Project",
            "WHOOSHING_API_SERVICE_PORT": "7777",
            "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
            "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
            
            "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
            
            "WHOOSHING_API_SERVICE_OPTIONAL_EXTRA_DATA": "extra",
            "WHOOSHING_API_SERVICE_OPTIONAL_EXTRA_INDEX": "28",
            
            "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_COUNT": "3",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_2": "YOU!",
                 
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "0",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                    "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "1",
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345"
        ][key] }
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.name == "Testing Project")
        #expect(project.domain == nil)
        #expect(project.port == 7777)
        #expect(project.hostname == "localhost")
        #expect(project.dbServices.count == 2)
        #expect(project.managerUrl.absoluteString == "https://example.com")
        #expect(project.log.directory.absoluteString == "/User/tester/logfile.log")
        #expect(project.dbServices[0].id == .init(string: "service_1"))
        #expect(project.dbServices[0].port == 5432)
        #expect(project.dbServices[0].dbs.count == 0)
        #expect(project.dbServices[1].id == .init(string: "service_2"))
        #expect(project.dbServices[1].port == 5433)
        #expect(project.dbServices[1].dbs.count == 0)
        
        #expect(project.optionalExtras == nil)
        
        #expect(project.extras.count == 1)
        let optionalArray = try #require(project.extras[0].optionalArray)
        #expect(optionalArray.count == 3)
        #expect(optionalArray[0] == nil)
        #expect(optionalArray[1] == "YOU!")
        #expect(optionalArray[2] == nil)
        #expect(project.extras[0].nestedArray.count == 1)
        #expect(project.extras[0].nestedArray[0].count == 1)
        #expect(project.extras[0].nestedArray[0][0] == 100)
        #expect(project.extras[0].optionalNestedArray.count == 0)
        #expect(project.extras[0].complexItems.count == 1)
        #expect(project.extras[0].complexItems[0].count == 1)
        #expect(project.extras[0].complexItems[0][0].count == 1)
        #expect(project.extras[0].complexItems[0][0][0].data == "Hello World!")
        #expect(project.extras[0].complexItems[0][0][0].index == 2345)
    }
    
    @Test("测试环境变量读取4")
    func testEnvironmentDetect4() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_COUNT": "2",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_2": "YOU!",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "2",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345"
            ][key] }
        })
    }
    
    @Test("测试环境变量读取5")
    func testEnvironmentDetect5() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
            "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
            "WHOOSHING_API_SERVICE_NAME": "Testing Project",
            "WHOOSHING_API_SERVICE_PORT": "7777",
            "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
            "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
            
            "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
            
            "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_COUNT": "3",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_2": "YOU!",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "2",
                    "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_2_COUNT": "1",
                        "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_2_1": "12",
                 
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                    "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "2",
            
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345",
            
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_1_DATA": "Item Data 2",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_1_INDEX": "1235"
        ][key] }
        
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.extras.count == 1)
        let optionalArray = try #require(project.extras[0].optionalArray)
        #expect(optionalArray.count == 3)
        #expect(optionalArray[0] == nil)
        #expect(optionalArray[1] == "YOU!")
        #expect(optionalArray[2] == nil)
        #expect(project.extras[0].nestedArray.count == 1)
        #expect(project.extras[0].nestedArray[0].count == 1)
        #expect(project.extras[0].nestedArray[0][0] == 100)
        #expect(project.extras[0].optionalNestedArray.count == 2)
        #expect(project.extras[0].optionalNestedArray[0] == nil)
        #expect(project.extras[0].optionalNestedArray[1]!.count == 1)
        #expect(project.extras[0].optionalNestedArray[1]![0] == 12)
        #expect(project.extras[0].complexItems.count == 1)
        #expect(project.extras[0].complexItems[0].count == 2)
        #expect(project.extras[0].complexItems[0][0].count == 1)
        #expect(project.extras[0].complexItems[0][0][0].data == "Hello World!")
        #expect(project.extras[0].complexItems[0][0][0].index == 2345)
        #expect(project.extras[0].complexItems[0][1][0].data == "Item Data 2")
        #expect(project.extras[0].complexItems[0][1][0].index == 1235)
    }
    
    @Test("测试环境变量读取6")
    func testEnvironmentDetect6() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self, OptionalExtraKey.self]) { key in [
            "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
            "WHOOSHING_API_SERVICE_NAME": "Testing Project",
            "WHOOSHING_API_SERVICE_PORT": "7777",
            "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
            "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
            
            "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
            
            "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_COUNT": "3",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_2": "YOU!",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "4",
            
                    "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_2_COUNT": "1",
                        "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_2_1": "12",
            
                    "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_4_COUNT": "2",
                        "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_4_1": "100",
                        "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_4_2": "300",
                 
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
            
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                    "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "2",
            
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345",
            
                        "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_COUNT": "1",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_1_DATA": "Item Data 2",
                            "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_1_INDEX": "1235"
        ][key] }
        
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.extras.count == 1)
        #expect(project.optionalExtras == nil)
        let optionalArray = try #require(project.extras[0].optionalArray)
        #expect(optionalArray.count == 3)
        #expect(optionalArray[0] == nil)
        #expect(optionalArray[1] == "YOU!")
        #expect(optionalArray[2] == nil)
        #expect(project.extras[0].nestedArray.count == 1)
        #expect(project.extras[0].nestedArray[0].count == 1)
        #expect(project.extras[0].nestedArray[0][0] == 100)
        #expect(project.extras[0].optionalNestedArray.count == 4)
        #expect(project.extras[0].optionalNestedArray[0] == nil)
        #expect(project.extras[0].optionalNestedArray[2] == nil)
        #expect(project.extras[0].optionalNestedArray[1]!.count == 1)
        #expect(project.extras[0].optionalNestedArray[1]![0] == 12)
        #expect(project.extras[0].optionalNestedArray[3]!.count == 2)
        #expect(project.extras[0].optionalNestedArray[3]![0] == 100)
        #expect(project.extras[0].optionalNestedArray[3]![1] == 300)
        #expect(project.extras[0].complexItems.count == 1)
        #expect(project.extras[0].complexItems[0].count == 2)
        #expect(project.extras[0].complexItems[0][0].count == 1)
        #expect(project.extras[0].complexItems[0][0][0].data == "Hello World!")
        #expect(project.extras[0].complexItems[0][0][0].index == 2345)
        #expect(project.extras[0].complexItems[0][1][0].data == "Item Data 2")
        #expect(project.extras[0].complexItems[0][1][0].index == 1235)
    }
    
    @Test("测试环境变量读取7")
    func testEnvironmentDetect7() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_EXTRA_COUNT": "1",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_COUNT": "3",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_ARRAY_2": "YOU!",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_COUNT": "4",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_2_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_2_1": "12",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_4_COUNT": "2",
                "WHOOSHING_API_SERVICE_EXTRA_1_OPTIONAL_NESTED_ARRAY_4_1": "100",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_NESTED_ARRAY_1_1": "100",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_DATA": "Hello World!",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_1_1_INDEX": "2345",
                
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_COUNT": "1",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_1_DATA": "Item Data 2",
                "WHOOSHING_API_SERVICE_EXTRA_1_COMPLEX_ITEMS_1_2_1_INDEX": "1235"
            ][key] }
        })
    }
    
    @Test("测试环境变量读取8")
    func testEnvironmentDetect8() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_EXTRA_COUNT": "10"
            ][key] }
        })
    }
    
    @Test("测试环境变量读取9")
    func testEnvironmentDetect9() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE", driverKeys: [ExtraKey.self]) { key in [
            "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
            "WHOOSHING_API_SERVICE_NAME": "Testing Project",
            "WHOOSHING_API_SERVICE_PORT": "7777",
            "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
            "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "1",
            
            "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
            
            "WHOOSHING_API_SERVICE_EXTRA_COUNT": "0"
        ][key] }
        
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.extras.count == 0)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
