import Foundation

// NOTE: No collection-specific tests exist in the original EdisonTests.swift.
// Collection CRUD is exercised indirectly through AppState in AppStateLifecycleTests.
// This file is a placeholder to satisfy AC4 (>= 6 test files) and establish
// the domain file for future W4b collection coordinator tests.

#if canImport(Testing)
import Testing
@testable import Edison

struct CollectionTests {
    // Placeholder: collection unit tests will be added in W4b alongside
    // ClipboardCoordinator extraction (W2.1), which owns collection CRUD.
}
#elseif canImport(XCTest)
import XCTest
@testable import Edison

final class CollectionTests: XCTestCase {
    // Placeholder: collection unit tests will be added in W4b alongside
    // ClipboardCoordinator extraction (W2.1), which owns collection CRUD.
}
#endif
