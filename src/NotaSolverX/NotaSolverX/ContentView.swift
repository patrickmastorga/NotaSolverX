import SwiftUI
import PencilKit

struct ContentView: View {
    @State var canvas = PKCanvasView()
    @State private var currentPosition: CGSize = .zero
    @State private var newSize: CGSize = CGSize(width: 150, height: 150)
    @State private var showRectangle: Bool = false
    
    var body: some View {
            ZStack {
                DrawingView(canvas: $canvas)
                
                if showRectangle {
                    ResizableRectangle(currentPosition: $currentPosition, newSize: $newSize)
                        .border(Color.black, width: 1)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Button("Toggle Rectangle") {
                            showRectangle.toggle()
                        }
                        .padding()
                        
                        if showRectangle {
                            Button("Capture and Save Strokes") {
                                //getPathsInRectangle()
                            }
                            .padding()
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
                } else if pathLength > 1 {
                    paths.append(path)
                    path = []
                }
            }
        }
        return paths
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
                )
            
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
