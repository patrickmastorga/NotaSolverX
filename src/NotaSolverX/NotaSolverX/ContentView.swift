import SwiftUI
import PencilKit

struct ColorInfo: Identifiable, Hashable {
    let id = UUID()
    let color: Color
    let uiColor: UIColor
}

struct ContentView: View {
    @State var canvas = PKCanvasView()
    @State private var currentPosition: CGSize = CGSize(width: 200, height: 450)
    @State private var newSize: CGSize = CGSize(width: 400, height: 150)
    @State private var showRectangle: Bool = false
    @State var currentTool: PKTool = PKInkingTool(.pen, color: .black, width: 10) // Default tool is the pen.
    @State private var selectedColor: ColorInfo = ColorInfo(color: .black, uiColor: .black) // Default color selection
    @State var selection: String = "black"
    
    let colors: [ColorInfo] = [
           ColorInfo(color: .black, uiColor: .black),
           ColorInfo(color: .red, uiColor: .red),
           ColorInfo(color: .green, uiColor: .green),
           ColorInfo(color: .blue, uiColor: .blue)
       ]
    
    @State private var equationBoxes: [EquationBox] = []
    
    var body: some View {
        ZStack {
            DrawingView(canvas: $canvas)
            
            if showRectangle {
                ResizableRectangle(currentPosition: $currentPosition, newSize: $newSize)
                    .border(Color.white, width: 1)
            }
            
            VStack {
                HStack {
                    Spacer()

                    VStack {
                        ScrollView {
                            ForEach(equationBoxes, id: \.self) { box in
                                box
                            }
                            
                            Spacer()
                        }
                    }
                    .background(Color.white)
                    .frame(width: 300)
                    .border(Color.black, width: 2)
                }
                
                HStack {
                    Menu {
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
    
                    Button("🖊") {
                        currentTool = PKInkingTool(.pen, color: .black, width: 10)
                        canvas.tool = currentTool
                    }
                    .padding()
                    .font(.system(size: 35))
                    
                    Button("❌") {
                        currentTool = PKEraserTool(.vector) // Use vector eraser type
                        canvas.tool = currentTool
                        }
                    .padding()
                    .font(.system(size: 35))
                    
                    Button("🔲") {
                        showRectangle.toggle()
                    }
                    .padding()
                    .font(.system(size: 35))
                    
                    if showRectangle {
                        Button("✅") {
                            print("Hello Wolrd")
                            processStrokesInRect(rect: getBoundingRect())
                            showRectangle = false
                        }
                        .padding()
                        .font(.system(size:35))
                    }
                }
            }
        }
    }
    
    func getStrokePointsInRect(rect: CGRect) -> [[CGPoint]] {
        var paths: [[CGPoint]] = []
        
        let intersectingStrokes = canvas.drawing.strokes.filter { stroke in
            stroke.renderBounds.intersects(rect)
        }
        
        for stroke in intersectingStrokes {
            var path: [CGPoint] = []
            var pathLength = 0;
            
            for point in stroke.path {
                if (rect.contains(point.location)) {
                    path.append(point.location)
                    pathLength += 1
                } else {
                    if pathLength > 1 {
                        paths.append(path)
                    }
                    path = []
                    pathLength = 0
                }
            }
            
            if pathLength > 1 {
                paths.append(path)
            }
        }
        return paths
    }
    
    func updateUIForRequest() {
        print("request made")
    }
    
    func updateUIForMathpixResult(result: Result<[String: Any], Error>) {
        switch result {
        case .success(let data):
            print("mathpix success: \(data)")
        case .failure(let error):
            print("mathpix failure: \(error)")
        }
    }
    
    func updateUIForWolframAlphaResult(result: Result<[String: Any], Error>) {
        switch result {
        case .success(let data):
            guard let queryresult = data["queryresult"] as? [String: Any] else {
                //Error handle
                return
            }
            guard let pods = queryresult["pods"] as? [[String: Any]] else {
                //Error handle
                return
            }
            
            var inputURL: String? = nil
            var stepsURL: String? = nil
            
            for pod in pods {
                if let idString = pod["id"] as? String {
                    
                    if idString == "Input" {
                        guard let subpods = pod["subpods"] as? [[String: Any]] else {
                            //Error handle
                            return
                        }
                        guard let img = subpods[0]["img"] as? [String: Any] else {
                            //Error handle
                            return
                        }
                        inputURL = img["src"] as? String
                    }
                    
                    if idString == "Result" {
                        /*
                        guard let subpods = pod["subpods"] as? [[String: Any]] else {
                            //Error handle
                            return
                        }
                        guard let img = subpods[0]["img"] as? [String: Any] else {
                            //Error handle
                            return
                        }
                        stepsURL = img["src"] as? String
                        */
                        
                        guard let subpods = pod["subpods"] as? [[String: Any]] else {
                            //Error handle
                            return
                        }
                        for subpod in subpods {
                            if let titleString = subpod["title"] as? String {
                                if titleString == "Possible intermediate steps" {
                                    guard let img = subpod["img"] as? [String: Any] else {
                                        //Error handle
                                        return
                                    }
                                    stepsURL = img["src"] as? String
                                }
                            }
                        }
                        
                        
                    }
                }
            }
            
            guard let inputURL = inputURL else {
                equationBoxes.append(EquationBox(inputURL: "https://www.computerhope.com/jargon/e/error.png", stepsURL: "https://www.computerhope.com/jargon/e/error.png"))
                return
            }
            guard let stepsURL = stepsURL else {
                equationBoxes.append(EquationBox(inputURL: inputURL, stepsURL: "https://www.computerhope.com/jargon/e/error.png"))
                return
            }

            equationBoxes.append(EquationBox(inputURL: inputURL, stepsURL: stepsURL))
            
        case .failure(let error):
            equationBoxes.append(EquationBox(inputURL: "https://www.computerhope.com/jargon/e/error.png", stepsURL: "https://www.computerhope.com/jargon/e/error.png"))
        }
    }
    
    /// Handles the entire process of converting the image into text, sending the text to wolfram, and creating the data to update the screen.
    /// - Parameter src: url of the image to be converted into a result
    /// - Parameter completion: completion handler to process display data or errors during the process
    func ProcessStrokes (strokes: [[CGPoint]]) {
        // Update UI to show request initialization
        updateUIForRequest()
        
        // Fetch from MathPix
        fetchDataFromMathpix(strokeData: strokes) { mathpixResult in
            // Update UI to show text response from Mathix
            updateUIForMathpixResult(result: mathpixResult)
            
            switch mathpixResult {
            case .success(let mathpixData):
                // Send Mathpix data to Wolfram Alpha
                fetchDataFromWolfram(data: mathpixData) { wolframResult in
                    // Update UI to show reponse from Wolfram Alpha
                    updateUIForWolframAlphaResult(result: wolframResult)
                    
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
    
    func processStrokesInRect(rect: CGRect) {
        ProcessStrokes(strokes: getStrokePointsInRect(rect: rect))
    }
    
    func getBoundingRect() -> CGRect {
        return CGRect(x: currentPosition.width,
                      y: currentPosition.height,
                      width: newSize.width,
                      height: newSize.height)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct DrawingView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) { }
}

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

struct EquationBox: View, Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(inputURL)
        hasher.combine(stepsURL)
    }
    
    static func == (lhs: EquationBox, rhs: EquationBox) -> Bool {
        return lhs.inputURL == rhs.inputURL && lhs.stepsURL == rhs.stepsURL
    }

    var inputURL: String
    var stepsURL: String
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack() {
                Spacer()
                
                AsyncImage(url: URL(string: inputURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    // Placeholder view while the image is loading
                    Text("Loading...")
                }
                .padding()
                
                Spacer()
            }
            
            if isExpanded {
                HStack() {
                    Spacer()
                    
                    AsyncImage(url: URL(string: stepsURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        // Placeholder view while the image is loading
                        Text("error")
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            
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
}
