//
//  Search.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
//

import Foundation
import Accelerate
import Progress

struct MovieSearchIndex {
	var tags: [String: Int]
	var movies: [Int: [String]]
	var map: SelfOrganizingMap
	
	init(map: SelfOrganizingMap, movies: [String: Sample], tags: [String: Int]) {
		self.tags = tags
		let mapMovieIndices = movies.mapValues { (sample) -> Int in
			map.nodes.minIndex(by: Array<Any>.compareDistance(sample)) ?? 0
		}
		self.movies = Dictionary.init(grouping: mapMovieIndices, by: {$0.value}).mapValues { (element) -> [String] in
			element.map { movie -> String in
				movie.key
			}
		}
		self.map = map
	}
	
	init(mapURL: URL, tagsURL: URL, movieNamesURL: URL, movieVectorsURL: URL) throws {
		print("Parsing map...")
		let map = try SelfOrganizingMap(contentsOf: mapURL)
		
		print("Parsing tags...")
		let tags = try GenomeParser.parseTags(at: tagsURL)
		
		print("Parsing movies...")
		let movies = try GenomeParser.parseMovies(at: movieNamesURL)
		
		print("Parsing movie tags...")
		let movieVectors = try GenomeParser.parseMovieVectors(at: movieVectorsURL)
		
		print("Processing movies...")
		
		let namedMovieVectors = Progress(movieVectors).flatMap { (movie) -> (String, Sample)? in
			guard let movieName = movies[movie.0] else {
				return nil
			}
			return (movieName, movie.1)
		}
		let movieIndex = Dictionary(uniqueKeysWithValues: namedMovieVectors)
		
		let tagNames = tags.map({ (element) -> (String, Int) in
			let (key, value) = element
			return (value, key - 1)
		})
		
		self.init(map: map, movies: movieIndex, tags: Dictionary(uniqueKeysWithValues: tagNames))
	}
}

struct PriorizedTag: Codable {
	let tag: String
	let priority: Float
}

struct MovieSearchRequest: Codable {
	let tags: [PriorizedTag]
	let threshold: Float?
	let count: Int?
}

struct MovieSearchResponse: Codable {
	let request: MovieSearchRequest
	let movies: [String]
}

struct MovieSearchEngine {
	let index: MovieSearchIndex
	
	func findMovies(`for` request: MovieSearchRequest) -> MovieSearchResponse {
		let tags = request.tags
		let tagIndices = tags.flatMap { tag -> (tag: Int, priority: Float)? in
			guard let tagIndex = index.tags[tag.tag] else {
				return nil
			}
			return (tag: tagIndex, priority: tag.priority)
		}
		
		let nodeScores = tagIndices.reduce(Sample(repeating: 0, count: index.map.nodes.count)) { (partialScores, tag) -> Sample in
			let tagScores = self.index.map.nodes.map({ node -> Float in
				node[tag.tag] * tag.priority
			})
			var result = partialScores
			vDSP_vadd(partialScores, 1, tagScores, 1, &result, 1, UInt(result.count))
			return result
		}
		
		let filteredNodes: [(offset: Int, element: Float)]
		
		if let threshold = request.threshold {
			filteredNodes = nodeScores.enumerated().filter { (nodeScore) -> Bool in
				return nodeScore.element >= threshold
			}
		} else {
			filteredNodes = Array(nodeScores.enumerated())
		}
		
		let sortedNodes = filteredNodes.sorted { (first, second) -> Bool in
			first.element < second.element
		}.reversed()
		
		let results = sortedNodes.flatMap ({ (node) -> [String] in
			return index.movies[node.offset, default: []]
		})
		
		if let count = request.count {
			return MovieSearchResponse(request: request, movies: Array(results.prefix(count)))
		} else {
			return MovieSearchResponse(request: request, movies: results)
		}
	}
}
