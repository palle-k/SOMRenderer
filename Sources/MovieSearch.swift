//
//  Search.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
//

import Foundation

struct MovieSearchIndex {
	var map: SelfOrganizingMap
	var movies: [String: [Int]]
	var tags: [String: Int]
	
	init(map: SelfOrganizingMap, movies: [String: Sample], tags: [String: Int]) {
		self.map = map
		self.tags = tags
		self.movies = movies.mapValues { (sample) -> Int in
			nodes.minIndex(by: Array<Any>.compareDistance(sample)) ?? 0
		}
	}
}

struct PriorizedTag: Codable {
	let tag: String
	let priority: Double
}

struct MovieSearchEngine {
	let index: MovieSearchIndex
	
	func findMovies(`for` tags: (String, Float)) {
		
	}
}
