//
//  SidebarViewModelFolderExpansionTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("SidebarViewModel Folder Expansion Tests")
struct SidebarViewModelFolderExpansionTests {
    @Test("No folders are collapsed on init")
    @MainActor
    func initialExpansionState() {
        let vm = SidebarViewModel()
        #expect(vm.collapsedFolders.isEmpty)
    }

    // MARK: - Folder Expansion

    @Test("Folders default to expanded")
    @MainActor
    func foldersDefaultToExpanded() {
        let vm = SidebarViewModel()
        let id = UUID()
        #expect(vm.isFolderExpanded(id))
    }

    @Test("setFolderExpanded false collapses folder")
    @MainActor
    func setFolderCollapsed() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.setFolderExpanded(id, isExpanded: false)
        #expect(!vm.isFolderExpanded(id))
    }

    @Test("setFolderExpanded true re-expands folder")
    @MainActor
    func setFolderReExpanded() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.setFolderExpanded(id, isExpanded: false)
        vm.setFolderExpanded(id, isExpanded: true)
        #expect(vm.isFolderExpanded(id))
    }

    @Test("toggleFolderExpansion collapses expanded folder")
    @MainActor
    func toggleCollapse() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.toggleFolderExpansion(id)
        #expect(!vm.isFolderExpanded(id))
    }

    @Test("toggleFolderExpansion expands collapsed folder")
    @MainActor
    func toggleExpand() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.toggleFolderExpansion(id)
        vm.toggleFolderExpansion(id)
        #expect(vm.isFolderExpanded(id))
    }

    @Test("Collapsing one folder does not affect others")
    @MainActor
    func independentFolderExpansion() {
        let vm = SidebarViewModel()
        let id1 = UUID()
        let id2 = UUID()
        vm.setFolderExpanded(id1, isExpanded: false)
        #expect(!vm.isFolderExpanded(id1))
        #expect(vm.isFolderExpanded(id2))
    }

    // MARK: - Expanded Binding

    @Test("expandedBinding getter returns correct state")
    @MainActor
    func expandedBindingGetter() {
        let vm = SidebarViewModel()
        let id = UUID()
        let binding = vm.expandedBinding(for: id)
        #expect(binding.wrappedValue == true)

        vm.setFolderExpanded(id, isExpanded: false)
        #expect(binding.wrappedValue == false)
    }

    @Test("expandedBinding setter updates state")
    @MainActor
    func expandedBindingSetter() {
        let vm = SidebarViewModel()
        let id = UUID()
        let binding = vm.expandedBinding(for: id)
        binding.wrappedValue = false
        #expect(!vm.isFolderExpanded(id))

        binding.wrappedValue = true
        #expect(vm.isFolderExpanded(id))
    }
}
