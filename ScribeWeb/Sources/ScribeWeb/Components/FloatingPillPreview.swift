import Ignite

struct FloatingPillPreview: HTML {
    var body: some HTML {
        AnyHTML("""
        <div class="scribe-pill-wrapper" style="display: flex; flex-direction: column; align-items: center; justify-content: center; width: 100%;">
        """)
        
        Section {
            // Top Row
            Section {
                // Recording Dot
                Section {}.class("recording-dot")
                
                // Live Speech Waveform Bars matching photo (trailing dots + active voice bars)
                AnyHTML("""
                <div class='live-speech-waveform'>
                  <span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span>
                  <span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span>
                  <span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span>
                  <span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span>
                  <span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span><span class='dot'></span>
                  <span class='bar'></span><span class='bar'></span><span class='bar'></span><span class='bar'></span><span class='bar'></span>
                  <span class='bar'></span><span class='bar'></span><span class='bar'></span><span class='bar'></span><span class='bar'></span>
                  <span class='bar'></span><span class='bar'></span><span class='bar'></span><span class='bar'></span>
                  <span class='dot'></span><span class='dot'></span><span class='dot'></span>
                </div>
                """)
                
                // Target App Badge
                Section {
                    AnyHTML("<svg class='gemini-icon' width='12' height='12' viewBox='0 0 24 24'><defs><linearGradient id='gem' x1='0%' y1='0%' x2='100%' y2='100%'><stop offset='0%' stop-color='#FF4F54'/><stop offset='50%' stop-color='#4DA1FF'/><stop offset='100%' stop-color='#00D26A'/></linearGradient></defs><path d='M12 0C12 0 12.5 9.5 24 12C24 12 13 12.5 12 24C12 24 11.5 14.5 0 12C0 12 11 11.5 12 0Z' fill='url(#gem)'/></svg>")
                    AnyHTML("<span>Gemini</span>")
                }.class("target-app-badge")
                
                // Stop Button
                Section {
                    AnyHTML("<svg width='10' height='10' viewBox='0 0 10 10'><rect width='10' height='10' rx='2' fill='currentColor'/></svg>")
                }.class("pill-stop-btn")
            }.class("pill-top-row")
            
        }.class("scribe-pill", "dark-theme")
        
        // Transcription Text Area Outside
        AnyHTML("""
        <div class="scribe-pill-content-outside" style="margin-top: 16px; min-height: 44px; min-width: 100px;">
            <span id='pill-transcription-text' class='scribe-pill-text-outside'></span>
        </div>
        """)
        
        AnyHTML("""
        </div>
        """)
    }
}
