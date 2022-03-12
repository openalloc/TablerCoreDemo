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
    
    private let columnSpacing: CGFloat = 10
    private let minWidth: CGFloat = 400
    private let title = "Tabler Core Data Demo"
    
    @State private var childContext: NSManagedObjectContext? = nil
    @State private var selected: Fruit.ID? = nil
    @State private var mselected = Set<Fruit.ID>()
    @State private var toEdit: Fruit? = nil
    @State private var isAdd: Bool = false
    @State private var headerize: Bool = true
    @State private var hovered: Fruit.ID? = nil
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.name, order: .forward)],
        animation: .default)
    private var fruits: FetchedResults<Fruit>
    
    private var gridItems: [GridItem] {[
        GridItem(.flexible(minimum: 40, maximum: 60), spacing: columnSpacing, alignment: .leading),
        GridItem(.flexible(minimum: 100, maximum: 200), spacing: columnSpacing, alignment: .leading),
        GridItem(.flexible(minimum: 90, maximum: 100), spacing: columnSpacing, alignment: .trailing),
        //GridItem(.flexible(minimum: 35, maximum: 50), spacing: columnSpacing, alignment: .leading),
    ]}
    
    private var listConfig: TablerListConfig<Fruit> {
        TablerListConfig<Fruit>(onHover: hoverAction)
    }
    
    private var stackConfig: TablerStackConfig<Fruit> {
        TablerStackConfig<Fruit>(onHover: hoverAction)
    }
    
    private var gridConfig: TablerGridConfig<Fruit> {
        TablerGridConfig<Fruit>(gridItems: gridItems, onHover: hoverAction)
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
                
                Section("Grid-based") {
                    grids
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
    
    private var columnPadding: EdgeInsets {
        EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                LinearGradient(gradient: .init(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]),
                               startPoint: .top,
                               endPoint: .bottom)
            )
    }
    
    private func header(ctx: Binding<Context>) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            Sort.columnTitle("ID", ctx, \.id)
                .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.id)] }
                .padding(columnPadding)
                .background(headerBackground)
            Sort.columnTitle("Name", ctx, \.name)
                .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.name)] }
                .padding(columnPadding)
                .background(headerBackground)
            Sort.columnTitle("Weight", ctx, \.weight)
                .onTapGesture { fruits.sortDescriptors = [tablerSort(ctx, \.weight)] }
                .padding(columnPadding)
                .background(headerBackground)
        }
    }
    
    // non-bound row for List, supporting context menu on macOS and swipe menu on iOS
    private func listRow(element: Fruit) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            rowItems(element: element)
        }
        .modifier(listMenu(element))
    }
    
    // non-bound row for Stack and Grid, only supporting context menu
    private func nonListRow(element: Fruit) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            rowItems(element: element)
        }
        .modifier(contextMenu(element))
    }
    
    @ViewBuilder
    private func rowItems(element: Fruit) -> some View {
        Text(element.id ?? "")
            .padding(columnPadding)
        Text(element.name ?? "")
            .padding(columnPadding)
        Text(String(format: "%.0f g", element.weight))
            .padding(columnPadding)
    }
    
    // Redundant items for grid, where each item is individually menued.
    // Not ideal, but no solution found yet.
    @ViewBuilder
    private func gridRowItems(element: Fruit) -> some View {
        Text(element.id ?? "")
            .padding(columnPadding)
            .modifier(contextMenu(element))
        Text(element.name ?? "")
            .padding(columnPadding)
            .modifier(contextMenu(element))
        Text(String(format: "%.0f g", element.weight))
            .padding(columnPadding)
            .modifier(contextMenu(element))
    }

    // bound row for List, supporting context menu on macOS and swipe menu on iOS
    private func listBrow(element: ProjectedValue) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            browItems(element: element)
        }
        //TODO .modifier(listMenu(element))
    }

    // bound row for Stack and Grid, only supporting context menu
    // See the `.onDisappear(perform: commitAction)` above to auto-save for tab-switching.
    private func nonListBrow(element: ProjectedValue) -> some View {
        LazyVGrid(columns: gridItems, alignment: .leading) {
            browItems(element: element)
        }
        //TODO .modifier(contextMenu(element))
    }
    
    // No redundant items for grid, at least yet, so no bound grid menus
    @ViewBuilder
    private func browItems(element: ProjectedValue) -> some View {
        Text(element.id.wrappedValue ?? "")
            .padding(columnPadding)
        TextField("Name",
                  text: Binding(element.name, replacingNilWith: ""),
                  onCommit: commitAction)
            .textFieldStyle(.roundedBorder)
            .border(Color.secondary)
            .padding(columnPadding)
        TextField("Weight",
                  value: element.weight,
                  formatter: NumberFormatter(),
                  onCommit: commitAction)
            .textFieldStyle(.roundedBorder)
            .border(Color.secondary)
            .padding(columnPadding)
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
        NavigationLink("TablerStackM" ) { stackMView .toolbar { myToolbar }}
        NavigationLink("TablerStackC" ) { stackCView .toolbar { myToolbar }}
        NavigationLink("TablerStack1C") { stack1CView.toolbar { myToolbar }}
        NavigationLink("TablerStackMC") { stackMCView.toolbar { myToolbar }}
    }
    
    @ViewBuilder
    private var grids: some View {
        NavigationLink("TablerGrid"  ) { gridView  .toolbar { myToolbar }}
        NavigationLink("TablerGrid1"  ) { grid1View  .toolbar { myToolbar }}
        NavigationLink("TablerGridM"  ) { gridMView  .toolbar { myToolbar }}
        NavigationLink("TablerGridC" ) { gridCView .toolbar { myToolbar }}
        NavigationLink("TablerGrid1C" ) { grid1CView .toolbar { myToolbar }}
        NavigationLink("TablerGridMC" ) { gridMCView .toolbar { myToolbar }}
    }
    
    private var myToolbar: FruitToolbar {
        FruitToolbar(headerize: $headerize,
                     onLoad: loadAction,
                     onClear: clearAction,
                     onAdd: addAction,
                     onEdit: editAction)
    }
    
    
    // single-select row background
    private func singleSelectBack(fruit: Fruit) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.accentColor.opacity(selected == fruit.id ? 1 : (hovered == fruit.id ? 0.2 : 0.0)))
    }
    
    // multi-select row background
    private func multiSelectBack(fruit: Fruit) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.accentColor.opacity(mselected.contains(fruit.id) ? 1 : (hovered == fruit.id ? 0.2 : 0.0)))
    }
    
    private func rowBackground(fruit: Fruit) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.accentColor.opacity(hovered == fruit.id ? 0.2 : 0.0))
    }

    // MARK: - Menus

    private func contextMenu(_ fruit: Fruit) -> EditDetailerContextMenu<Fruit> {
        EditDetailerContextMenu(fruit,
                                canDelete: detailerConfig.canDelete,
                                onDelete: detailerConfig.onDelete,
                                canEdit: detailerConfig.canEdit,
                                onEdit: editAction)
    }

#if os(macOS)
    private func listMenu(_ fruit: Fruit) -> EditDetailerContextMenu<Fruit> {
        EditDetailerContextMenu(fruit,
                                canDelete: detailerConfig.canDelete,
                                onDelete: detailerConfig.onDelete,
                                canEdit: detailerConfig.canEdit,
                                onEdit: editAction)
    }
#elseif os(iOS)
    private func listMenu(_ fruit: Fruit) -> EditDetailerSwipeMenu<Fruit> {
        EditDetailerSwipeMenu(fruit,
                              canDelete: detailerConfig.canDelete,
                              onDelete: detailerConfig.onDelete,
                              canEdit: detailerConfig.canEdit,
                              onEdit: editAction)
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
        if childContext == nil {
            print("\(#function) saving child context to state variable")
            childContext = viewContext.childContext()
        }
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
        guard let fruit = get(for: _id).first else { return }
        editAction(fruit)
    }
    
    private func editAction(_ fruit: Fruit) {
        if childContext == nil {
            print("\(#function) saving child context to state variable")
            childContext = viewContext.childContext()
        }
        let childsFruit = childContext!.object(with: fruit.objectID) as! Fruit
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
            //moc.rollback()
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
    
    private func deleteAction(_ fruit: Fruit) {
        let _fruit = get(for: fruit.id)
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
    
    private func hoverAction(fruitID: Fruit.ID, isHovered: Bool) {
        if isHovered { hovered = fruitID } else { hovered = nil }
    }
}

extension ContentView {
    // MARK: - List Views
    
    private var listView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerList(listConfig,
                           header: header,
                           row: listRow,
                           rowBackground: rowBackground,
                           results: fruits)
            } else {
                TablerList(listConfig,
                           row: listRow,
                           rowBackground: rowBackground,
                           results: fruits)
            }
        }
    }
    
    private var list1View: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerList1(listConfig,
                            header: header,
                            row: listRow,
                            rowBackground: rowBackground,
                            results: fruits,
                            selected: $selected)
            } else {
                TablerList1(listConfig,
                            row: listRow,
                            rowBackground: rowBackground,
                            results: fruits,
                            selected: $selected)
            }
        }
    }
    
    private var listMView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerListM(listConfig,
                            header: header,
                            row: listRow,
                            rowBackground: rowBackground,
                            results: fruits,
                            selected: $mselected)
            } else {
                TablerListM(listConfig,
                            row: listRow,
                            rowBackground: rowBackground,
                            results: fruits,
                            selected: $mselected)
            }
        }
    }
    
    private var listCView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerListC(listConfig,
                            header: header,
                            row: listBrow,
                            rowBackground: rowBackground,
                            results: fruits)
            } else {
                TablerListC(listConfig,
                            row: listBrow,
                            rowBackground: rowBackground,
                            results: fruits)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var list1CView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerList1C(listConfig,
                             header: header,
                             row: listBrow,
                             rowBackground: rowBackground,
                             results: fruits,
                             selected: $selected)
            } else {
                TablerList1C(listConfig,
                             row: listBrow,
                             rowBackground: rowBackground,
                             results: fruits,
                             selected: $selected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var listMCView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerListMC(listConfig,
                             header: header,
                             row: listBrow,
                             rowBackground: rowBackground,
                             results: fruits,
                             selected: $mselected)
            } else {
                TablerListMC(listConfig,
                             row: listBrow,
                             rowBackground: rowBackground,
                             results: fruits,
                             selected: $mselected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    // MARK: - Stack Views
    
    private var stackView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerStack(stackConfig,
                            header: header,
                            row: nonListRow,
                            rowBackground: rowBackground,
                            results: fruits)
            } else {
                TablerStack(stackConfig,
                            row: nonListRow,
                            rowBackground: rowBackground,
                            results: fruits)
            }
        }
    }
    
    private var stack1View: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerStack1(stackConfig,
                             header: header,
                             row: nonListRow,
                             rowBackground: singleSelectBack,
                             results: fruits,
                             selected: $selected)
            } else {
                TablerStack1(stackConfig,
                             row: nonListRow,
                             rowBackground: singleSelectBack,
                             results: fruits,
                             selected: $selected)
            }
        }
    }
    
    private var stackMView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerStackM(stackConfig,
                             header: header,
                             row: nonListRow,
                             rowBackground: multiSelectBack,
                             results: fruits,
                             selected: $mselected)
            } else {
                TablerStackM(stackConfig,
                             row: nonListRow,
                             rowBackground: multiSelectBack,
                             results: fruits,
                             selected: $mselected)
            }
        }
    }

    
    private var stackCView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerStackC(stackConfig,
                             header: header,
                             row: nonListBrow,
                             rowBackground: rowBackground,
                             results: fruits)
            } else {
                TablerStackC(stackConfig,
                             row: nonListBrow,
                             rowBackground: rowBackground,
                             results: fruits)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var stack1CView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerStack1C(stackConfig,
                              header: header,
                              row: nonListBrow,
                              rowBackground: singleSelectBack,
                              results: fruits,
                              selected: $selected)
            } else {
                TablerStack1C(stackConfig,
                              row: nonListBrow,
                              rowBackground: singleSelectBack,
                              results: fruits,
                              selected: $selected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var stackMCView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerStackMC(stackConfig,
                              header: header,
                              row: nonListBrow,
                              rowBackground: multiSelectBack,
                              results: fruits,
                              selected: $mselected)
            } else {
                TablerStackMC(stackConfig,
                              row: nonListBrow,
                              rowBackground: multiSelectBack,
                              results: fruits,
                              selected: $mselected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    // MARK: - Grid Views
    
    private var gridView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerGrid(gridConfig,
                           header: header,
                           row: gridRowItems,
                           rowBackground: rowBackground,
                           results: fruits)
            } else {
                TablerGrid(gridConfig,
                           row: gridRowItems,
                           rowBackground: rowBackground,
                           results: fruits)
            }
        }
    }
    
    private var gridCView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerGridC(gridConfig,
                            header: header,
                            row: browItems,
                            rowBackground: rowBackground,
                            results: fruits)
            } else {
                TablerGridC(gridConfig,
                            row: browItems,
                            rowBackground: rowBackground,
                            results: fruits)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var grid1View: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerGrid1(gridConfig,
                            header: header,
                            row: gridRowItems,
                            rowBackground: singleSelectBack,
                            results: fruits,
                            selected: $selected)
            } else {
                TablerGrid1(gridConfig,
                            row: gridRowItems,
                            rowBackground: singleSelectBack,
                            results: fruits,
                            selected: $selected)
            }
        }
    }
    
    private var gridMView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerGridM(gridConfig,
                            header: header,
                            row: gridRowItems,
                            rowBackground: multiSelectBack,
                            results: fruits,
                            selected: $mselected)
            } else {
                TablerGridM(gridConfig,
                            row: gridRowItems,
                            rowBackground: multiSelectBack,
                            results: fruits,
                            selected: $mselected)
            }
        }
    }
    
    private var grid1CView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerGrid1C(gridConfig,
                             header: header,
                             row: browItems,
                             rowBackground: singleSelectBack,
                             results: fruits,
                             selected: $selected)
            } else {
                TablerGrid1C(gridConfig,
                             row: browItems,
                             rowBackground: singleSelectBack,
                             results: fruits,
                             selected: $selected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
    
    private var gridMCView: some View {
        Sideways(minWidth: minWidth) {
            if headerize {
                TablerGridMC(gridConfig,
                             header: header,
                             row: browItems,
                             rowBackground: multiSelectBack,
                             results: fruits,
                             selected: $mselected)
            } else {
                TablerGridMC(gridConfig,
                             row: browItems,
                             rowBackground: multiSelectBack,
                             results: fruits,
                             selected: $mselected)
            }
        }
        .onDisappear(perform: commitAction) // auto-save any pending changes
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

