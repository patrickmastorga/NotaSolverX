//
//  APIFunctions.swift
//  Sidebar
//
//  Created by Maks Kushniryk on 10/15/23.
//

import Foundation
import SwiftUI

/// Errors that can occur during the complete process for parsing, solving, and displaying the unsolved problems
enum CustomError: Error {
    case MathpixURLError
    case MathpixResponseDecodingError
    case WolframURLError
    case WolframInputEncodingError
    case WolframResponseDecodingError
    case UnsupportedEquationError
    case dataProcessingError
}


/// Different operations supported by the program for Wolfram Alpha requests
enum WolframOperation {
    case Solve
}


/// Takes some stroke from the UI and converts it into json format
/// - Parameter strokeData: Data representing the stroke from the UI
/// - Returns: The json format required by the Mathpix API
func convertStrokeToJsonData (strokeData: [[CGPoint]]) -> Data? {
    var x: [[Int]] = []
    var y: [[Int]] = []
    
    for path in strokeData {
        var xData: [Int] = []
        var yData: [Int] = []
        for point in path {
            xData.append(Int(exactly: point.x.rounded())!)
            yData.append(Int(exactly: point.y.rounded())!)
        }
        x.append(xData)
        y.append(yData)
    }
    
    let json: [String: Any] = [
        "strokes": [
            "strokes": [
              "x": x,
              "y": y
            ]
          ]
        ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        return nil
    }
}


/// Get the text representation of the formula from Mathpix API
/// - Parameter strokeJsonString: JSON reprentation of the stroke
/// - Parameter completion: completion handler to process data
func fetchDataFromMathpix (strokeData: [[CGPoint]], completion: @escaping ((Result<[String: Any], Error>) -> Void)) {
    let appID = "notasolverx_12721e_64cb20"
    let appKey = "e8070a38f235821bbec6507a6a5841e444d287e30640f0ab37935fdbdc647c33" // FIGURE OUT CLIENT SIDE TOKENS

    // Convert stroke data to json string
    guard let strokeJsonData = convertStrokeToJsonData(strokeData: strokeData) else {
        completion(.failure(CustomError.MathpixResponseDecodingError))
        return
    }
    
    // Create url object
    guard let url = URL(string: "https://api.mathpix.com/v3/strokes") else {
        completion(.failure(CustomError.MathpixURLError))
        return
    }

    // Build request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(appID, forHTTPHeaderField: "app_id")
    request.setValue(appKey, forHTTPHeaderField: "app_key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = strokeJsonData

    // Make request
    print("Making request to \(url)")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, let response = response as? HTTPURLResponse else {
            completion(.failure(error!))
            return
        }

        print("Response status code: \(response.statusCode)")

        // Parse response as json
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                completion(.success(jsonResponse))
            } else {
                completion(.failure(CustomError.MathpixResponseDecodingError))
                return
            }
        } catch {
            // JSON serialization threw an error
            completion(.failure(error))
            return
        }
        
    }
    task.resume()
}


/// Processes the data from the Mathpix API and prepares the Wolfram Alpha API request
/// - Parameter data: data to be processed
/// - Returns: Result either containing data and WolframOperation or Error
func convertMathpixResponseToInputString (data: [String: Any]) throws -> String {
    guard let latex = data["latex_styled"] as? String else {
        throw CustomError.MathpixResponseDecodingError
    }
    return latex
}


/// Gets the solution and all of the steps from Wolfram Aplha API
/// - Parameter Data:
/// - Parameter completion: completion handler to process data
func fetchDataFromWolfram (data: [String: Any], completion: @escaping ((Result<[String: Any], Error>) -> Void)) {
    let appID = "JG4TGL-G86953GKY8"

    // Convert data from Mathpix into wolfram input
    let wolframInputString: String?
    do {
        wolframInputString = try convertMathpixResponseToInputString(data: data)
    } catch {
        completion(.failure(error))
        return
    }


    // Create base url object
    guard var baseURL = URLComponents(string: "https://api.wolframalpha.com/v2/query") else {
        completion(.failure(CustomError.WolframURLError))
        return
    }

    // Append URL query items to create final URL
    baseURL.queryItems  = [
        URLQueryItem(name: "appid", value: appID),
        URLQueryItem(name: "input", value: wolframInputString),
        URLQueryItem(name: "podstate", value: "Step-by-step solution"),
        URLQueryItem(name: "format", value: "image"),
        URLQueryItem(name: "mag", value: "2.0"),
        URLQueryItem(name: "output", value: "json")
    ]
    
    let url = baseURL.url!

    // Make request
    print("Making request to \(url)")
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, let response = response as? HTTPURLResponse else {
            completion(.failure(error!))
            return
        }

        print("Response status code: \(response.statusCode)")

        // Parse response as json
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                completion(.success(jsonResponse))
            } else {
                completion(.failure(CustomError.WolframResponseDecodingError))
                return
            }
        } catch {
            // JSON serialization threw an error
            completion(.failure(error))
            return
        }
    }
    task.resume()
}
