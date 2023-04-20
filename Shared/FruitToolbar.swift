//
//  FruitToolbar.swift
//
// Copyright 2021, 2022 OpenAlloc LLC
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

struct FruitToolbar: ToolbarContent {
    @Binding var headerize: Bool
    var onLoad: () -> Void
    var onClear: () -> Void
    var onAdd: () -> Void
    var onEdit: () -> Void

    // private var toolbarGroup: ToolbarItemGroup {
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
            // editAction(selected)
            onEdit()
        }) {
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
