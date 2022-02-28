//
//  ContentView.swift
//
// Copyright 2022 FlowAllocator LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI
import CoreData
import Tabler

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    typealias Sort = TablerSort<Fruit>
    typealias Context = TablerContext<Fruit>
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.name, order: .forward)],
        animation: .default)
    private var fruits: FetchedResults<Fruit>
    
    private var gridItems: [GridItem] = [
        GridItem(.flexible(minimum: 35, maximum: 40), alignment: .leading),
        GridItem(.flexible(minimum: 100), alignment: .leading),
        GridItem(.flexible(minimum: 40, maximum: 80), alignment: .trailing),
    ]
    
    @ViewBuilder
    private func header(_ ctx: Binding<Context>) -> some View {
        Sort.columnTitle("ID", ctx, \.id)
            .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.id)] }
        Sort.columnTitle("Name", ctx, \.name)
            .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.name)] }
        Sort.columnTitle("Weight", ctx, \.weight)
            .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.weight)] }
    }
    
    @ViewBuilder
    private func row(_ element: Fruit) -> some View {
        Text(element.id ?? "")
        Text(element.name ?? "")
        Text(String(format: "%.0f g", element.weight))
    }
    
    private var listConfig: TablerListConfig<Fruit> {
        TablerListConfig<Fruit>(gridItems: gridItems)
    }
    
    var body: some View {
#if os(macOS)
        theContent
#elseif os(iOS)
        NavigationView {
            theContent
        }
        .navigationViewStyle(StackNavigationViewStyle())
#endif
    }
    
    private var theContent: some View {
        TablerList(listConfig,
                   headerContent: header,
                   rowContent: row,
                   results: fruits)
            .toolbar {
                ToolbarItemGroup {
                    Button(action: {
                        FruitBase.loadSampleData(viewContext)
                    }) { Text("Load Sample Data") }
                    Button(action: {
                        clearAction()
                    }) { Text("Clear") }
                }
            }
    }
    
    private func clearAction() {
        do {
            fruits.forEach { viewContext.delete($0) }
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

private let fruitFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
