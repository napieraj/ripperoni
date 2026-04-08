// ripperoni-iokit-state — IOKit optical drive state for macOS (drutil bypass).
//
// Contract (stdout, one line, no extra whitespace):
//   open | empty | loading | ready | busy | unknown
//
// Exit: 0 always when a line is printed; stderr for diagnostics.
// Invalid usage: exit 2.
//
// Argument: drutil-style 1-based drive index (same as RIPPERONI_DRIVE on macOS).

import Foundation
import IOKit

private let opticalClasses = [
    "IOCDBlockStorageDevice",
    "IODVDBlockStorageDevice",
    "IOBDBlockStorageDevice",
]

@discardableResult
private func release(_ obj: io_object_t) -> io_object_t {
    if obj != 0 {
        IOObjectRelease(obj)
    }
    return 0
}

private func registryEntryID(_ entry: io_registry_entry_t) -> UInt64 {
    var id: UInt64 = 0
    _ = IORegistryEntryGetRegistryEntryID(entry, &id)
    return id
}

/// Collect optical block storage services; stable order by registry entry ID.
private func opticalServices() -> [io_registry_entry_t] {
    var seen = Set<UInt64>()
    var out: [io_registry_entry_t] = []

    for className in opticalClasses {
        guard let matching = IOServiceMatching(className) else { continue }
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            continue
        }
        defer { release(iter) }

        while true {
            let svc = IOIteratorNext(iter)
            if svc == 0 { break }
            let rid = registryEntryID(svc)
            if seen.insert(rid).inserted {
                out.append(svc)
            } else {
                release(svc)
            }
        }
    }

    out.sort { registryEntryID($0) < registryEntryID($1) }
    return out
}

private func cfProperty(_ entry: io_registry_entry_t, _ key: String) -> CFTypeRef? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue()
}

private func boolProperty(_ entry: io_registry_entry_t, _ key: String) -> Bool? {
    guard let ref = cfProperty(entry, key) else { return nil }
    if let b = ref as? Bool { return b }
    let tr = ref as CFTypeRef
    if CFGetTypeID(tr) == CFBooleanGetTypeID() {
        return CFBooleanGetValue((tr as! CFBoolean))
    }
    return nil
}

private func intProperty(_ entry: io_registry_entry_t, _ key: String) -> Int64? {
    guard let ref = cfProperty(entry, key) else { return nil }
    if let n = ref as? Int64 { return n }
    if let n = ref as? Int { return Int64(n) }
    if let n = ref as? NSNumber { return n.int64Value }
    return nil
}

/// Tray open: boolean keys or "Tray State" (1 = open per IOCDMedia convention on many Apple drivers).
private func trayOpenLikely(_ entry: io_registry_entry_t) -> Bool? {
    if boolProperty(entry, "Tray Open") == true { return true }
    if boolProperty(entry, "TrayOpen") == true { return true }
    if let ts = intProperty(entry, "Tray State"), ts == 1 { return true }
    if boolProperty(entry, "Tray Open") == false { return false }
    if boolProperty(entry, "TrayOpen") == false { return false }
    if let ts = intProperty(entry, "Tray State"), ts == 0 { return false }
    return nil
}

private func trayOpenScanningAncestors(_ entry: io_registry_entry_t, depth: Int = 6) -> Bool? {
    var e = entry
    var remaining = depth
    var acquired: [io_registry_entry_t] = []

    defer {
        for x in acquired {
            release(x)
        }
    }

    while remaining > 0 {
        if let t = trayOpenLikely(e) { return t }
        var parent: io_registry_entry_t = 0
        if IORegistryEntryGetParentEntry(e, kIOServicePlane, &parent) != KERN_SUCCESS {
            break
        }
        if parent == 0 { break }
        acquired.append(parent)
        e = parent
        remaining -= 1
    }
    return nil
}

private func ioObjectConforms(_ obj: io_object_t, _ c: String) -> Bool {
    c.withCString { IOObjectConformsTo(obj, $0) != 0 }
}

private func hasOpticalMediaTree(_ entry: io_registry_entry_t, depth: Int, maxDepth: Int) -> Bool {
    if depth > maxDepth { return false }

    if ioObjectConforms(entry, "IOCDMedia") || ioObjectConforms(entry, "IODVDMedia")
        || ioObjectConforms(entry, "IOBDMedia")
    {
        return true
    }

    var iter: io_iterator_t = 0
    guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iter) == KERN_SUCCESS else {
        return false
    }
    defer { release(iter) }

    while true {
        let child = IOIteratorNext(iter)
        if child == 0 { break }
        let found = hasOpticalMediaTree(child, depth: depth + 1, maxDepth: maxDepth)
        release(child)
        if found { return true }
    }
    return false
}

private func busyLikely(_ entry: io_registry_entry_t) -> Bool {
    if boolProperty(entry, "Busy") == true { return true }
    if let b = intProperty(entry, "BusyState"), b != 0 { return true }
    return false
}

/// Maps IOKit observations to ripperoni state names.
private func state(for service: io_registry_entry_t) -> String {
    let media = hasOpticalMediaTree(service, depth: 0, maxDepth: 12)
    let tray = trayOpenScanningAncestors(service)
    let busy = busyLikely(service)

    if tray == true {
        return "open"
    }

    if media {
        if busy {
            return "loading"
        }
        return "ready"
    }

    if tray == false {
        return "empty"
    }

    // Tray unknown, no media leaf: still ambiguous (open vs empty closed).
    return "unknown"
}

private func usage() -> Never {
    fputs("usage: ripperoni-iokit-state <drive>\n  drive: drutil 1-based index\n", stderr)
    exit(2)
}

func main() {
    let args = CommandLine.arguments.dropFirst()
    guard let first = args.first, let idx = Int(first), idx >= 1 else {
        usage()
    }

    let services = opticalServices()
    defer {
        for s in services {
            release(s)
        }
    }

    guard idx <= services.count else {
        print("unknown")
        exit(0)
    }

    let svc = services[idx - 1]
    print(state(for: svc))
}

main()
