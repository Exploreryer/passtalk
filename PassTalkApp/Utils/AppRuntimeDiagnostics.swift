import Foundation
import Darwin

enum AppRuntimeDiagnostics {
    private static let crashLogFileName = "passtalk_last_crash.log"
    static var signalLogFD: Int32 = -1
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true

        prepareSignalLogFile()
        installUncaughtExceptionHandler()
        installSignalHandlers()

        log("Runtime diagnostics installed.")
    }

    static func log(_ message: String) {
        let line = "[PassTalk] \(message)"
        fputs("\(line)\n", stderr)
    }

    static func lastCrashLog() -> String? {
        let url = crashLogURL()
        guard let data = try? Data(contentsOf: url),
              !data.isEmpty,
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return content
    }

    private static func installUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler(passtalk_uncaught_exception_handler)
    }

    private static func installSignalHandlers() {
        let fatalSignals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP]
        for signalCode in fatalSignals {
            signal(signalCode, passtalk_signal_handler)
        }
    }

    private static func prepareSignalLogFile() {
        let fileURL = crashLogURL()
        let parent = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        signalLogFD = open(fileURL.path, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)
        if signalLogFD < 0 {
            fputs("[PassTalk] Failed to open crash log file at \(fileURL.path)\n", stderr)
        }
    }

    private static func crashLogURL() -> URL {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return cache.appendingPathComponent(crashLogFileName)
    }
}

@_cdecl("passtalk_uncaught_exception_handler")
private func passtalk_uncaught_exception_handler(_ exception: NSException) {
    let stack = exception.callStackSymbols.joined(separator: "\n")
    AppRuntimeDiagnostics.log(
        "Uncaught NSException: \(exception.name.rawValue), reason: \(exception.reason ?? "none")\n\(stack)"
    )
}

@_cdecl("passtalk_signal_handler")
private func passtalk_signal_handler(_ signalCode: Int32) {
    let message = "PassTalk received fatal signal: \(signalCode)\n"
    message.withCString { ptr in
        write(STDERR_FILENO, ptr, strlen(ptr))
        if AppRuntimeDiagnostics.signalLogFD >= 0 {
            write(AppRuntimeDiagnostics.signalLogFD, ptr, strlen(ptr))
            fsync(AppRuntimeDiagnostics.signalLogFD)
        }
    }

    signal(signalCode, SIG_DFL)
    raise(signalCode)
}
