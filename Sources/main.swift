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

// Create a group of commands: train and render

let group = Group { group in
    
    group.command(
        "train",
        Argument("map-width", description: "Width of the SOM", validator: Int.init(validatePositive: )),
        Argument("map-height", description: "Height of the SOM", validator: Int.init(validatePositive: )),
        Argument("epochs", description: "Number of epochs to train", validator: Int.init(validatePositive: )),
        Argument("dataset", description: "Path to the dataset file with which the map should be trained. The file must be in the format \"id1, feature1, ...\\nid2,...\"", validator: String.init(validateExisting: )),
        Argument<String>("o", description: "Save path for the self organizing map"),
        Option("nscale", 1, flag: nil, description: "Scale of neighbourhood", validator: Float.init(validatePositive: )),
        description: "Train a self organizing map on a given dataset"
    ) { mapWidth, mapHeight, epochs, movieTagsFilePath, mapFilePath, neighbourhoodScale in
        
        let movieTagsURL = URL(fileURLWithPath: movieTagsFilePath)
        let mapURL = URL(fileURLWithPath: mapFilePath)
        
        // Loading data
        
        print("Parsing movie tags...")
        let movieVectors = try GenomeParser.parseMovieVectors(at: movieTagsURL)
        print("Done. Beginning training...")
        
        // Creating and training map
        
        let map = SelfOrganizingMap(mapWidth, mapHeight, outputSize: movieVectors.first?.1.count ?? 0, distanceFunction: hexagonDistance(from: to: ))
        
        for epoch in Progress(0 ..< epochs)
        {
            map.update(with: movieVectors.random().1, totalIterations: epochs * 4 / 5, currentIteration: epoch, neighbourhoodScale: neighbourhoodScale)
        }
        
        // Saving map
        try map.write(to: mapURL)
        
    } // End command train
    
    group.command(
        "render",
        Argument("map", description: "Path to the self organizing map", validator: String.init(validateExisting: )),
        Argument("tags", description: "Path to a CSV file containing names for the features of the dataset", validator: String.init(validateExisting: )),
        Argument("dataset", description: "Path to the dataset file", validator: String.init(validateExisting: )),
        Argument<String>("o", description: "Save path for the rendered map"),
        description: "Renders the U-matrix, component planes and distribution of values from a dataset of a trained SOM"
    ) { mapFilePath, tagsFilePath, movieTagsFilePath, outputFilePath in
        
        let tagsURL = URL(fileURLWithPath: tagsFilePath)
        let mapURL = URL(fileURLWithPath: mapFilePath)
        let movieTagsURL = URL(fileURLWithPath: movieTagsFilePath)
        let saveURL = URL(fileURLWithPath: outputFilePath)
        
        // Loading data
        
        print("Parsing map...")
        let map = try SelfOrganizingMap(contentsOf: mapURL)
        
        print("Parsing tags...")
        let tags = try GenomeParser.parseTags(at: tagsURL)
        
        print("Parsing movie tags...")
        let movieTags = try GenomeParser.parseMovieVectors(at: movieTagsURL)
        
        // Setting up render contexts
        print("Rendering...")
        var renderer = SOMUMatrixRenderer(map: map, mode: .distance)
        renderer.drawsScale = true
        
        guard let context = CGContext(saveURL as CFURL, mediaBox: [CGRect(x: 0, y: 0, width: 620, height: 600)], nil) else
        {
            fatalError("Could not render image. Context could not be created.")
        }
        
        // Render first page: U-Matrix
        context.beginPDFPage(nil)
        context.translateBy(x: 10, y: 10)
        renderer.title = "Inverse Map Density"
        renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
        context.endPDFPage()
        
        // Render Component Planes
        for i in Progress(0 ..< tags.count)
        {
            context.beginPDFPage(nil)
            context.translateBy(x: 10, y: 10)
            renderer.title = tags[i + 1] ?? "Unknown Tag"
            renderer.viewMode = .feature(index: i)
            renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
            context.endPDFPage()
        }
        
        // Render Dataset Density
        context.beginPDFPage(nil)
        context.translateBy(x: 10, y: 10)
        renderer.title = "Log Dataset Density"
        renderer.viewMode = .density(dataset: movieTags.map{$0.1})
        renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
        context.endPDFPage()
        
        // Finish rendering
        context.flush()
        
    } // End command render
    
    group.command(
        "convert",
        Argument("scores", description: "Path to file containing dataset in the format \"id,featureID,featureValue\\n...\"", validator: String.init(validateExisting: )),
        Argument<String>("o", description: "Filepath to generated matrix file"),
        description: "Converts a 2d matrix from a 3 column CSV representation (id, featureID, value) to a matrix file"
    ) { scoresFilePath, outputFilePath in
        
        let scoresURL = URL(fileURLWithPath: scoresFilePath)
        let outputURL = URL(fileURLWithPath: outputFilePath)
        
        // Parse input CSV
        print("Parsing scores...")
        let scoreList = try GenomeParser.parseScores(at: scoresURL)
        
        print("Generating score matrix...")
        let scores = GenomeParser.generateGenomeScoreMatrix(from: scoreList)
        
        // Write output CSV
        print("Writing matrix...")
        try GenomeParser.write(scores.map{[$0.0] + $0.1}, to: outputURL)
        
    } // End command convert
	
	group.command(
		"similar-tags",
		Argument("map", description: "Path to the self organizing map", validator: String.init(validateExisting: )),
		Argument("tags", description: "Path to a CSV file containing names for the features of the dataset", validator: String.init(validateExisting: )),
		description: "Finds tags similar to a set of given tags."
	) { mapFilePath, tagsFilePath in
		let inputString = sequence(first: "", next: {_ in readLine()}).joined(separator: "\n")
		
		guard !inputString.isEmpty, let inputData = inputString.data(using: .utf8) else {
			print("""
			No input provided.
			Expected format:
			
			{
				"tags": [
					"one tag",
					"another tag"
					"..."
				],
				"method": "tag matching method",
				"threshold": maximum difference (optional),
				"count": number of objects to return (optional)
			}

			Matching methods:
			- enclosed: Matches tags for which hot areas are contained by hot areas of the input tags
			- similar: Matches tags by overall similarity
			""")
			exit(1)
		}
		
		let request: TagSimilarityRequest
		do {
			request = try JSONDecoder().decode(TagSimilarityRequest.self, from: inputData)
		} catch {
			print("""
			Invalid input provided (\(error))
			Expected format:
			
			{
				"tags": [
					"one tag",
					"another tag"
					"..."
				],
				"method": "tag matching method",
				"threshold": maximum difference (optional),
				"count": number of objects to return (optional)
			}

			Matching methods:
			- enclosed: Matches tags for which hot areas are contained by hot areas of the input tags
			- similar: Matches tags by overall similarity
			""")
			exit(1)
		}
		
		let tagsURL = URL(fileURLWithPath: tagsFilePath)
		let mapURL = URL(fileURLWithPath: mapFilePath)
		
		let engine = try TagSearchEngine(mapURL: mapURL, tagsURL: tagsURL)
		
		let response = engine.similarTags(for: request)
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		guard let responseString = try String(data: encoder.encode(response), encoding: .utf8) else {
			fatalError("Internal Error: Invalid Response.")
		}
		print(responseString)
	}
	
	group.command(
		"movies",
		Argument("map", description: "Path to the self organizing map", validator: String.init(validateExisting: )),
		Argument("tags", description: "Path to a CSV file containing names for the features of the dataset", validator: String.init(validateExisting: )),
		Argument("movie-names", description: "Path to a CSV file containing names of movies", validator: String.init(validateExisting: )),
		Argument("movie-vectors", description: "Path to the movie tag vector file", validator: String.init(validateExisting: )),
		description: "Finds movies which best match a list of tags"
	) { mapFilePath, tagsFilePath, movieNamesFilePath, movieVectorsFilePath in
		
		let inputString = sequence(first: "", next: {_ in readLine()}).joined(separator: "\n")
		
		guard !inputString.isEmpty, let inputData = inputString.data(using: .utf8) else {
			print("""
				No input provided.
				""")
			exit(1)
		}
		
		let request: MovieSearchRequest
		
		do {
			request = try JSONDecoder().decode(MovieSearchRequest.self, from: inputData)
		} catch {
			print("""
				Invalid input provided (\(error))
				""")
			exit(1)
		}
		
		
		let tagsURL = URL(fileURLWithPath: tagsFilePath)
		let mapURL = URL(fileURLWithPath: mapFilePath)
		let movieNamesURL = URL(fileURLWithPath: movieNamesFilePath)
		let movieVectorsURL = URL(fileURLWithPath: movieVectorsFilePath)
		
		let index = try MovieSearchIndex(mapURL: mapURL, tagsURL: tagsURL, movieNamesURL: movieNamesURL, movieVectorsURL: movieVectorsURL)
		let engine = MovieSearchEngine(index: index)
		let response = engine.findMovies(for: request)
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		
		guard let responseString = try String(data: encoder.encode(response), encoding: .utf8) else {
			fatalError("Internal Error: Invalid Response.")
		}
		
		print(responseString)
	}
	
	group.command(
		"server",
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
		}),
		description: "Runs a HTTP server which responds to JSON requests."
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
}

group.run()
