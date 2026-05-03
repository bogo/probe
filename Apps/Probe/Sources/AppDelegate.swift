import AppKit
import ProbeCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shiftModifierMask: UInt8 = 0x22
    private static let shiftRawKeycodes = Set(["KC_LEFT_SHIFT", "KC_RIGHT_SHIFT", "KC_LSFT", "KC_RSFT"])

    private var statusItem: NSStatusItem!
    private var panel: HUDPanel!
    private var hudView: KeyboardHUDView!
    private var hidMonitor: RawHIDMonitor?
    private let heatmapStore = HeatmapStore()
    private let hudSettingsStore = HUDSettingsStore()
    private let typingMetricsStore = TypingMetricsStore()
    private let appUpdater = AppUpdater()
    private let menuBarIconStore = MenuBarIconStore()

    private var keymap = LayeredKeymap.voyagerDefault(layers: [])
    private var hidDiagnostics = RawHIDDiagnostics()
    private var activeLayer = 0
    private var locked = true
    private var hudScale = HUDSettings.defaultScale
    private var hudOpacity = HUDSettings.defaultOpacity
    private var showsHeatmap = HUDSettings.defaultShowsHeatmap
    private var showsTypingStats = HUDSettings.defaultShowsTypingStats
    private var usesSymbolicKeyLabels = HUDSettings.defaultUsesSymbolicKeyLabels
    private var keyboardColorTheme = HUDSettings.defaultKeyboardColorTheme
    private var heatmapColorTheme = HUDSettings.defaultHeatmapColorTheme
    private var graphColorTheme = HUDSettings.defaultGraphColorTheme
    private var userWantsHUDVisible = true
    private var keyboardConnected = false
    private var hasUsableKeymap = false
    private var pressedKeys = Set<Int>()
    private var pressedShiftKeys = Set<Int>()
    private var activeModifiers: UInt8 = 0
    private var samplePulseTask: Task<Void, Never>?
    private var metricsRefreshTimer: Timer?
    private var onboardingController: KeymapOnboardingWindowController?
    private var settingsController: ProbeSettingsWindowController?
    private var menuBarIcon = MenuBarIconChoice.defaultChoice

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarIcon = menuBarIconStore.load()
        keymap = KeymapSourceLoader.load()
        hasUsableKeymap = !keymap.layers.isEmpty
        configurePanel()
        configureStatusItem()
        configureHID()
        configureMetricsRefresh()
        updateHUD()
        syncHUDVisibility()
        showKeymapOnboardingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        try? heatmapStore.save()
        saveHUDSettings()
        metricsRefreshTimer?.invalidate()
        hidMonitor?.stop()
    }

    private func configurePanel() {
        let settings = hudSettingsStore.load()
        hudScale = settings.scale
        hudOpacity = settings.opacity
        showsHeatmap = settings.showsHeatmap
        showsTypingStats = settings.showsTypingStats
        usesSymbolicKeyLabels = settings.usesSymbolicKeyLabels
        keyboardColorTheme = settings.keyboardColorTheme
        heatmapColorTheme = settings.heatmapColorTheme
        graphColorTheme = settings.graphColorTheme

        panel = HUDPanel(contentRect: settings.frame)
        panel.delegate = self
        panel.ignoresMouseEvents = locked
        panel.alphaValue = hudOpacity

        hudView = KeyboardHUDView(frame: NSRect(origin: .zero, size: settings.frame.size))
        hudView.autoresizingMask = [.width, .height]
        hudView.onKeymapDropped = { [weak self] url in
            self?.importKeymap(at: url)
        }
        panel.contentView = hudView
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setStatusItemIcon(.normal)
        rebuildMenu()
    }

    private func configureHID() {
        hidMonitor = RawHIDMonitor(
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            },
            onDiagnostics: { [weak self] diagnostics in
                Task { @MainActor in
                    self?.handle(diagnostics)
                }
            }
        )
        hidMonitor?.start()
    }

    private func handle(_ diagnostics: RawHIDDiagnostics) {
        let wasConnected = keyboardConnected
        hidDiagnostics = diagnostics
        keyboardConnected = diagnostics.isKeyboardConnected
        updateStatusTooltip()

        if keyboardConnected != wasConnected {
            handleKeyboardConnectionChange()
        }
    }

    private func handleKeyboardConnectionChange() {
        if !keyboardConnected {
            clearLiveInputState()
            updateHUD()
        }
        syncHUDVisibility()
    }

    private func configureMetricsRefresh() {
        metricsRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.showsTypingStats else { return }
                self.updateHUD()
            }
        }
    }

    private func handle(_ event: TelemetryEvent) {
        switch event {
        case .key(let keyEvent):
            if keyEvent.activeLayer != TelemetryCodec.unspecifiedActiveLayer {
                activeLayer = keyEvent.activeLayer
            }
            activeModifiers = keyEvent.mods | keyEvent.oneShotMods
            guard let keyID = keymap.keyID(row: keyEvent.matrixRow, column: keyEvent.matrixColumn) else {
                return
            }
            if keyEvent.pressed {
                pressedKeys.insert(keyID)
                if keyActsAsShift(keyID) {
                    pressedShiftKeys.insert(keyID)
                }
                heatmapStore.recordKeyDown(layer: activeLayer, keyID: keyID)
                if hasUsableKeymap {
                    typingMetricsStore.record(label: keymap.resolvedLabel(forKeyID: keyID, onLayer: activeLayer))
                }
            } else {
                let wasShiftKey = pressedShiftKeys.contains(keyID)
                pressedKeys.remove(keyID)
                pressedShiftKeys.remove(keyID)
                if wasShiftKey || keyActsAsShift(keyID) {
                    activeModifiers &= ~Self.shiftModifierMask
                }
            }
        case .layer(let layerEvent), .hello(let layerEvent):
            activeLayer = layerEvent.activeLayer
        }
        updateHUD()
    }

    private func updateHUD() {
        hudView.keymap = keymap
        hudView.activeLayer = activeLayer
        hudView.shiftActive = shiftActive
        hudView.pressedKeys = pressedKeys
        hudView.heatmap = heatmapStore.snapshot()
        hudView.showsHeatmap = showsHeatmap
        hudView.showsTypingStats = showsTypingStats
        hudView.usesSymbolicKeyLabels = usesSymbolicKeyLabels
        hudView.colorTheme = keyboardColorTheme
        hudView.heatmapColorTheme = heatmapColorTheme
        hudView.graphColorTheme = graphColorTheme
        hudView.typingMetrics = typingMetricsStore.snapshot()
        hudView.needsDisplay = true
    }

    private func clearLiveInputState() {
        pressedKeys.removeAll()
        pressedShiftKeys.removeAll()
        activeModifiers = 0
        activeLayer = 0
        samplePulseTask?.cancel()
        samplePulseTask = nil
    }

    private var shiftActive: Bool {
        activeModifiers & Self.shiftModifierMask != 0 || !pressedShiftKeys.isEmpty
    }

    private func keyActsAsShift(_ keyID: Int) -> Bool {
        let label = keymap.resolvedLabel(forKeyID: keyID, onLayer: activeLayer)
        switch label.role {
        case .modifier:
            return label.primary == "Shift" || Self.shiftRawKeycodes.contains(label.raw)
        case .modTap:
            return label.primary == "Shift"
                || label.secondary?.split(separator: "+").contains { $0 == "Shift" } == true
        default:
            return false
        }
    }

    private func rebuildMenu() {
        let menu = statusItem.menu ?? NSMenu()
        menu.removeAllItems()
        menu.delegate = self
        menu.addItem(hudVisibilityMenuItem())
        menu.addItem(NSMenuItem(title: locked ? "Unlock Position and Drops" : "Lock Position", action: #selector(toggleLock), keyEquivalent: ""))

        let opacityMenu = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let opacitySubmenu = NSMenu()
        let selectedOpacity = HUDOpacityChoice.nearest(to: hudOpacity)
        addMenuItem(
            HUDOpacityChoice.translucent.title,
            action: #selector(setOpacity45),
            to: opacitySubmenu,
            state: selectedOpacity == .translucent ? .on : .off
        )
        addMenuItem(
            HUDOpacityChoice.balanced.title,
            action: #selector(setOpacity65),
            to: opacitySubmenu,
            state: selectedOpacity == .balanced ? .on : .off
        )
        addMenuItem(
            HUDOpacityChoice.vivid.title,
            action: #selector(setOpacity85),
            to: opacitySubmenu,
            state: selectedOpacity == .vivid ? .on : .off
        )
        menu.setSubmenu(opacitySubmenu, for: opacityMenu)
        menu.addItem(opacityMenu)

        let scaleMenu = NSMenuItem(title: "Scale", action: nil, keyEquivalent: "")
        let scaleSubmenu = NSMenu()
        let selectedScale = HUDScaleChoice.nearest(to: hudScale)
        addMenuItem(
            HUDScaleChoice.small.title,
            action: #selector(setScaleSmall),
            to: scaleSubmenu,
            state: selectedScale == .small ? .on : .off
        )
        addMenuItem(
            HUDScaleChoice.medium.title,
            action: #selector(setScaleMedium),
            to: scaleSubmenu,
            state: selectedScale == .medium ? .on : .off
        )
        addMenuItem(
            HUDScaleChoice.large.title,
            action: #selector(setScaleLarge),
            to: scaleSubmenu,
            state: selectedScale == .large ? .on : .off
        )
        menu.setSubmenu(scaleSubmenu, for: scaleMenu)
        menu.addItem(scaleMenu)

        let displayMenu = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displaySubmenu = NSMenu()
        addMenuItem(showsHeatmap ? "Hide Heatmap" : "Show Heatmap", action: #selector(toggleHeatmap), to: displaySubmenu)
        addMenuItem(showsTypingStats ? "Hide Typing Stats" : "Show Typing Stats", action: #selector(toggleTypingStats), to: displaySubmenu)
        addMenuItem(usesSymbolicKeyLabels ? "Use Text Key Labels" : "Use macOS Key Glyphs", action: #selector(toggleSymbolicKeyLabels), to: displaySubmenu)
        menu.setSubmenu(displaySubmenu, for: displayMenu)
        menu.addItem(displayMenu)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Import Keymap...", action: #selector(importKeymapFromPanel), keyEquivalent: ""))
        menu.addItem(debugMenuItem())
        menu.addItem(.separator())
        menu.addItem(settingsMenuItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Reset Session Heatmap", action: #selector(resetSessionHeatmap), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset All-Time Heatmap", action: #selector(resetAllTimeHeatmap), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(appUpdater.checkForUpdatesMenuItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Probe", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func addMenuItem(
        _ title: String,
        action: Selector,
        to menu: NSMenu,
        state: NSControl.StateValue = .off
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = state
        menu.addItem(item)
    }

    private func addDisabledMenuItem(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func hudVisibilityMenuItem() -> NSMenuItem {
        let title: String
        if keyboardConnected {
            title = userWantsHUDVisible ? "Hide HUD" : "Show HUD"
        } else {
            title = userWantsHUDVisible ? "Hide HUD When Connected" : "Show HUD When Connected"
        }

        let item = NSMenuItem(title: title, action: #selector(toggleHUD), keyEquivalent: "")
        item.target = self
        return item
    }

    private func settingsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        item.target = self
        return item
    }

    private func debugMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "HID Diagnostics", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        addDisabledMenuItem("Raw HID: \(hidDiagnostics.connectionSummary)", to: submenu)
        addDisabledMenuItem("Keymap: \(hasUsableKeymap ? "Imported" : "Not imported")", to: submenu)
        addDisabledMenuItem("Telemetry: \(hidDiagnostics.telemetrySummary)", to: submenu)
        addDisabledMenuItem("Open: \(hidDiagnostics.openResult)", to: submenu)
        addDisabledMenuItem("Matched Devices: \(hidDiagnostics.matchedDeviceCount)", to: submenu)
        addDisabledMenuItem("Registered Devices: \(hidDiagnostics.registeredDeviceCount)", to: submenu)
        addDisabledMenuItem("Reports: \(hidDiagnostics.reportsReceived)", to: submenu)
        addDisabledMenuItem("Decoded: \(hidDiagnostics.decodedReports)", to: submenu)
        addDisabledMenuItem("Rejected: \(hidDiagnostics.rejectedReports)", to: submenu)
        addDisabledMenuItem("Last Packet: \(hidDiagnostics.lastPacketSummary)", to: submenu)
        addDisabledMenuItem("Last Event: \(hidDiagnostics.lastEventSummary)", to: submenu)
        submenu.addItem(.separator())
        addMenuItem("Request Live View Pairing", action: #selector(requestLiveViewPairing), to: submenu)
        addMenuItem("Pulse Sample Key", action: #selector(pulseSampleKey), to: submenu)
        addMenuItem("Copy Debug Info", action: #selector(copyHIDDebugInfo), to: submenu)
        item.submenu = submenu
        return item
    }

    @objc private func toggleHUD() {
        userWantsHUDVisible.toggle()
        syncHUDVisibility()
    }

    @objc private func toggleLock() {
        locked.toggle()
        panel.ignoresMouseEvents = locked
        panel.isMovableByWindowBackground = !locked
        rebuildMenu()
    }

    @objc private func setOpacity45() { setOpacity(HUDOpacityChoice.translucent.value) }
    @objc private func setOpacity65() { setOpacity(HUDOpacityChoice.balanced.value) }
    @objc private func setOpacity85() { setOpacity(HUDOpacityChoice.vivid.value) }

    private func setOpacity(_ opacity: CGFloat) {
        hudOpacity = opacity
        panel.alphaValue = opacity
        saveHUDSettings()
        rebuildMenu()
        settingsController?.update(state: currentSettingsState)
    }

    @objc private func setScaleSmall() { setScale(HUDScaleChoice.small.value) }
    @objc private func setScaleMedium() { setScale(HUDScaleChoice.medium.value) }
    @objc private func setScaleLarge() { setScale(HUDScaleChoice.large.value) }

    private func setScale(_ scale: CGFloat) {
        hudScale = scale
        let currentCenter = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        let newSize = NSSize(width: 900 * scale, height: 360 * scale)
        let newOrigin = CGPoint(x: currentCenter.x - newSize.width / 2, y: currentCenter.y - newSize.height / 2)
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: true)
        saveHUDSettings(frame: NSRect(origin: newOrigin, size: newSize))
        rebuildMenu()
        settingsController?.update(state: currentSettingsState)
    }

    private func syncHUDVisibility() {
        if userWantsHUDVisible && keyboardConnected {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        rebuildMenu()
    }

    private func saveHUDSettings(frame: NSRect? = nil) {
        guard panel != nil else { return }
        hudSettingsStore.save(
            HUDSettings(
                frame: frame ?? panel.frame,
                scale: hudScale,
                opacity: hudOpacity,
                showsHeatmap: showsHeatmap,
                showsTypingStats: showsTypingStats,
                usesSymbolicKeyLabels: usesSymbolicKeyLabels,
                keyboardColorTheme: keyboardColorTheme,
                heatmapColorTheme: heatmapColorTheme,
                graphColorTheme: graphColorTheme
            )
        )
    }

    @objc private func toggleHeatmap() {
        setHeatmapVisible(!showsHeatmap)
    }

    private func setHeatmapVisible(_ enabled: Bool) {
        showsHeatmap = enabled
        saveHUDSettings()
        updateHUD()
        rebuildMenu()
        settingsController?.update(state: currentSettingsState)
    }

    @objc private func toggleSymbolicKeyLabels() {
        setSymbolicKeyLabels(!usesSymbolicKeyLabels)
    }

    private func setSymbolicKeyLabels(_ enabled: Bool) {
        usesSymbolicKeyLabels = enabled
        saveHUDSettings()
        updateHUD()
        rebuildMenu()
        settingsController?.update(state: currentSettingsState)
    }

    @objc private func toggleTypingStats() {
        setTypingStatsVisible(!showsTypingStats)
    }

    private func setTypingStatsVisible(_ enabled: Bool) {
        showsTypingStats = enabled
        saveHUDSettings()
        updateHUD()
        rebuildMenu()
        settingsController?.update(state: currentSettingsState)
    }

    @objc private func importKeymapFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = KeymapImportSupport.panelContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.importKeymap(at: url)
        }
    }

    private func importKeymap(at url: URL) {
        do {
            keymap = try KeymapSourceLoader.importKeymap(at: url)
            hasUsableKeymap = true
            activeLayer = min(activeLayer, max(0, keymap.layers.count - 1))
            pressedKeys.formIntersection(Set(keymap.physicalKeys.map(\.id)))
            pressedShiftKeys.formIntersection(pressedKeys)
            updateHUD()
            settingsController?.update(state: currentSettingsState)
            dismissKeymapOnboarding(markDismissed: true)
            syncHUDVisibility()
            showStatusItemFlash(.success)
        } catch {
            showStatusItemFlash(.failure)
            NSSound.beep()
        }
    }

    private func showKeymapOnboardingIfNeeded() {
        guard !KeymapSourceLoader.hasUsableImportedKeymap,
            !UserDefaults.standard.bool(forKey: OnboardingDefaults.keymapPromptDismissed)
        else {
            return
        }

        let controller = KeymapOnboardingWindowController(
            onImport: { [weak self] url in
                self?.importKeymap(at: url)
            },
            onChoose: { [weak self] in
                self?.importKeymapFromPanel()
            },
            onSkip: { [weak self] in
                self?.dismissKeymapOnboarding(markDismissed: true)
            }
        )
        onboardingController = controller
        controller.window?.center()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissKeymapOnboarding(markDismissed: Bool) {
        if markDismissed {
            UserDefaults.standard.set(true, forKey: OnboardingDefaults.keymapPromptDismissed)
        }
        onboardingController?.close()
        onboardingController = nil
    }

    private func showStatusItemFlash(_ icon: StatusItemIcon) {
        setStatusItemIcon(icon)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            setStatusItemIcon(.normal)
        }
    }

    private func setStatusItemIcon(_ icon: StatusItemIcon) {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.image = icon.image(menuBarIcon: menuBarIcon)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = statusTooltip(for: icon)
    }

    private func updateStatusTooltip() {
        guard let button = statusItem?.button else { return }
        button.toolTip = statusTooltip(for: .normal)
    }

    private func statusTooltip(for icon: StatusItemIcon) -> String {
        "\(icon.tooltip)\nRaw HID: \(hidDiagnostics.connectionSummary)\nReports: \(hidDiagnostics.reportsReceived), Decoded: \(hidDiagnostics.decodedReports)"
    }

    @objc private func pulseSampleKey() {
        samplePulseTask?.cancel()
        let keyID =
            keymap.physicalKeys.first { key in
                keymap.resolvedLabel(forKeyID: key.id, onLayer: activeLayer).primary == "A"
            }?.id ?? keymap.physicalKeys.first?.id

        guard let keyID else { return }
        pressedKeys.insert(keyID)
        updateHUD()

        samplePulseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            pressedKeys.remove(keyID)
            updateHUD()
        }
    }

    @objc private func requestLiveViewPairing() {
        hidMonitor?.requestLiveViewPairing()
    }

    @objc private func copyHIDDebugInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hidDiagnostics.pasteboardReport, forType: .string)
        showStatusItemFlash(.success)
    }

    @objc private func resetSessionHeatmap() {
        heatmapStore.resetSession()
        updateHUD()
    }

    @objc private func resetAllTimeHeatmap() {
        heatmapStore.resetAllTime()
        updateHUD()
    }

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = ProbeSettingsWindowController(
                state: currentSettingsState,
                onIconSelected: { [weak self] choice in
                    self?.setMenuBarIcon(choice)
                },
                onSymbolicKeyLabelsChanged: { [weak self] enabled in
                    self?.setSymbolicKeyLabels(enabled)
                },
                onKeyboardColorThemeChanged: { [weak self] theme in
                    self?.setKeyboardColorTheme(theme)
                },
                onHeatmapColorThemeChanged: { [weak self] theme in
                    self?.setHeatmapColorTheme(theme)
                },
                onGraphColorThemeChanged: { [weak self] theme in
                    self?.setGraphColorTheme(theme)
                },
                onScaleChanged: { [weak self] scale in
                    self?.setScale(scale)
                },
                onOpacityChanged: { [weak self] opacity in
                    self?.setOpacity(opacity)
                },
                onHeatmapVisibilityChanged: { [weak self] enabled in
                    self?.setHeatmapVisible(enabled)
                },
                onTypingStatsVisibilityChanged: { [weak self] enabled in
                    self?.setTypingStatsVisible(enabled)
                },
                onImportKeymap: { [weak self] in
                    self?.importKeymapFromPanel()
                },
                onImportKeymapAt: { [weak self] url in
                    self?.importKeymap(at: url)
                }
            )
        }

        settingsController?.update(state: currentSettingsState)
        settingsController?.window?.center()
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var currentSettingsState: ProbeSettingsState {
        ProbeSettingsState(
            selectedIcon: menuBarIcon,
            usesSymbolicKeyLabels: usesSymbolicKeyLabels,
            keyboardColorTheme: keyboardColorTheme,
            heatmapColorTheme: heatmapColorTheme,
            graphColorTheme: graphColorTheme,
            scale: hudScale,
            opacity: hudOpacity,
            showsHeatmap: showsHeatmap,
            showsTypingStats: showsTypingStats,
            keymap: keymap,
            activeLayer: activeLayer,
            hasUsableKeymap: hasUsableKeymap
        )
    }

    private func setMenuBarIcon(_ choice: MenuBarIconChoice) {
        menuBarIcon = choice
        menuBarIconStore.save(choice)
        setStatusItemIcon(.normal)
    }

    private func setKeyboardColorTheme(_ theme: KeyboardColorTheme) {
        keyboardColorTheme = theme
        saveHUDSettings()
        updateHUD()
        settingsController?.update(state: currentSettingsState)
    }

    private func setHeatmapColorTheme(_ theme: HeatmapColorTheme) {
        heatmapColorTheme = theme
        saveHUDSettings()
        updateHUD()
        settingsController?.update(state: currentSettingsState)
    }

    private func setGraphColorTheme(_ theme: GraphColorTheme) {
        graphColorTheme = theme
        saveHUDSettings()
        updateHUD()
        settingsController?.update(state: currentSettingsState)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        saveHUDSettings()
    }

    func windowDidResize(_ notification: Notification) {
        saveHUDSettings()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}

private enum StatusItemIcon {
    case normal
    case success
    case failure

    var tooltip: String {
        switch self {
        case .normal:
            "Probe"
        case .success:
            "Probe imported keymap"
        case .failure:
            "Probe could not import keymap"
        }
    }

    func image(menuBarIcon: MenuBarIconChoice) -> NSImage? {
        if self == .normal, let statusImage = menuBarIcon.image(pointSize: 20) {
            return statusImage
        }

        let image =
            symbolNames.lazy
            .compactMap { NSImage(systemSymbolName: $0, accessibilityDescription: tooltip) }
            .first
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }

    private var symbolNames: [String] {
        switch self {
        case .normal:
            [
                "antenna.radiowaves.left.and.right",
                "dot.radiowaves.left.and.right",
                "paperplane.fill",
                "paperplane"
            ]
        case .success:
            ["checkmark.circle.fill", "checkmark.circle"]
        case .failure:
            ["exclamationmark.triangle.fill", "exclamationmark.triangle"]
        }
    }

}

private enum OnboardingDefaults {
    static let keymapPromptDismissed = "onboarding.keymapPromptDismissed"
}
