//
//  Tagging.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
//

import Foundation

enum MatchingMethod: String, Codable {
	case enclosedTags = "enclosed"
	case similarTags = "similar"
}

struct TagSimilarityRequest: Codable {
	let tags: [String]
	let matchingMethod: MatchingMethod
	let threshold: Float?
	let count: Int?
	
	private enum CodingKeys: String, CodingKey {
		case tags
		case matchingMethod = "method"
		case threshold
		case count
	}
}

struct MatchedTag: Codable {
	let tag: String
	let score: Float
}

struct TagSimilarityResponse: Codable {
	let request: TagSimilarityRequest
	let matchedTags: [MatchedTag]
	
	init<C: Collection>(request: TagSimilarityRequest, matchedTags: C) where C.Element == MatchedTag {
		self.request = request
		self.matchedTags = Array(matchedTags)
	}
	
	private enum CodingKeys: String, CodingKey {
		case request
		case matchedTags = "matches"
	}
}

struct TagSearchEngine {
	var map: SelfOrganizingMap
	var tags: [String: Int]
	
	func similarTags(`for` request: TagSimilarityRequest) -> TagSimilarityResponse {
		let scoredTags = tags.map { (tag) -> MatchedTag in
			let (key, index) = tag
			
			let tagScore = request.tags.flatMap({ self.tags[$0] }).reduce(0, { (requestedTagAccumulatedScore, requestedTagIndex) -> Float in
				let componentScore = self.map.nodes.reduce(0, { (mapScore, node) -> Float in
					switch request.matchingMethod {
					case .enclosedTags:
						return mapScore + max(node[index] - node[requestedTagIndex], 0) * max(node[index] - node[requestedTagIndex], 0)
						
					case .similarTags:
						return mapScore + (node[index] - node[requestedTagIndex]) * (node[index] - node[requestedTagIndex])
					}
				})
				
				return sqrt(componentScore)
			})
			
			
			return MatchedTag(tag: key, score: tagScore)
		}
		
		let response = TagSimilarityResponse(
			request: request,
			matchedTags: scoredTags.sorted(by: {
				$0.score < $1.score
			})
			.filter({ (tag) -> Bool in
				if let threshold = request.threshold {
					return tag.score <= threshold
				} else {
					return true
				}
			})
			.prefix(request.count ?? Int.max)
		)
		
		return response
	}
}
