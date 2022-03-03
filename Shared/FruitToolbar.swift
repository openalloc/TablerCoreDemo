//
//  FruitToolbar.swift
//  TablerCoreDemo
//
//  Created by Reed Esau on 3/2/22.
//

import SwiftUI

struct FruitToolbar: ToolbarContent {
    @Binding var headerize: Bool
    var onLoad: () -> Void
    var onClear: () -> Void
    var onAdd: () -> Void
    var onEdit: () -> Void
    
    //private var toolbarGroup: ToolbarItemGroup {
    var body: some ToolbarContent {
        ToolbarItemGroup {
            Toggle(isOn: $headerize) { Text("Header") }
            loadButton
            clearButton
#if os(macOS)
            editButton
#endif
            addButton
        }
    }
    
    private var loadButton: some View {
        Button(action: {
            onLoad()
        }) { Text("Load Sample Data") }
    }
    
    private var clearButton: some View {
        Button(action: {
            onClear()
        }) { Text("Clear") }
    }
    
    private var editButton: some View {
        Button(action: {
            //editAction(selected)
            onEdit()
        } ) {
            Text("Edit")
        }
    }
    
    private var addButton: some View {
        Button(action: {
            onAdd()
        }) {
            Label("Add Item", systemImage: "plus")
        }
    }
    
}
