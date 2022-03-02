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
import Detailer

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    enum Tabs {
        case unbound
        case bound
    }
    
    typealias Sort = TablerSort<Fruit>
    typealias Context = TablerContext<Fruit>
    typealias ProjectedValue = ObservedObject<Fruit>.Wrapper
    
    private let title = "Tabler Core Data Demo"
    
    @State private var childContext: NSManagedObjectContext? = nil
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
            onSave: detailSaveAction,
            onCancel: detailCancelAction,
            titler: { _ in title })
    }
    
    // MARK: - Views
    
    var body: some View {
        VStack {
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
            TablerList1(listConfig,
                        headerContent: header,
                        rowContent: row,
                        results: fruits,
                        selected: $selected)
                .tabItem { Text("Unbound") }
                .tag(Tabs.unbound)
            TablerListC(listConfig,
                        headerContent: header,
                        rowContent: brow,
                        results: fruits)
                .onDisappear(perform: commitAction) // auto-save any pending changes
                .tabItem { Text("Bound") }
                .tag(Tabs.bound)
        }
#if os(macOS)
        .padding()
#endif
        .editDetailer(detailerConfig,
                       toEdit: $toEdit,
                       isAdd: $isAdd,
                       detailContent: editDetail)
        .toolbar {
            ToolbarItemGroup {
                loadButton
                clearButton
            }
            ToolbarItemGroup {
#if os(macOS)
                editButton
#endif
                addButton
            }
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
            .modifier(menu(element))    // TODO is there a better way to handle menu?
        Text(element.name ?? "")
        Text(String(format: "%.0f g", element.weight))
    }
    
    // BOUND value row (with direct editing and auto-save)
    // See the `.onDisappear(perform: commitAction)` above to auto-save for tab-switching.
    @ViewBuilder
    private func brow(_ element: ProjectedValue) -> some View {
        Text(element.id.wrappedValue ?? "")
        TextField("Name",
                  text: Binding(element.name, replacingNilWith: ""),
                  onCommit: commitAction)
            .textFieldStyle(.roundedBorder)
            .border(Color.secondary)
        TextField("Weight",
                  value: element.weight,
                  formatter: NumberFormatter(),
                  onCommit: commitAction)
            .textFieldStyle(.roundedBorder)
            .border(Color.secondary)
    }
   
    private func editDetail(ctx: DetailerContext<Fruit>, element: ProjectedValue) -> some View {
        Form {
            TextField("ID", text: Binding(element.id, replacingNilWith: ""))
                .validate(ctx, element.id.wrappedValue, \.id) { ($0?.count ?? 0) > 0 }
            TextField("Name", text: Binding(element.name, replacingNilWith: ""))
                .validate(ctx, element.name.wrappedValue, \.name) { ($0?.count ?? 0) > 0 }
            TextField("Weight", value: element.weight, formatter: NumberFormatter())
                .validate(ctx, element.weight.wrappedValue, \.weight) { $0 > 0 }
            TextField("Color", text: Binding(element.color, replacingNilWith: "gray"))
                .validate(ctx.config, true)  // spacer, for consistency
        }
    }
    
    private var loadButton: some View {
        Button(action: {
            FruitBase.loadSampleData(viewContext)
        }) { Text("Load Sample Data") }
    }
    
    private var clearButton: some View {
        Button(action: {
            clearAction()
        }) { Text("Clear") }
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
            let fr = NSFetchRequest<Fruit>.init(entityName: "Fruit")
            fr.predicate = NSPredicate(format: "id == %@", _id!)
            return try viewContext.fetch(fr)
        } catch {
            let nsError = error as NSError
            print("\(#function): Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return []
    }
    
    // MARK: - Action Handlers
    
    // supporting "auto-save" of direct modifications
    private func commitAction() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("\(#function): Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func addAction() {
        if childContext == nil { childContext = viewContext.childContext() }
        let childsFruit = Fruit(context: childContext!)
        isAdd = true                // NOTE cleared on dismissal of detail sheet
        toEdit = childsFruit
    }
    
    private func editAction(_ id: Fruit.ID?) {
        if childContext == nil { childContext = viewContext.childContext() }
        guard let _fruit = get(for: id).first else { return }
        let childsFruit = childContext!.object(with: _fruit.objectID) as! Fruit
        isAdd = false
        toEdit = childsFruit
    }
    
    private func detailCancelAction(_ context: DetailerContext<Fruit>, _ element: Fruit) {
        guard let moc = self.childContext else {
            print("\(#function): child context not found")
            return
        }
        
        if moc.hasChanges { moc.rollback() }
    }
    
    /// Note the parent context must ALSO be saved to persist the changes of its child.
    private func detailSaveAction(_ context: DetailerContext<Fruit>, _ element: Fruit) {
        guard let moc = self.childContext else {
            print("\(#function): child context not found")
            return
        }

        do {
            if moc.hasChanges {
                try moc.save()
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            print("\(#function): Unresolved error \(nsError), \(nsError.userInfo)")
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
            print("\(#function): Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func clearAction() {
        do {
            fruits.forEach { viewContext.delete($0) }
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("\(#function): Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

