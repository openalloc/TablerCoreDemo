//
//  MOC-extension.swift
//  TablerCoreDemo
//
//  Created by Reed Esau on 3/1/22.
//

import CoreData

extension NSManagedObjectContext {
    func childContext(concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType) -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        childContext.parent = self
        return childContext
    }
}

