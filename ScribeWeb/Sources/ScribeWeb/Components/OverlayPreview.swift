import Ignite

struct OverlayPreview: HTML {
    var body: some HTML {
        Section {
            Text("Live Overlay Preview").class("preview-title")
            
            Section {
                // 1. Classic (220x220)
                Section {
                    Section {
                        Section {}.class("classic-ring ring-3")
                        Section {}.class("classic-ring ring-2")
                        Section {}.class("classic-ring ring-1")
                        Section {}.class("classic-center")
                        Section {
                            AnyHTML("""
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"></path></svg>
                            """)
                        }.class("classic-icon")
                    }.class("classic-rings")
                }.class("preview-overlay overlay-dot premium-glass")
                
                // 2. Waveform (480x72)
                Section {
                    Section {
                        Section {}.class("red-dot")
                    }.class("wave-status")
                    
                    Section {
                        AnyHTML("""
                        <div class="wave-bars-container">
                            <div class="bar h-1"></div><div class="bar h-2"></div><div class="bar h-3"></div>
                            <div class="bar h-4"></div><div class="bar h-2"></div><div class="bar h-1"></div>
                            <div class="bar h-5"></div><div class="bar h-4"></div><div class="bar h-2"></div>
                            <div class="bar h-3"></div><div class="bar h-5"></div><div class="bar h-2"></div>
                            <div class="bar h-1"></div><div class="bar h-3"></div><div class="bar h-4"></div>
                            <div class="bar h-5"></div><div class="bar h-2"></div><div class="bar h-1"></div>
                        </div>
                        """)
                    }.class("wave-center")
                    
                    Section {
                        Text("00:12").class("wave-time")
                    }.class("wave-right")
                }.class("preview-overlay overlay-waveform premium-glass active")
                
                // 3. Minimal (140x44)
                Section {
                    Section {}.class("red-dot")
                    Text("00:12").class("minimal-time")
                }.class("preview-overlay overlay-pill premium-glass")
                
                // 4. Pulse / ECG (260x64)
                Section {
                    Section {}.class("red-dot")
                    AnyHTML("""
                    <svg class="ecg-line" width="120" height="30" viewBox="0 0 120 30" fill="none" stroke="#34C759" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M0 15h20l10-10 10 20 10-20 10 20 10-10h50"></path>
                    </svg>
                    """)
                    Text("00:12").class("ecg-time")
                }.class("preview-overlay overlay-pulse premium-glass")
                
                // 5. Orb (200x200)
                Section {
                    Section {
                        Section {}.class("orb-shape")
                    }.class("orb-container")
                    Section {
                        AnyHTML("""
                        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"></path></svg>
                        """)
                    }.class("orb-icon")
                }.class("preview-overlay overlay-magic premium-glass")
                
            }.class("preview-desktop")
            
        }.class("overlay-preview-container")
    }
}
