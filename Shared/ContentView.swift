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
import DetailerMenu

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    typealias Sort = TablerSort<Fruit>
    typealias Context = TablerContext<Fruit>
    typealias ProjectedValue = ObservedObject<Fruit>.Wrapper
    
    private let minWidth: CGFloat = 400
    private let title = "Tabler Core Data Demo"
    
    @State private var childContext: NSManagedObjectContext? = nil
    @State private var selected: Fruit.ID? = nil
    @State private var mselected = Set<Fruit.ID>()
    @State private var toEdit: Fruit? = nil
    @State private var isAdd: Bool = false
    @State private var headerize: Bool = true
    
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
    
    private var myToolbar: FruitToolbar {
        FruitToolbar(headerize: $headerize,
                     onLoad: loadAction,
                     onClear: clearAction,
                     onAdd: addAction,
                     onEdit: editAction)
    }
    
    private var listConfig: TablerListConfig<Fruit> {
        TablerListConfig<Fruit>()
    }

    private var stackConfig: TablerStackConfig<Fruit> {
        TablerStackConfig<Fruit>()
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
        NavigationView {
            List {
                Section("List-based") {
                    lists
                }
                
                Section("Stack-based") {
                    stacks
                }
           }
#if os(iOS)
            .navigationTitle(title)
#endif
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
#if os(macOS)
        .navigationTitle(title)
#endif
        .editDetailer(detailerConfig,
                      toEdit: $toEdit,
                      isAdd: $isAdd,
                      detailContent: editDetail)
    }
    
    private func header(_ ctx: Binding<Context>) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            Sort.columnTitle("ID", ctx, \.id)
                .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.id)] }
            Sort.columnTitle("Name", ctx, \.name)
                .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.name)] }
            Sort.columnTitle("Weight", ctx, \.weight)
                .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.weight)] }
        }
    }
    
    private func row(_ element: Fruit) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            Text(element.id ?? "")
                .modifier(menu(element))    // TODO is there a better way to handle menu?
            Text(element.name ?? "")
            Text(String(format: "%.0f g", element.weight))
        }
    }
    
    // BOUND value row (with direct editing and auto-save)
    // See the `.onDisappear(perform: commitAction)` above to auto-save for tab-switching.
    private func brow(_ element: ProjectedValue) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
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
    
    @ViewBuilder
    var lists: some View {
        NavigationLink("TablerList"   ) { listView  .toolbar { myToolbar }}
        NavigationLink("TablerList1"  ) { list1View .toolbar { myToolbar }}
        NavigationLink("TablerListM"  ) { listMView .toolbar { myToolbar }}
        NavigationLink("TablerListC"  ) { listCView .toolbar { myToolbar }}
        NavigationLink("TablerList1C" ) { list1CView.toolbar { myToolbar }}
        NavigationLink("TablerListMC" ) { listMCView.toolbar { myToolbar }}
    }
    
    @ViewBuilder
    private var stacks: some View {
        NavigationLink("TablerStack"  ) { stackView  .toolbar { myToolbar }}
        NavigationLink("TablerStack1" ) { stack1View .toolbar { myToolbar }}
        NavigationLink("TablerStackC" ) { stackCView .toolbar { myToolbar }}
        NavigationLink("TablerStack1C") { stack1CView.toolbar { myToolbar }}
    }
    

    // MARK: - List Views
    
    private var listView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerList(listConfig,
                           header: header,
                           row: row,
                           results: fruits)
            } else {
                TablerList(listConfig,
                           row: row,
                           results: fruits)
            }
        }
    }
    
    private var list1View: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerList1(listConfig,
                            header: header,
                            row: row,
                            results: fruits,
                            selected: $selected)
            } else {
                TablerList1(listConfig,
                            row: row,
                            results: fruits,
                            selected: $selected)
            }
        }
    }
    
    private var listMView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerListM(listConfig,
                            header: header,
                            row: row,
                            results: fruits,
                            selected: $mselected)
            } else {
                TablerListM(listConfig,
                            row: row,
                            results: fruits,
                            selected: $mselected)
            }
        }
    }
    
    private var listCView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerListC(listConfig,
                            header: header,
                            row: brow,
                            results: fruits)
            } else {
                TablerListC(listConfig,
                            row: brow,
                            results: fruits)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var list1CView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerList1C(listConfig,
                             header: header,
                             row: brow,
                             results: fruits,
                             selected: $selected)
            } else {
                TablerList1C(listConfig,
                             row: brow,
                             results: fruits,
                             selected: $selected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var listMCView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerListMC(listConfig,
                             header: header,
                             row: brow,
                             results: fruits,
                             selected: $mselected)
            } else {
                TablerListMC(listConfig,
                             row: brow,
                             results: fruits,
                             selected: $mselected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    // MARK: - Stack Views
    
    private var stackView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerStack(stackConfig,
                            header: header,
                            row: row,
                            results: fruits)
            } else {
                TablerStack(stackConfig,
                            row: row,
                            results: fruits)
            }
        }
    }
    
    private var stack1View: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerStack1(stackConfig,
                             header: header,
                             row: row,
                             results: fruits,
                             selected: $selected)
            } else {
                TablerStack1(stackConfig,
                             row: row,
                             results: fruits,
                             selected: $selected)
            }
        }
    }
    
    private var stackCView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerStackC(stackConfig,
                             header: header,
                             row: brow,
                             results: fruits)
            } else {
                TablerStackC(stackConfig,
                             row: brow,
                             results: fruits)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var stack1CView: some View {
        SidewaysScroller(minWidth: minWidth) {
            if headerize {
                TablerStack1C(stackConfig,
                              header: header,
                              row: brow,
                              results: fruits,
                              selected: $selected)
            } else {
                TablerStack1C(stackConfig,
                              row: brow,
                              results: fruits,
                              selected: $selected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    // MARK: - Menus
    
#if os(macOS)
    private func menu(_ fruit: Fruit) -> EditDetailerContextMenu<Fruit> {
        EditDetailerContextMenu(fruit,
                                $toEdit,
                                canEdit: detailerConfig.canEdit,
                                canDelete: detailerConfig.canDelete,
                                onDelete: detailerConfig.onDelete)
    }
#elseif os(iOS)
    private func menu(_ fruit: Fruit) -> EditDetailerSwipeMenu<Fruit> {
        EditDetailerSwipeMenu(fruit,
                              $toEdit,
                              canEdit: detailerConfig.canEdit,
                              canDelete: detailerConfig.canDelete,
                              onDelete: detailerConfig.onDelete)
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
    
    private func editAction() {
        // TODO make work with multi-select too
        editAction(selected)
    }
    
    private func editAction(_ id: Fruit.ID?) {
        guard let _id = id else { return }
        if childContext == nil { childContext = viewContext.childContext() }
        guard let _fruit = get(for: _id).first else { return }
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
    
    private func loadAction() {
        FruitBase.loadSampleData(viewContext)
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

