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

//TODO use a nested viewContext to target rollback to the changes made by detailer.

import SwiftUI
import CoreData
import Tabler
import Detailer

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    enum Tabs {
        case unbound
        case bound
    }
    
    typealias Sort = TablerSort<Fruit>
    typealias Context = TablerContext<Fruit>
    
    private let title = "Tabler/Detailer Core Data Demo"
    
    @State private var selected: Fruit.ID? = nil
    @State private var toEdit: Fruit? = nil
    @State private var isAdd: Bool = false
    @State private var tab: Tabs = .unbound
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.name, order: .forward)],
        animation: .default)
    private var fruits: FetchedResults<Fruit>
    
    private var gridItems: [GridItem] = [
        GridItem(.flexible(minimum: 35, maximum: 50), alignment: .leading),
        GridItem(.flexible(minimum: 100, maximum: 200), alignment: .leading),
        GridItem(.flexible(minimum: 90, maximum: 100), alignment: .trailing),
        //GridItem(.flexible(minimum: 35, maximum: 50), alignment: .leading),
    ]
    
    private var listConfig: TablerListConfig<Fruit> {
        TablerListConfig<Fruit>(gridItems: gridItems)
    }
    
    private var detailerConfig: DetailerConfig<Fruit> {
        DetailerConfig<Fruit>(
            onDelete: deleteAction,
            onSave: saveAction,
            onCancel: cancelAction,
            titler: { _ in title })
    }
    
    // MARK: - Views
    
    var body: some View {
        Group {
#if os(macOS)
            tabView
#elseif os(iOS)
            NavigationView {
                tabView
                    .navigationTitle(title)
            }
            .navigationViewStyle(StackNavigationViewStyle())
#endif
        }
    }
    
    private var tabView: some View {
        TabView(selection: $tab) {
            unboundView
                .tabItem { Text("Unbound") }
                .tag(Tabs.unbound)
            boundView
                .tabItem { Text("Bound (Observable Object)") }
                .tag(Tabs.bound)
        }
//        .editDetailer(detailerConfig,
//                      toEdit: $toEdit,
//                      isAdd: $isAdd,
//                      detailContent: editDetail)
        .toolbar {
            ToolbarItemGroup {
                Button(action: {
                    FruitBase.loadSampleData(viewContext)
                }) { Text("Load Sample Data") }
                Button(action: {
                    clearAction()
                }) { Text("Clear") }
            }
            ToolbarItemGroup {
#if os(macOS)
                editButton
#endif
                addButton
            }
        }
    }
    
    private var unboundView: some View {
        TablerList1(listConfig,
                    headerContent: header,
                    rowContent: row,
                    results: fruits,
                    selected: $selected)
    }
    
    private var boundView: some View {
        TablerListO(listConfig,
                    headerContent: header,
                    rowContent: brow,
                    results: fruits)
    }
    
    private var editButton: some View {
        Button(action: { editAction(selected) } ) {
            Text("Edit")
        }
        .disabled(selected == nil)
    }
    
    private var addButton: some View {
        Button(action: addAction) {
            Label("Add Item", systemImage: "plus")
        }
    }
    
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
            .modifier(menu(element))
        Text(element.name ?? "")
        Text(String(format: "%.0f g", element.weight))
    }
    
    typealias ProjectedValue<E> = ObservedObject<E>.Wrapper where E: ObservableObject
    
    // BOUND value row (with direct editing)
    @ViewBuilder
    private func brow(_ element: ProjectedValue<Fruit>) -> some View {
        Text(element.id.wrappedValue ?? "")
        TextField("Name", text: Binding(element.name, replacingNilWith: ""))
            .textFieldStyle(.roundedBorder)
            .border(Color.secondary)
        TextField("Weight", value: element.weight, formatter: NumberFormatter())
            .textFieldStyle(.roundedBorder)
            .border(Color.secondary)
//        Text(String(format: "%.0f g", element.weight.wrappedValue))
    }
    
    /**
     TODO should detailer be using an @ObservedObject?
     
     struct EditView : View {
         @ObservedObject var book: Book
         
         init(book: Book) {
             self.book = book
         }
         
         var body : some View {
             TextField("Name", text: $book.bookName)
         }
     }
     
     
     @ObservedObject var thing: Thing
     TextField("name", text: $thing.localName)
     */
    private func editDetail(ctx: DetailerContext<Fruit>, element: Binding<Fruit>) -> some View {
        Form {
            TextField("ID", text: Binding(element.id, replacingNilWith: ""))
                .validate(ctx, element, \.id) { ($0?.count ?? 0) > 0 }
            TextField("Name", text: Binding(element.name, replacingNilWith: ""))
                .validate(ctx, element, \.name) { ($0?.count ?? 0) > 0 }
            TextField("Weight", value: element.weight, formatter: NumberFormatter())
                .validate(ctx, element, \.weight) { $0 > 0 }
            TextField("Color", text: Binding(element.color, replacingNilWith: "gray"))
        }
    }
    
    // MARK: - Menus
    
#if os(macOS)
    private func menu(_ fruit: Fruit) -> EditDetailerContextMenu<Fruit> {
        EditDetailerContextMenu(detailerConfig, $toEdit, fruit)
    }
#elseif os(iOS)
    private func menu(_ fruit: Fruit) -> EditDetailerSwipeMenu<Fruit> {
        EditDetailerSwipeMenu(detailerConfig, $toEdit, fruit)
    }
#endif
    
    // MARK: - Helpers
    
    private func get(for id: Fruit.ID?) -> [Fruit] {
        guard let _id = id else { return [] }
        do {
            let fetchRequest = NSFetchRequest<Fruit>.init(entityName: "Fruit")
            fetchRequest.predicate = NSPredicate(format: "id == %@", _id!)
            return try viewContext.fetch(fetchRequest)
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return []
    }
    
    // MARK: - Action Handlers
    
    private func addAction() {
        isAdd = true                // NOTE cleared on dismissal of detail sheet
        toEdit = Fruit(context: viewContext)
    }
    
    private func editAction(_ id: Fruit.ID?) {
        guard let _fruit = get(for: id).first else { return }
        isAdd = false
        toEdit = _fruit
    }
    
    private func cancelAction(_ context: DetailerContext<Fruit>, _ element: Fruit) {
        viewContext.rollback()
    }
    
    private func saveAction(_ context: DetailerContext<Fruit>, _ element: Fruit) {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func deleteAction(_ id: Fruit.ID) {
        let _fruit = get(for: id)
        guard _fruit.count > 0 else { return }
        do {
            _fruit.forEach { viewContext.delete($0) }
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func clearAction() {
        do {
            fruits.forEach { viewContext.delete($0) }
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
