import Ignite

struct SettingsPanel: HTML {
    var body: some HTML {
        Section {
            Section {
                Section {
                    Section {}.class("mac-btn", "mac-close")
                    Section {}.class("mac-btn", "mac-min")
                    Section {}.class("mac-btn", "mac-max")
                    AnyHTML("<div class='mac-title'>Scribe Settings</div>")
                }.class("mac-titlebar")

                Section {
                    Section {
                        AnyHTML("""
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span style="font-family: ui-rounded, 'SF Pro Rounded', system-ui, sans-serif; font-weight: 900; font-size: 17px; letter-spacing: 1.5px; color: currentColor;">SCRIBE</span>
                        </div>
                        """)
                    }.class("settings-header")
                    
                    Section {
                        Section {
                            ThemeOption(id: "aurora", name: "Aurora")
                            ThemeOption(id: "ember", name: "Ember")
                            ThemeOption(id: "ocean", name: "Ocean")
                            ThemeOption(id: "lumina", name: "Lumina", isActive: true)
                            ThemeOption(id: "midnight", name: "Midnight")
                            ThemeOption(id: "emerald", name: "Emerald")
                        }.class("theme-row")
                        
                        SettingsRow(label: "Sound Feedback") { CustomToggle() }
                        SettingsRow(label: "Show Recording Timer") { CustomToggle() }
                        
                        SettingsRow(label: "Overlay Style") {
                            AnyHTML("""
                            <div class="segmented-control icons-control" id="overlayStyleControl">
                                <div class="segment" data-style="dot"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"></circle><circle cx="12" cy="12" r="3" fill="currentColor"></circle></svg></div>
                                <div class="segment active" data-style="waveform"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M8 9v6M16 9v6M4 12v1M20 12v1"></path></svg></div>
                                <div class="segment" data-style="pill"><svg width="22" height="14" viewBox="0 0 24 16" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="1" width="22" height="14" rx="7"></rect></svg></div>
                                <div class="segment" data-style="pulse"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 12h4l3-8 4 16 3-8h4"></path></svg></div>
                                <div class="segment" data-style="magic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2l2 6 6 2-6 2-2 6-2-6-6-2 6-2z"></path></svg></div>
                            </div>
                            """)
                        }
                        
                        SettingsRow(label: "Overlay Size") {
                            AnyHTML("""
                            <div class="segmented-control text-control">
                                <div class="segment" data-style="size-100">100%</div>
                                <div class="segment active" data-style="size-90">90%</div>
                                <div class="segment" data-style="size-80">80%</div>
                                <div class="segment" data-style="size-70">70%</div>
                            </div>
                            """)
                        }
                        
                        SettingsRow(label: "Panel Appearance", isLast: true) {
                            AnyHTML("""
                            <div class="segmented-control text-control appearance-control">
                                <div class="segment" data-style="panel-dark">
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>
                                    Dark
                                </div>
                                <div class="segment" data-style="panel-light">
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"></circle><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"></path></svg>
                                    Light
                                </div>
                                <div class="segment active glass-active" data-style="panel-glass">
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>
                                    Liquid Glass
                                </div>
                            </div>
                            """)
                        }
                    }.class("settings-panel")
                }
            }.class("mac-window")
        }.class("mac-window-wrapper")
    }
}

struct SettingsRow<Content: HTML>: HTML {
    var label: String
    var isLast: Bool = false
    @HTMLBuilder var content: () -> Content
    
    var body: some HTML {
        Section {
            Text(label).class("setting-label")
            content()
        }.class("setting-row" + (isLast ? " last" : ""))
    }
}

struct ThemeOption: HTML {
    var id: String
    var name: String
    var isActive: Bool = false
    
    var body: some HTML {
        Section {
            AnyHTML("""
            <div class="theme-circle theme-\(id)">
                \(isActive ? "<svg class='check-icon' width='20' height='20' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><polyline points='20 6 9 17 4 12'></polyline></svg>" : "")
            </div>
            """)
            AnyHTML("<span>\(name)</span>")
        }.class("theme-option").class(isActive ? "active" : "").customAttribute(name: "data-target", value: id)
    }
}

struct CustomToggle: HTML {
    var isActive: Bool = true
    
    var body: some HTML {
        Section {
            Section {}.class("toggle-knob")
        }.class("toggle").class(isActive ? "active" : "")
    }
}
