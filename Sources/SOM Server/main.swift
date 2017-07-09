//
//  main.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 29.04.17.
//    Copyright (c) 2017 Palle Klewitz
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.


import Foundation
import CoreGraphics
import Progress
import Commander

import Kitura
import KituraNet
import KituraCORS

import SOMKit
import MovieLensTools

extension RouterResponse {
	@discardableResult
	func send<Value: Encodable>(_ value: Value, encoder: JSONEncoder = JSONEncoder()) throws -> RouterResponse {
		let encoded = try encoder.encode(value)
		self.send(data: encoded)
		
		return self
	}
}

// Create a group of commands: train and render

let main = command(
	Argument("map", description: "Path to the self organizing map", validator: String.init(validateExisting: )),
	Argument("tags", description: "Path to a CSV file containing names for the features of the dataset", validator: String.init(validateExisting: )),
	Argument("movie-names", description: "Path to a CSV file containing names of movies", validator: String.init(validateExisting: )),
	Argument("movie-vectors", description: "Path to the movie tag vector file", validator: String.init(validateExisting: )),
	Option("port", 8000, flag: "p", description: "The TCP port on which the server should run", validator: { port in
		if port <= 0 {
			throw ValidationError(description: "Port must be greater than 0.")
		} else {
			return port
		}
	})
) { mapFilePath, tagsFilePath, movieNamesFilePath, movieVectorsFilePath, port in
	let tagsURL = URL(fileURLWithPath: tagsFilePath)
	let mapURL = URL(fileURLWithPath: mapFilePath)
	let movieNamesURL = URL(fileURLWithPath: movieNamesFilePath)
	let movieVectorsURL = URL(fileURLWithPath: movieVectorsFilePath)
	
	let movieSearchIndex = try MovieSearchIndex(mapURL: mapURL, tagsURL: tagsURL, movieNamesURL: movieNamesURL, movieVectorsURL: movieVectorsURL)
	let movieSearchEngine = MovieSearchEngine(index: movieSearchIndex)
	
	let tagSearchEngine = try TagSearchEngine(mapURL: mapURL, tagsURL: tagsURL)
	
	print("Running Server...")
	
	let router = Router()
	router.all(
		middleware: CORS(
			options: KituraCORS.Options(
				allowedOrigin: .all,
				credentials: false,
				methods: ["GET"],
				allowedHeaders: nil,
				maxAge: nil,
				exposedHeaders: nil,
				preflightContinue: true
			)
		)
	)
	
	router.get("/movies/:query") { request, response, next in
		defer { next() }
		
		guard let queryString = request.parameters["query"], let queryData = queryString.data(using: .utf8) else {
			response.statusCode = HTTPStatusCode.badRequest
			response.send("Error 400: No Query.")
			return
		}
		
		guard let query = try? JSONDecoder().decode(MovieSearchRequest.self, from: queryData) else {
			response.statusCode = HTTPStatusCode.badRequest
			response.send("Error 400: Invalid Query.")
			return
		}
		
		let result = movieSearchEngine.findMovies(for: query)
		try response.send(result)
	}
	
	router.get("/tags/:query") { request, response, next in
		defer { next() }
		
		guard let queryString = request.parameters["query"], let queryData = queryString.data(using: .utf8) else {
			response.statusCode = HTTPStatusCode.badRequest
			response.send("Error 400: No Query.")
			return
		}
		
		guard let query = try? JSONDecoder().decode(TagSimilarityRequest.self, from: queryData) else {
			response.statusCode = HTTPStatusCode.badRequest
			response.send("Error 400: Invalid Query.")
			return
		}
		
		let result = tagSearchEngine.similarTags(for: query)
		try response.send(result)
	}
	
	router.get("/static", middleware: StaticFileServer())
	
	router.get("/") { request, response, next in
		next()
	}
	
	Kitura.addHTTPServer(onPort: port, with: router)
	Kitura.run()
}

main.run()
