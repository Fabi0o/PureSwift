import Vapor
import NIO
import Foundation

/// Errors for this site
enum PureSwiftError: Error {
    case Database(String)
    case DataDecode(String)
}

func routes(_ app: Application) throws {
    /// Index (browse)
    app.get { req -> EventLoopFuture<View> in
        // Get all packages
        let file = try String(contentsOfFile: "Public/Data/packages.json", encoding: String.Encoding.utf8)
        let decoder = JSONDecoder()
        let packages: [Package] = try decoder.decode([Package].self, from: file.data(using: String.Encoding.utf8)!) 

        return req.view.render("index", ["packages": packages])
    }

    /// Categories overvies
    app.get("category", ":category") { req -> EventLoopFuture<View> in 
        return req.view.render("not_found")
    }
    
    /// Packages
    app.get("package", ":name") { req -> EventLoopFuture<View> in
        return try PackagePageController().getPage(req: req)
    }

    /// Search
    app.get("search") { req -> EventLoopFuture<View> in
        let results: [Package]
        do {
            let search = try req.query.decode(Search.self)
            results = try search.retrieveResults()
        } catch(let error) {
            results = [Package(title: "Error", authors: ["Something went wrong: \(error)"])]
        }
        return req.view.render("search", ["packages": results])
    }
    
    /*
    app.get("exec") { req -> String in
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "Sources/App/main")
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        try task.run()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)
        
        print("OUTPUT:", output)
        print("ERROR:", error)
        return "E"
    }
    */
}

/// Represents a search query
struct Search: Content {
    var query: String?
}

extension Search {
    /// Retrieve results from the query
    func retrieveResults() throws -> [Package] {
        // #7 
        let task = Process()
        #if os(macOS)
        task.executableURL = URL(fileURLWithPath: "Public/bin/jql_mac")
        #elseif os(Linux)
        task.executableURL = URL(fileURLWithPath: "Public/bin/jql_lin")
        #endif

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)

        print("STDERR:", error)
        print("STDOUT:", output)

        return [Package(title: "STDOUT", authors: [output]), Package(title: "STDERR", authors: [error])]
    }
}
