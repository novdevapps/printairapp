import Dependencies
import SwiftUI

struct PrintersScreen: View {
    @Environment(\.dismiss) var dismiss
    @State var printers: [Printer] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(printers) { printer in
                    HStack {
                        Image("ic_printer")
                        
                        Text(printer.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
        }
        .secondaryBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Available devices")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image("ic_back")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .task {
            @Dependency(\.printerClient) var printerClient
            for await printers in printerClient.start() {
                self.printers = printers
            }
        }
    }
}

#Preview {
    NavigationView {
        PrintersScreen()
    }
}
