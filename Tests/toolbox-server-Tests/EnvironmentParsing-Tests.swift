import Testing
import Foundation
@testable import VaporTube

@Suite("环境变量解析测试集", .serialized)
struct EnvironmentParsingTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .enviromentParsing {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let TestToken = SendableSymmKey(key: .init(data: Data(base64Encoded: TestTokenStr)!))
    static let TestTokenStr = "9cCat+omad2WPRetG0VdqSdVhBPVz5kXJ2DssJtQshI="
    
    @Test("测试环境变量读取")
    func testEnvironmentDetect() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.name == "Testing Project")
        #expect(project.domain == "testing.whooshing.space")
        #expect(project.port == 7777)
        #expect(project.hostname == "localhost")
        
        #expect(project.log.directory.absoluteString == "/User/tester/logfile.log")
        
        #expect(project.dbServices.count == 2)
        #expect(project.managerUrl.absoluteString == "https://example.com")
        
        #expect(project.dbServices[0].id == .init(string: "service_1"))
        #expect(project.dbServices[0].host == "example.host.com")
        #expect(project.dbServices[0].port == 5432)
        #expect(project.dbServices[0].dbs.count == 1)
        #expect(project.dbServices[0].dbs[0].id.string == "service_1/woo_db")
        #expect(project.dbServices[0].dbs[0].parameter.user == "woo")
        #expect(project.dbServices[0].dbs[0].parameter.password == "woo_test")
        #expect(project.dbServices[0].dbs[0].parameter.fileStorageKey == Self.TestToken)
        
        #expect(project.dbServices[1].id == .init(string: "service_2"))
        #expect(project.dbServices[1].host == "example.host.com")
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
    }
    
    @Test("测试环境变量读取2")
    func testEnvironmentDetect2() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
            
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
            
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
            
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                
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
        ][key] }
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.name == "Testing Project")
        #expect(project.domain == "testing.whooshing.space")
        #expect(project.port == 7777)
        #expect(project.hostname == "localhost")
        #expect(project.dbServices.count == 2)
        #expect(project.managerUrl.absoluteString == "https://example.com")
        
        #expect(project.log.directory.absoluteString == "/User/tester/logfile.log")
        
        #expect(project.dbServices[0].id == .init(string: "service_1"))
        #expect(project.dbServices[0].host == "example.host.com")
        #expect(project.dbServices[0].port == 5432)
        #expect(project.dbServices[0].dbs.count == 1)
        #expect(project.dbServices[0].dbs[0].id.string == "service_1/woo_db")
        #expect(project.dbServices[0].dbs[0].parameter.user == "woo")
        #expect(project.dbServices[0].dbs[0].parameter.password == "woo_test")
        #expect(project.dbServices[0].dbs[0].parameter.fileStorageKey == nil)
        
        #expect(project.dbServices[1].id == .init(string: "service_2"))
        #expect(project.dbServices[1].host == "example.host.com")
        #expect(project.dbServices[1].port == 5433)
        #expect(project.dbServices[1].dbs.count == 2)
        #expect(project.dbServices[1].dbs[0].id.string == "service_2/woo_db_2")
        #expect(project.dbServices[1].dbs[0].parameter.user == "woo_2")
        #expect(project.dbServices[1].dbs[0].parameter.password == "woo_test_2")
        #expect(project.dbServices[1].dbs[0].parameter.fileStorageKey == Self.TestToken)
        #expect(project.dbServices[1].dbs[1].id.string == "service_2/woo_db_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.user == "woo_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.password == "woo_test_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.fileStorageKey == nil)
    }
    
    @Test("测试环境变量读取3")
    func testEnvironmentDetect3() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
            
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
            
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2",
                    
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_NAME": "woo_db_2_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_USER": "woo_2_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_PASSWORD": "woo_test_2_2",
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
        #expect(project.dbServices[0].dbs.count == 1)
        #expect(project.dbServices[0].dbs[0].id.string == "service_1/woo_db")
        #expect(project.dbServices[0].dbs[0].parameter.user == "woo")
        #expect(project.dbServices[0].dbs[0].parameter.password == "woo_test")
        #expect(project.dbServices[0].dbs[0].parameter.fileStorageKey == nil)
        
        #expect(project.dbServices[1].id == .init(string: "service_2"))
        #expect(project.dbServices[1].host == "example.host.com")
        #expect(project.dbServices[1].port == 5433)
        #expect(project.dbServices[1].dbs.count == 2)
        #expect(project.dbServices[1].dbs[0].id.string == "service_2/woo_db_2")
        #expect(project.dbServices[1].dbs[0].parameter.user == "woo_2")
        #expect(project.dbServices[1].dbs[0].parameter.password == "woo_test_2")
        #expect(project.dbServices[1].dbs[0].parameter.fileStorageKey == nil)
        #expect(project.dbServices[1].dbs[1].id.string == "service_2/woo_db_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.user == "woo_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.password == "woo_test_2_2")
        #expect(project.dbServices[1].dbs[1].parameter.fileStorageKey == nil)
    }
    
    @Test("测试环境变量读取4")
    func testEnvironmentDetect4() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                    
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2",
                        
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_NAME": "woo_db_2_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_USER": "woo_2_2",
            ][key] }
        })
    }
    
    @Test("测试环境变量读取5")
    func testEnvironmentDetect5() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                    
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2",
                        
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_NAME": "woo_db_2_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_PASSWORD": "woo_test_2_2"
            ][key] }
        })
    }
    
    @Test("测试环境变量读取6")
    func testEnvironmentDetect6() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
                    "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "1",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_NAME": "woo_db",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_USER": "woo",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_1_PASSWORD": "woo_test",
                    
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2"
            ][key] }
        })
    }
    
    @Test("测试环境变量读取7")
    func testEnvironmentDetect7() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
                    
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                    "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "2",
                
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_NAME": "woo_db_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_USER": "woo_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_1_PASSWORD": "woo_test_2",
                        
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_NAME": "woo_db_2_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_USER": "woo_2_2",
                        "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_2_PASSWORD": "woo_test_2_2",
            ][key] }
        })
    }
    
    @Test("测试环境变量读取8")
    func testEnvironmentDetect8() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
            
            "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "0",
        ][key] }
        #expect(project.id.uuidString == "C59C74DC-AF7F-4497-854B-75561D9FE995")
        #expect(project.name == "Testing Project")
        #expect(project.domain == "testing.whooshing.space")
        #expect(project.port == 7777)
        #expect(project.hostname == "localhost")
        #expect(project.dbServices.count == 0)
        #expect(project.managerUrl.absoluteString == "https://example.com")
        #expect(project.log.directory.absoluteString == "/User/tester/logfile.log")
    }
    
    @Test("测试环境变量读取9")
    func testEnvironmentDetect9() async throws {
        let project = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
    }
    
    @Test("测试环境变量读取10")
    func testEnvironmentDetect10() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_HOST": "example.host.com",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
            ][key] }
        })
    }
    
    @Test("测试环境变量读取11")
    func testEnvironmentDetect11() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
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
    
    @Test("测试环境变量读取12")
    func testEnvironmentDetect12() async throws {
        #expect(throws: Environment.Errcase.ErrType.self, performing: {
            let _ = try Environment.Config.parse(prefix: "WHOOSHING_API_SERVICE") { key in [
                "WHOOSHING_API_SERVICE_ID": "C59C74DC-AF7F-4497-854B-75561D9FE995",
                "WHOOSHING_API_SERVICE_NAME": "Testing Project",
                "WHOOSHING_API_SERVICE_PORT": "7777",
                "WHOOSHING_API_SERVICE_MANAGER_URL": "https://example.com",
                "WHOOSHING_API_SERVICE_HOSTNAME": "localhost",
                "WHOOSHING_API_SERVICE_DB_SERVICES_COUNT": "2",
                
                "WHOOSHING_API_SERVICE_LOG_DIRECTORY": "/User/tester/logfile.log",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_NAME": "service_1",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_PORT": "5432",
                "WHOOSHING_API_SERVICE_DB_SERVICES_1_DBS_COUNT": "0",
                
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_NAME": "service_2",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_PORT": "5433",
                "WHOOSHING_API_SERVICE_DB_SERVICES_2_DBS_COUNT": "0",
            ][key] }
        })
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}

extension String: @retroactive Error {}
