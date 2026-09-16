import Foundation
import Darwin
import Combine

@MainActor final class SystemMetrics: ObservableObject {
    @Published private(set) var cpuPercent = 0.0
    @Published private(set) var memoryPercent = 0.0
    @Published private(set) var memoryUsedGB = 0.0
    @Published private(set) var downloadBytesPerSecond = 0.0
    @Published private(set) var uploadBytesPerSecond = 0.0
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []

    private let historyLimit = 90

    private var timer: Timer?
    private var previousCPU: (busy: UInt64, total: UInt64)?
    private var previousNetwork: (received: UInt64, sent: UInt64, time: Date)?

    init() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        var cpuUpdated = false
        var cpu = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let cpuResult = withUnsafeMutablePointer(to: &cpu) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if cpuResult == KERN_SUCCESS {
            let ticks = withUnsafeBytes(of: cpu.cpu_ticks) { Array($0.bindMemory(to: UInt32.self)) }
            if ticks.count >= 4 {
                let total = ticks.prefix(4).reduce(UInt64(0)) { $0 + UInt64($1) }
                let busy = total - UInt64(ticks[2])
                if let before = previousCPU, total > before.total, busy >= before.busy {
                    cpuPercent = min(100, 100 * Double(busy - before.busy) / Double(total - before.total))
                    cpuUpdated = true
                }
                previousCPU = (busy, total)
            }
        }

        var vm = vm_statistics64_data_t()
        count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if vmResult == KERN_SUCCESS {
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            let available = Double(UInt64(vm.free_count) + UInt64(vm.inactive_count)) * Double(vm_kernel_page_size)
            let used = max(0, total - available)
            memoryPercent = total > 0 ? min(100, 100 * used / total) : 0
            memoryUsedGB = used / 1_073_741_824
        }

        if cpuUpdated {
            append(cpuPercent, to: &cpuHistory)
        }
        if vmResult == KERN_SUCCESS {
            append(memoryPercent, to: &memoryHistory)
        }

        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return }
        defer { freeifaddrs(first) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            let value = item.pointee
            if let addr = value.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               (value.ifa_flags & UInt32(IFF_LOOPBACK)) == 0, let data = value.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                received += UInt64(stats.ifi_ibytes)
                sent += UInt64(stats.ifi_obytes)
            }
            current = value.ifa_next
        }
        let now = Date()
        if let before = previousNetwork {
            let interval = now.timeIntervalSince(before.time)
            if interval > 0, received >= before.received, sent >= before.sent {
                downloadBytesPerSecond = Double(received - before.received) / interval
                uploadBytesPerSecond = Double(sent - before.sent) / interval
                append(downloadBytesPerSecond, to: &downloadHistory)
                append(uploadBytesPerSecond, to: &uploadHistory)
            }
        }
        previousNetwork = (received, sent, now)
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}
