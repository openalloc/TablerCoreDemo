//
//  Fruit.swift
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

import CoreData
import SwiftUI

struct FruitBase: Identifiable {
    var id: String
    var name: String
    var weight: Double
    var color: Color
    init(_ id: String = "",
         _ name: String = "",
         _ weight: Double = 0,
         _ color: Color = .gray) {
        self.id = id
        self.name = name
        self.weight = weight
        self.color = color
    }
    
    static var bootstrap: [FruitBase] = [
        FruitBase("🍌", "Banana", 118, .brown),
        FruitBase("🍓", "Strawberry", 12, .red),
        FruitBase("🍊", "Orange", 190, .orange),
        FruitBase("🥝", "Kiwi", 75, .green),
        FruitBase("🍇", "Grape", 7, .purple),
        FruitBase("🫐", "Blueberry", 2, .blue),
    ]
    
    static func loadSampleData(_ viewContext: NSManagedObjectContext) {
        do {
            for fruit in bootstrap {
                let nuFruit = Fruit(context: viewContext)
                nuFruit.id = fruit.id
                nuFruit.name = fruit.name
                nuFruit.weight = fruit.weight
                nuFruit.color = fruit.color.description
            }
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
