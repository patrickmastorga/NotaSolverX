import Foundation

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


func StrokeFinder () {
    
}


/// Takes some stroke from the UI and converts it into json format
/// - Parameter strokeData: Data representing the stroke from the UI
/// - Returns: The json format required by the Mathpix API
func convertStrokeToJsonString (strokeData: Stroke) -> String throws {
    var json: [String: Any] = []

    return JSONSerialization.
}


/// Get the text representation of the formula from Mathpix API
/// - Parameter strokeJsonString: JSON reprentation of the stroke
/// - Parameter completion: completion handler to process data
func fetchDataFromMathpix (strokeData: Stroke, completion: @escaping ((Result<[String: Any], Error>) -> Void)) {
    let appID = "notasolverx_12721e_64cb20"
    let appKey = "e8070a38f235821bbec6507a6a5841e444d287e30640f0ab37935fdbdc647c33" // FIGURE OUT CLIENT SIDE TOKENS

    // Convert stroke data to json string
    let strokeJsonString: String?
    do {
        strokeJsonString = try convertStrokeToJsonString(strokeData)
    } catch {
        completion(.failure(error))
    }

    // Create url object
    guard let url = URL(string: "https://api.mathpix.com/v3/strokes") else {
        completion(.failure(CustomError.MathpixURLError))
    }

    // Build request
    let request = URLRequest(url: URL(string: urlString)!)
    request.httpMethod = "POST"
    request.setValue(appID, forHTTPHeaderField: "app_id")
    request.setValue(appKey, forHTTPHeaderField: "app_key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = strokeJsonString.data(using: .utf8)

    // Make request
    print("Making request to \(urlString)")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in 
        guard let data = data, let response = response as? HTTPURLResponse else {
            completion(.failure(error))
        }

        print("Response status code: \(response.statusCode)")

        // Parse response as json
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                completionHandler(.success(jsonResponse))
            } else {
                completionHandler(.failure(CustomError.MathpixResponseDecodingError))
            }
        } catch {
            // JSON serialization threw an error
            completionHandler(.failure(error))
        }
        
    }
    task.resume()
}


/// Processes the data from the Mathpix API and prepares the Wolfram Alpha API request
/// - Parameter data: data to be processed
/// - Returns: Result either containing data and WolframOperation or Error
func convertMathpixResponseToInputString (data: [String: Any]) -> String throws {
    // IF DATA CAN BE PROCESSED INTO A VALID REQUEST
        // return PROCESSED_DATA
    // ELSE
        // throw CustomError.UnsupportedEquationError
}


/// Gets the solution and all of the steps from Wolfram Aplha API
/// - Parameter Data: 
/// - Parameter completion: completion handler to process data
func fetchDataFromWolfram (data: [String: Any], completion: @escaping ((Result<[String: Any], Error>) -> Void)) {
    let appID = "JG4TGL-G86953GKY8"

    // Convert data from Mathpix into wolfram input
    let wolframInputString: String?
    do {
        wolframInputString = try convertMathpixResponseToInputString(data)
    } catch {
        completion(.failure(error))
    }


    // URL encode wolfram input
    guard let wolframEncodedInput = wolframInputString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        completion(.failure(CustomError.WolframInputEncodingError))
        return
    }

    // Create base url object
    guard let baseURL = URL(string: "http://api.wolframalpha.com/v2/query") else {
        completion(.failure(CustomError.WolframURLError))
        return
    }

    // Append URL query items to create final URL
    let url = baseURL.appending(queryItems: [
        URLQueryItem(name: "appid", value: appID),
        URLQueryItem(name: "input", value: wolframEncodedInput),
        URLQueryItem(name: "podstate", value: "Step-by-step%20solution"),
        //URLQueryItem(name: "format", value: "image") If we REALLY want to cheat
        URLQueryItem(name: "output", value: "json")
    ])

    // Make request
    print("Making request to \(url)")
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, let response = response as? HTTPURLResponse else {
            completionHandler(.failure(error))
            return
        }

        print("Response status code: \(response.statusCode)")

        // Parse response as json
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                completionHandler(.success(jsonResponse))
            } else {
                completionHandler(.failure(CustomError.WolframResponseDecodingError))
            }
        } catch {
            // JSON serialization threw an error
            completionHandler(.failure(error))
        }
    }
    task.resume()
}


/// Processes the solution to be displayed step by step
/// - Parameter data: data to be processed
/// - Returns: data to be displayed about equation
/// - Throws: Error if data from wolfram is invalid or wolfram couldnt get the answer
func processDataForDisplay (data: String) -> DisplayData throws {
    // Im thinking we somehow generate the ui components in this function
}


/// Handles the entire process of converting the image into text, sending the text to wolfram, and creating the data to update the screen.
/// - Parameter src: url of the image to be converted into a result
/// - Parameter completion: completion handler to process display data or errors during the process
func completeProcessForWebApp (stroke: Stroke) {
    // Update UI to show request initialization
    updateUIforRequest()

    // Fetch from MathPix
    fetchDataFromMathpix(strokeData: stroke) { mathpixResult in
        // Update UI to show text response from Mathix
        updateUIforMathpixResult(mathpixResult)
        
        switch mathpixResult {
            case .success(let mathpixData):
                // Send Mathpix data to Wolfram Alpha
                fetchDataFromWolfram(data: mathpixData) { wolframResult in
                    // Update UI to show reponse from Wolfram Alpha
                    updateUIforWolframAlphaResult(wolframResult)

                    if case .failure(let error) {
                        print("Wolfram error: \(error)")
                        return
                    }
                }
            case .failure(let error):
                print("Mathpix error: \(error)")
                return
        }
    }
}


// Usage example
let exampleString = "poop"
completeProcessForWebApp (src: exampleString)
