//
//  Search.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
//

import Foundation
import Accelerate
import Progress

import SOMKit
import MovieLensTools

struct MovieSearchIndex {
	
	/// Genome Tag names and corresponding Tag IDs
	var tags: [String: Int]
	
	/// Movie IDs and corresponding movie names
	var movieNames: [Int: String]
	
	/// SOM Map indices and associated movies
	var mapMovieIndex: [Int: [Int]]
	
	/// A SOM which was previously trained on a dataset of tags on movies.
	var map: SelfOrganizingMap
	
	
	/// Creates a new movie search index
	/// which allows movies to be searched using their location on a SOM
	///
	/// - Parameters:
	///   - map: SOM of tag vectors for movies
	///   - movieVectors: Tag vectors for movies
	///   - tags: Tag names for tag IDs
	///   - movieNames: Names of movies
	init(map: SelfOrganizingMap, movieVectors: [Int: Sample], tags: [String: Int], movieNames: [Int: String]) {
		// Maps samples corresponding to movies to the index of the BMU of the map
		let movieMapIndices = movieVectors.mapValues { sample -> Int in
			map.nodes.minIndex(by: sample.compareDistance()) ?? 0
		}
		// Groups movies by the index of the BMU of each movie
		self.mapMovieIndex = Dictionary(grouping: movieMapIndices, by: {$0.value}).mapValues { groupedMovies -> [Int] in
			// Strip BMU index from values (as it's already stored as the key)
			groupedMovies.map { movie -> Int in
				movie.key
			}
		}
		self.tags = tags
		self.map = map
		self.movieNames = movieNames
	}
	
	init(mapURL: URL, tagsURL: URL, movieNamesURL: URL, movieVectorsURL: URL) throws {
		print("Parsing map...")
		let map = try SelfOrganizingMap(contentsOf: mapURL)
		
		print("Parsing tags...")
		let tags = try GenomeParser.parseTags(at: tagsURL)
		
		print("Parsing movies...")
		let movies = try GenomeParser.parseMovies(at: movieNamesURL)
		
		print("Parsing movie tags...")
		let movieIndex = try Dictionary(uniqueKeysWithValues: GenomeParser.parseMovieVectors(at: movieVectorsURL))
		
		let tagNames = tags.map({ (element) -> (String, Int) in
			let (key, value) = element
			return (value, key - 1)
		})
		
		self.init(map: map, movieVectors: movieIndex, tags: Dictionary(uniqueKeysWithValues: tagNames), movieNames: movies)
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
		let tagIndices = tags.flatMap { tag -> (index: Int, priority: Float)? in
			guard let tagIndex = index.tags[tag.tag] else {
				return nil
			}
			return (index: tagIndex, priority: tag.priority)
		}
		
		let nodeScores = tagIndices.reduce(Sample(repeating: 0, count: index.map.nodes.count)) { (partialScores, tag) -> Sample in
			let tagScores = self.index.map.nodes.map({ node -> Float in
				node[tag.index] * tag.priority
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
		
		let selectedMovies = sortedNodes.flatMap { (node) -> [Int] in
			index.mapMovieIndex[node.offset, default: []]
		}
		
		let selectedMovieNames = selectedMovies.flatMap { (movieID) -> String? in
			index.movieNames[movieID]
		}
		
		if let count = request.count {
			return MovieSearchResponse(request: request, movies: Array(selectedMovieNames.prefix(count)))
		} else {
			return MovieSearchResponse(request: request, movies: selectedMovieNames)
		}
	}
}
