import SwiftUI
import PencilKit

/// Represents a color for the Pencil Kit pen
struct ColorInfo: Identifiable, Hashable {
    let id = UUID()
    let color: Color
    let uiColor: UIColor
}

struct ContentView: View {
    /// Pencil Kit Drawing canvas
    @State var canvas = PKCanvasView()
    /// Which Pencil Kit tool is currently selected
    @State var currentTool: PKTool = PKInkingTool(.pen, color: .black, width: 10)
    /// Which color is currently selected for the Pencil Kit pen input
    @State private var selectedColor: ColorInfo = ColorInfo(color: .black, uiColor: .black)
    /// String representation of the current color
    @State var selection: String = "black"

    /// Represents current position of snipping rectangle
    @State private var currentPosition: CGSize = CGSize(width: 200, height: 450)
    /// Represents current size of snipping rectangle
    @State private var newSize: CGSize = CGSize(width: 400, height: 150)
    /// Represents whether or not the snipping rectangle is visible
    @State private var showRectangle: Bool = false
    
    /// Color options for the Pencil Kit pen tool
    let colors: [ColorInfo] = [
           ColorInfo(color: .black, uiColor: .black),
           ColorInfo(color: .red, uiColor: .red),
           ColorInfo(color: .green, uiColor: .green),
           ColorInfo(color: .blue, uiColor: .blue)
       ]

    /// Array containing EquationInfos for all of the solved inputs
    @State private var equationInfos: [EquationInfo] = []
    
    var body: some View {
        // Main ZStack containing every layer of components on the screen (drawing kit -> snipping rectangle -> buttons + output)
        ZStack {
            // Add the Pencil Kit drawing canvas to the screen
            DrawingView(canvas: $canvas)
            
            // Display the snipping rectangle if user has enabled it
            if (showRectangle) {
                ResizableRectangle(currentPosition: $currentPosition, newSize: $newSize)
                    .border(Color.white, width: 1)
            }
            
            // Main VStack for all of the UI components (buttons and output)
            VStack {
                // HStack spanning the top majority of the screen
                HStack {
                    Spacer()

                    // Vstack for displaying all of the outputs
                    VStack {
                        // Display every equation box on screen
                        ScrollView {
                            ForEach(equationInfos, id: \.self) { info in
                                EquationBox(info)
                            }
                            
                            Spacer()
                        }
                    }
                    .background(Color.white)
                    .frame(width: 300)
                    .border(Color.black, width: 2)
                }
                
                // HStack on bottom of screen for UI inputs
                HStack {
                    // Color selection menu
                    Menu {
                        // Honestly don't really know what this does
                        ForEach(colors) { colorInfo in
                            Button(action: {
                                self.selectedColor = colorInfo
                                currentTool = PKInkingTool(.pen, color: colorInfo.uiColor, width: 10)
                                canvas.tool = currentTool
                            }) {
                                HStack {
                                    Circle()
                                        .fill(colorInfo.color)
                                        .frame(width: 30, height: 30)
                                    Text(colorInfo.color.description) // This text might not be necessary, bt it helps ensure the menu items are not blank. You might need to adjust it depending on how your 'ColorInfo' struct is set up.
                                        .foregroundColor(.black) // Or another suitable color that makes the text visible on your menu.
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(selectedColor.color)
                                .frame(width: 35, height: 35)
                        }
                    }
                    .padding()
    
                    // Button for selecting pen input
                    Button("🖊") {
                        currentTool = PKInkingTool(.pen, color: .black, width: 10)
                        canvas.tool = currentTool
                    }
                    .padding()
                    .font(.system(size: 35))
                    
                    // Button for selecting eraser input
                    Button("❌") {
                        currentTool = PKEraserTool(.vector) // Use vector eraser type
                        canvas.tool = currentTool
                        }
                    .padding()
                    .font(.system(size: 35))
                    
                    // Button for toggling snipping rectangle
                    Button("🔲") {
                        showRectangle.toggle()
                    }
                    .padding()
                    .font(.system(size: 35))
                    
                    // Button for submitting input
                    if showRectangle {
                        Button("✅") {
                            submit()
                            showRectangle = false
                        }
                        .padding()
                        .font(.system(size:35))
                    }
                }
            }
        }
    }
    

    /// Returns an array of paths from the Pencil Kit drawing canvas
    /// Only paths within a specified rectangle are included
    /// Paths are represented as an array of CGPoints
    /// - Parameter rect: the CGRect you want paths within
    /// - Returns: Array of paths within the rectangle
    func getStrokePointsInRect(rect: CGRect) -> [[CGPoint]] {
        var paths: [[CGPoint]] = []
        
        // Only consider paths whose bounding box intersect the rectangle for efficiency
        let intersectingStrokes = canvas.drawing.strokes.filter { stroke in
            stroke.renderBounds.intersects(rect)
        }
        
        for stroke in intersectingStrokes {
            // Stores current path in search
            var path: [CGPoint] = []
            var pathLength = 0;
            
            for point in stroke.path {
                // Check if every point is within specified rectangle
                if (rect.contains(point.location)) {
                    // Add points within rectangle to current path
                    path.append(point.location)
                    pathLength += 1
                } else {
                    // When the stroke exits the rectangle, add current path to paths
                    if pathLength > 1 {
                        paths.append(path)
                    }
                    path = []
                    pathLength = 0
                }
            }
            
            // Add current path is stroke ended within the rectangle
            if pathLength > 1 {
                paths.append(path)
            }
        }

        return paths
    }
    
    /// Create new output window for the input and reflect that the request has been made
    func updateUIForRequest() {
        print("request made")
    }

    
    /// Takes the response from wolfram alpha API and converts it into a array of "pods"
    /// - Returns result containing the list of pods
    func getPodsFromWolframResponse(result: Result<[String, Any], Error>) -> Result<[WolframPod], Error> {
        switch result {
        case .success(let data):
            // Checking if wolfram response is a success
            guard let success = data["success"] as? Bool else {
                return .failure(CustomError.WolframResponseDecodingError)
            }
            guard let error = data["error"] as? Bool else {
                return .failure(CustomError.WolframResponseDecodingError)
            }
            if (!success || error) {
                return .failure(CustomError.WolframResponseError)
            }

            // Print out input string
            guard let inputstring = data["inputstring"] as? String else {
                return .failure(CustomError.WolframResponseDecodingError)
            }
            print("Wolfram input string (in response):", inputstring)

            // Array for storing parsed pods
            let parsed: [WolframPod] = []

            let ids: [String] = []

            // Get the pods from the response
            guard let pods = data["pods"] as? [[String: Any]] else {
                return .failure(CustomError.WolframResponseDecodingError)
            }
            for pod in pods {
                let podinfo = [String: String]

                // Get neccessary info about the pod
                guard let podTitle = pod["title"] as? String else {
                    return .failure(CustomError.WolframResponseDecodingError)
                }
                guard let id = pod["id"] as? String else {
                    return .failure(CustomError.WolframResponseDecodingError)
                }

                ids.append(id)

                // Get the subpods from the pod
                guard let subpods = pod["subpods"] as? [[String: Any]] else {
                    return .failure(CustomError.WolframResponseDecodingError)
                }
                for subpods in subpods {
                    guard let subpodTitle = subpod["title"] as? String else {
                        return .failure(CustomError.WolframResponseDecodingError)
                    }
                    guard let img = subpod["img"] as? [String, Any] else {
                        return .failure(CustomError.WolframResponseDecodingError)
                    }
                    guard let src = img["src"] as? String else {
                        return .failure(CustomError.WolframResponseDecodingError)
                    }
                    
                    // Create parsed pod object
                    let title = subpodTitle.isEmpty ? podTitle : "\(podTitle): \(subpodTitle)"
                    parsed.append(WolframPod(title: title, imgSrc: img))
                }
            }

            // Check if response contained the pods expected
            if (parsed.count == 0 || !ids.contains("Input") || !ids.contain("Result")) {
                return .failure(CustomError.WolframResponseDecodingError)
            }

            return parsed
        case .failure:
            return result
        }
    }

    
    /// Handles the entire process of converting the image into text, sending the text to wolfram, and creating the data to update the screen.
    /// - Parameter src: url of the image to be converted into a result
    /// - Parameter completion: completion handler to process display data or errors during the process
    func processStrokes(strokes: [[CGPoint]], number: Int) {        
        // Fetch from MathPix
        fetchDataFromMathpix(strokeData: strokes) { mathpixResult in
            // Update UI to show text response from Mathix
            equationInfos[equationInfos.count - number] = EquationInfo(status: 1, mathpix: mathpixResult)
            
            switch mathpixResult {
            case .success(let mathpixData):
                // Print out mathpix output
                print("Mathpix output string \(mathpixData)")

                // Send Mathpix data to Wolfram Alpha
                fetchDataFromWolfram(data: mathpixData) { wolframResult in
                    // Update UI to show reponse from Wolfram Alpha
                    equationInfos[equationInfos.count - number] = EquationInfo(status: 2, mathpix: mathpixResult, wolfram: getPodsFromWolframResponse(wolframResult))
                    
                    if case .failure(let error) = wolframResult {
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

    
    /// Gets the rectangle covered by the snipping rectangle at the current moment
    /// - Returns: the CGRect representing where the snipping rectagle covers
    func getBoundingRect() -> CGRect {
        return CGRect(x: currentPosition.width,
                      y: currentPosition.height,
                      width: newSize.width,
                      height: newSize.height)
    }


    func submit() {
        let newInfo = EquationInfo()
        equationInfos.insert(newInfo, at: 0)
        processStrokes(strokes: getStrokePointsInRect(), number: equationInfos.count)
    }
}


/// Setup required for the creating the Pencil Kit drawing canvas
struct DrawingView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) { }
}


/// View for snipping rectangle
/// Consists of a transparent rectangle with a small circle in the corner to allow for resizing
struct ResizableRectangle: View {
    @Binding var currentPosition: CGSize
    @Binding var newSize: CGSize
    @GestureState private var dragState: CGSize = .zero
    @State private var offsetForResize: CGSize = .zero
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: newSize.width, height: newSize.height)
                .position(x: currentPosition.width + dragState.width + newSize.width / 2,
                          y: currentPosition.height + dragState.height + newSize.height / 2)
                .gesture(
                    DragGesture()
                        .updating($dragState) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            currentPosition.width += value.translation.width
                            currentPosition.height += value.translation.height
                        }
                ).foregroundColor(Color.blue.opacity(0.3))
            
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(Color.gray.opacity(0.5))
                .position(x: currentPosition.width + dragState.width + newSize.width,
                          y: currentPosition.height + dragState.height + newSize.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let deltaWidth = value.translation.width - self.offsetForResize.width
                            let deltaHeight = value.translation.height - self.offsetForResize.height
                            self.newSize = CGSize(width: self.newSize.width + deltaWidth, height: self.newSize.height + deltaHeight)
                            self.offsetForResize = value.translation
                        }
                        .onEnded { _ in
                            self.offsetForResize = .zero
                        }
                )
        }
    }
}


/// Represents a pod returned from Wolfram Alpha
struct WolframPod: Hashable {
    public let title: String
    public let imgSrc: String
    public static let ERROR: WolframPod = WolframPod(title: "ERROR", imgSrc: "https://www.computerhope.com/jargon/e/error.png")
}


struct EquationInfo: Hashable {
    public let status: Int = 0
    public let mathpix: Result<String, Error> = .failure(CustomError.MathpixDisplayInitializationError)
    public let wolfram: Result<[WolframPod], Error> = .failure(CustomError.WolframDisplayInitializationError)
}


/// View for containing information about a input
/// Includes Mathpix Output and all of the pods returned from wolfram aplha
struct EquationBox: View, Hashable {
    /// Data associated with this particular EquationBox
    @state private var info: EquationInfo
    
    /// Whether or not the equation box is expanded
    @State private var isExpanded = false
    
    var body: some View {
        // Main VStack for storing all information in box
        VStack() {
            // Top portion for displaying latex text of input
            HStack() {
                Spacer()
                
                // Show loading symbol when Mathpix result is loading
                if (info.status == 0) {
                    Text("Loading data from Mathpix...")
                        .padding()

                    ProgressView()
                } 
                // Otherwise display Mathpix latex text
                else {
                    switch info.mathpix {
                        case .success(let latex):
                            Text(latex)
                                .padding()
                        case .failure(let error):
                            Text(error)
                                .padding()
                    }
                    
                }
                
                Spacer()
            }
            
            if (isExpanded && info.status != 0) {
                // Show loading symbol when Wolfram result is loading
                if (info.status == 1) {
                    Text("Loading data from Wolfram...")
                        .padding()

                    ProgressView()
                }
                // Otherwise display all of the pods
                else {
                    switch info.wolfram {
                        case .success(let pods):
                            ForEach(pods, id: \.self) { pod in
                                AsyncImage(url: URL(string: pod.imgSrc)) { image in
                                    // Make image as wide as possible
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                } placeholder: {
                                    Text("Loading image...")
                                        .padding()

                                    ProgressView()
                                }
                                
                            }

                        case .failure(let error):
                            Text(error)
                                .padding()    
                    }
                }
            }
            
            // Button for expanding/collapsing the additional info
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                Text(isExpanded ? "Collapse" : "Expand")
            }
        }
        .background(Color.white) // Background color for each box
        .cornerRadius(10) // Rounded corners for the box
        .padding(.vertical, 10) // Vertical spacing between boxes
        .padding(.horizontal, 20) // Horizontal spacing for the  box
        .shadow(radius: 5) // Add shadow for a card-like effect
        .frame(maxWidth: .infinity)
    }

    /// Required for the hashable interface
    func hash(into hasher: inout Hasher) {
        hasher.combine(status)
        hasher.combine(info)
    }
    
    
    /// Required for the hashable interface
    static func == (lhs: EquationBox, rhs: EquationBox) -> Bool {
        return lhs.status == rhs.status && lhs.info == rhs.info
    }
}
