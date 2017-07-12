//
//  Search.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
//  Copyright (c) 2017 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

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
	
	// The IMDB ID and TMDB ID for a MovieLens ID
	var movieLinks: [Int: (String, String)]
	
	/// Creates a new movie search index
	/// which allows movies to be searched using their location on a SOM
	///
	/// - Parameters:
	///   - map: SOM of tag vectors for movies
	///   - movieVectors: Tag vectors for movies
	///   - tags: Tag names for tag IDs
	///   - movieNames: Names of movies
	init(map: SelfOrganizingMap, movieVectors: [Int: Sample], tags: [String: Int], movieNames: [Int: String], links: [Int: (String, String)]) {
		
		print("Mapping movies to map...")
		var bar = ProgressBar(count: movieVectors.count)
		
		// Maps samples corresponding to movies to the index of the BMU of the map
		let movieMapIndices = movieVectors.mapValues { sample -> Int in
			bar.next()
			return map.nodes.minIndex(by: sample.compareDistance()) ?? 0
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
		self.movieLinks = links
	}
	
	init(mapURL: URL, tagsURL: URL, movieNamesURL: URL, movieVectorsURL: URL, linksURL: URL) throws {
		print("Parsing map...")
		let map = try SelfOrganizingMap(contentsOf: mapURL)
		
		print("Parsing tags...")
		let tags = try GenomeParser.parseTags(at: tagsURL)
		
		print("Parsing movies...")
		let movies = try GenomeParser.parseMovies(at: movieNamesURL)
		
		print("Parsing movie tags...")
		let movieIndex = try Dictionary(uniqueKeysWithValues: GenomeParser.parseMovieVectors(at: movieVectorsURL))
		
		print("Parsing links...")
		let links = try GenomeParser.parseLinks(at: linksURL)
		
		let tagNames = tags.map({ (element) -> (String, Int) in
			let (key, value) = element
			return (value, key - 1)
		})
		
		self.init(map: map, movieVectors: movieIndex, tags: Dictionary(uniqueKeysWithValues: tagNames), movieNames: movies, links: links)
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

struct Movie: Codable {
	let id: Int
	let title: String
	let imdbID: String
	let tmdbID: String
	
	private enum CodingKeys: String, CodingKey {
		case id
		case title
		case imdbID = "imdb_id"
		case tmdbID = "tmdb_id"
	}
}

struct MovieSearchResponse: Codable {
	let request: MovieSearchRequest
	let movies: [Movie]
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
		
		let selectedMovieIDs = sortedNodes.flatMap { node -> [Int] in
			index.mapMovieIndex[node.offset, default: []]
		}
		
		let selectedMovies = selectedMovieIDs.flatMap { movieID -> Movie? in
			guard let (imdbID, tmdbID) = index.movieLinks[movieID] else {
				return nil
			}
			guard let title = index.movieNames[movieID] else {
				return nil
			}
			return Movie(id: movieID, title: title, imdbID: imdbID, tmdbID: tmdbID)
		}
		
		if let count = request.count {
			return MovieSearchResponse(request: request, movies: Array(selectedMovies.prefix(count)))
		} else {
			return MovieSearchResponse(request: request, movies: selectedMovies)
		}
	}
}
