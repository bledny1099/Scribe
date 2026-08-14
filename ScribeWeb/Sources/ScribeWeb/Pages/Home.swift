import Ignite

struct Home: StaticPage {
    var title = "Scribe - Fast and Accurate Voice Dictation"
    
    var body: some HTML {
        Section {
            // Navbar
            Section {
                Section {
                    Text("Scribe").class("aqua-logo")
                    Section {
                        Link("Features", target: "#features").class("aqua-nav-link")
                        Link("Design", target: "#design").class("aqua-nav-link")
                        Link("Demo", target: "#demo").class("aqua-nav-link")
                        Link("Pricing", target: "#pricing").class("aqua-nav-link")
                        Link("Download for Mac", target: "#").class("aqua-btn", "aqua-btn-secondary")
                    }.class("aqua-nav-links")
                }.class("aqua-container", "aqua-nav-inner")
            }.class("aqua-nav")
            
            // Splash Screen Overlay
            AnyHTML("""
            <div id="splash-screen">
                <div class="splash-content-large">
                    <h1 class="splash-title">Hello, Explorer!</h1>
                    <p class="splash-subtitle">Time to save time.</p>
                </div>
            </div>
            """)
            
            // Hero Section (with restored text)
            Section {
                Section {
                    Text("Now live on Mac").class("aqua-hero-badge")
                    
                    AnyHTML("""
                    <h1 class="aqua-hero-title" style="font-size: 72px; font-weight: 800; line-height: 1.05; letter-spacing: -2px; margin: 0 auto 24px; max-width: 900px;">
                        Your voice.<br>Instantly written.
                    </h1>
                    <p class="aqua-hero-subtitle" style="font-size: 20px; color: var(--aqua-text-muted); max-width: 600px; margin: 0 auto 40px;">
                        Scribe turns your voice into clear text in real time, for everything from AI prompts to essays.
                    </p>
                    <div class="hero-actions">
                        <a href="#pricing" class="aqua-btn" style="background: var(--aqua-text); color: var(--aqua-bg);">Download for Mac</a>
                        <a href="#demo" class="aqua-btn aqua-btn-secondary">Watch Demo</a>
                    </div>
                    """)
                }.class("hero-text-content")
            }.class("aqua-hero", "aqua-container")
            
            // Interactive Demo Section
            Section {
                AnyHTML("""
                <div class="demo-section-header">
                    <h2>See it in action</h2>
                    <p>Dictate anywhere. Scribe types it instantly.</p>
                </div>
                <div class="demo-desktop-environment" style="position: relative; background: linear-gradient(to bottom, #001f3f, #3a8dff); border-radius: 20px; overflow: hidden;">
                    <!-- Desktop Area -->
                    <div class="desktop-workspace">
                        <div class="demo-mac-window" style="max-width: 900px; width: 90%;">
                            <div class="mac-window-header">
                                <div class="mac-btns">
                                    <span></span><span></span><span></span>
                                </div>
                                <div class="mac-title">Notes</div>
                            </div>
                            <div class="mac-window-body">
                                <div class="demo-typing-area" id="demo-text"></div>
                            </div>
                        </div>
                        
                        <!-- Global Scribe Overlay -->
                        <div class="global-demo-overlay" id="demo-overlay">
                            <div class="scribe-overlay-wrapper">
                                <!-- Main Pill -->
                                <div class="scribe-overlay-main premium-glass">
                                    <div class="overlay-left">
                                        <div class="recording-dot pulse"></div>
                                    </div>
                                    <div class="overlay-center">
                                        <div class="wave-bars-container">
                                            <div class="bar h-1"></div><div class="bar h-2"></div><div class="bar h-4"></div>
                                            <div class="bar h-5"></div><div class="bar h-3"></div><div class="bar h-1"></div>
                                            <div class="bar h-4"></div><div class="bar h-2"></div><div class="bar h-5"></div>
                                            <div class="bar h-3"></div><div class="bar h-1"></div><div class="bar h-4"></div>
                                        </div>
                                    </div>
                                    <div class="overlay-right">
                                        <div class="app-indicator">
                                            <div class="app-icon finder-icon"></div>
                                            <span class="app-name">Finder</span>
                                        </div>
                                        <button class="stop-btn">
                                            <div class="stop-square"></div>
                                        </button>
                                    </div>
                                </div>
                                <!-- Sub Pill for transcription -->
                                <div class="scribe-overlay-sub premium-glass">
                                    <div class="transcription-text" id="demo-sub-text"></div>
                                </div>
                            </div>
                        </div>
                        
                        <!-- macOS Dock -->
                        <div class="desktop-dock">
                            <div class="dock-icon notes" title="Notes"></div>
                            <div class="dock-icon gemini" title="Gemini"></div>
                            <div class="dock-icon antigravity" title="Antigravity"></div>
                        </div>
                    </div>

                    <!-- Full-Environment Blur Start Overlay (Placed last so backdrop-filter blurs everything) -->
                    <div class="demo-start-overlay" id="demo-start-overlay">
                        <button class="aqua-btn" id="start-demo-btn">Simulate Dictation</button>
                    </div>
                </div>
                """)
            }.class("aqua-demo-section", "aqua-container").id("demo")

            Section {
                AnyHTML("<h2 class='aqua-section-title reveal-on-scroll reveal-stagger-1'>Type at the speed of thought. Flawless accuracy.</h2>")
                
                Section {
                    Section {
                        Text("Using Scribe AI").class("aqua-speed-header")
                        Text("230 WPM").class("aqua-speed-wpm")
                        AnyHTML("<p class='aqua-speed-text'>Make a new React component called TaskDashboard. Add a useState hook for selectedTaskId initialized to null, and another for isSidebarOpen set to true.</p>")
                    }.class("aqua-speed-card", "reveal-on-scroll", "reveal-stagger-2")
                    
                    Section {
                        Text("Using Keyboard").class("aqua-speed-header")
                        Text("40 WPM").class("aqua-speed-wpm")
                        AnyHTML("<p class='aqua-speed-text'>Make a new React component called TaskDashboard. Add a <strike>useStateuseStateusestale</strike> hook for selectedTaskId initialized to null, and another for isSidebarOpen set to true.</p>")
                    }.class("aqua-speed-card", "reveal-on-scroll", "reveal-stagger-3")
                }.class("aqua-speed-section")
            }.class("aqua-container")
            
            // Bento Grid Features
            Section {
                Section {
                    // Feature 1 (Span 2 for asymmetric layout)
                    Section {
                        Section {
                            AnyHTML("⚡️")
                        }.class("aqua-bento-icon")
                        AnyHTML("<h3>Works with all your apps</h3>")
                        AnyHTML("<p>Fits naturally into every app you use each day, without setup or friction. Instantly output text directly into your favorite editors.</p>")
                    }.class("aqua-bento-card", "aqua-bento-span-2", "aqua-bento-card-premium", "reveal-on-scroll", "reveal-stagger-1")
                    
                    // Feature 2
                    Section {
                        Section {
                            AnyHTML("🧠")
                        }.class("aqua-bento-icon")
                        AnyHTML("<h3>Your thoughts set the pace</h3>")
                        AnyHTML("<p>Keeps up with your ideas so you can focus on thinking, not typing.</p>")
                    }.class("aqua-bento-card", "aqua-bento-card-premium", "reveal-on-scroll", "reveal-stagger-2")
                    
                    // Feature 3
                    Section {
                        Section {
                            AnyHTML("💻")
                        }.class("aqua-bento-icon")
                        AnyHTML("<h3>Active App Context</h3>")
                        AnyHTML("<p>Detects which app you are typing in—like Xcode, Slack, or Notion—and adapts its formatting rules automatically.</p>")
                    }.class("aqua-bento-card", "aqua-bento-card-premium", "reveal-on-scroll", "reveal-stagger-3")
                }.class("aqua-bento")
            }.class("aqua-features", "aqua-container").id("features")
            
            // Coding & Prompting
            Section {
                AnyHTML("<h2 class='aqua-section-title reveal-on-scroll reveal-stagger-1' style='margin-top: 60px;'>Coding & Prompting</h2>")
                AnyHTML("<p class='reveal-on-scroll reveal-stagger-2' style='text-align: center; font-size: 20px; color: var(--aqua-text-muted); max-width: 700px; margin: 0 auto;'>Speak your ideas into existence with ease. Scribe understands syntax, libraries, and frameworks as you speak.</p>")
                
                Section {
                    Section {
                        Section {}.class("aqua-terminal-dot", "dot-red")
                        Section {}.class("aqua-terminal-dot", "dot-yellow")
                        Section {}.class("aqua-terminal-dot", "dot-green")
                    }.class("aqua-terminal-header")
                    
                    AnyHTML("""
                    <div class='aqua-terminal-content'>
                        <span class="keyword">function</span> <span class="function">calculateROI</span>(investment, return) {<br>
                        &nbsp;&nbsp;<span class="keyword">if</span> (!investment || !return) <span class="keyword">return</span> <span class="string">'Error: Invalid inputs'</span>;<br>
                        &nbsp;&nbsp;<span class="comment">// Scribe transcribed this effortlessly without any typos</span><br>
                        &nbsp;&nbsp;<span class="keyword">return</span> ((return - investment) / investment) * 100;<br>
                        }
                    </div>
                    """)
                }.class("aqua-terminal", "reveal-on-scroll", "reveal-stagger-3")
            }.class("aqua-container")
            
            // Productivity Grid
            Section {
                Section {
                    Section {
                        Text("6h 23m").class("aqua-metric-value")
                        Text("Saved coding weekly").class("aqua-metric-label")
                    }.class("aqua-metric-card", "reveal-on-scroll", "reveal-stagger-1")
                    
                    Section {
                        Text("230 WPM").class("aqua-metric-value")
                        Text("Write 5 times faster").class("aqua-metric-label")
                    }.class("aqua-metric-card", "reveal-on-scroll", "reveal-stagger-2")
                    
                    Section {
                        Text("47s").class("aqua-metric-value")
                        Text("Average reply time").class("aqua-metric-label")
                    }.class("aqua-metric-card", "reveal-on-scroll", "reveal-stagger-3")
                }.class("aqua-metrics")
            }.class("aqua-container")
            
            // Feature Grid 1-6
            Section {
                AnyHTML("<h2 class='aqua-section-title reveal-on-scroll reveal-stagger-1'>Built for the way you work</h2>")
                
                Section {
                    Section {
                        Text("[01]").class("aqua-grid-item-num")
                        AnyHTML("<h3>Powered by WhisperKit</h3>")
                        AnyHTML("<p>Scribe runs locally on your Mac using WhisperKit for 100% offline privacy and zero latency dictation.</p>")
                    }.class("aqua-grid-item", "reveal-on-scroll", "reveal-stagger-1")
                    
                    Section {
                        Text("[02]").class("aqua-grid-item-num")
                        AnyHTML("<h3>Custom Vocabulary</h3>")
                        AnyHTML("<p>Teach Scribe technical terms, crypto names like Binance or Bybit, and watch accuracy improve instantly.</p>")
                    }.class("aqua-grid-item", "reveal-on-scroll", "reveal-stagger-2")
                    
                    Section {
                        Text("[03]").class("aqua-grid-item-num")
                        AnyHTML("<h3>Smart LLM Refinement</h3>")
                        AnyHTML("<p>Turn raw voice into Key Summaries, Executive Tone, Action Items, or fluent English Translation on the fly.</p>")
                    }.class("aqua-grid-item", "reveal-on-scroll", "reveal-stagger-3")
                    
                    Section {
                        Text("[04]").class("aqua-grid-item-num")
                        AnyHTML("<h3>Filler Word Cleaner</h3>")
                        AnyHTML("<p>Automatically cleans speech hesitations like \"uh\", \"um\", and duplicate words for a perfectly polished transcript.</p>")
                    }.class("aqua-grid-item", "reveal-on-scroll", "reveal-stagger-1")
                    
                    Section {
                        Text("[05]").class("aqua-grid-item-num")
                        AnyHTML("<h3>100% Private</h3>")
                        AnyHTML("<p>In Free mode, processing is entirely local. Your voice data never leaves your device, keeping your secrets safe.</p>")
                    }.class("aqua-grid-item", "reveal-on-scroll", "reveal-stagger-2")
                    
                    Section {
                        Text("[06]").class("aqua-grid-item-num")
                        AnyHTML("<h3>Global Hotkey</h3>")
                        AnyHTML("<p>Press Option + S from anywhere to start recording. A beautiful liquid glass panel gives you real-time visual feedback.</p>")
                    }.class("aqua-grid-item", "reveal-on-scroll", "reveal-stagger-3")
                }.class("aqua-grid-6")
            }.class("aqua-container").id("design")
            
            // Pricing
            Section {
                AnyHTML("<h2 class='aqua-section-title reveal-on-scroll reveal-stagger-1'>Pricing</h2>")
                
                Section {
                    Section {
                        Text("Scribe Free").class("aqua-pricing-title")
                        Text("$0 / month").class("aqua-pricing-subtitle")
                        AnyHTML("""
                        <ul class="aqua-pricing-features">
                            <li>100% Local WhisperKit Dictation</li>
                            <li>Zero Data Leaves Your Mac</li>
                            <li>Custom Vocabulary & Auto-Casing</li>
                            <li>Global Hotkey Access</li>
                        </ul>
                        """)
                        Link("Download for Mac", target: "#").class("aqua-btn", "aqua-btn-secondary")
                    }.class("aqua-pricing-card", "reveal-on-scroll", "reveal-stagger-1")
                    
                    Section {
                        Text("Scribe Pro Cloud").class("aqua-pricing-title")
                        Text("$4.99 / month").class("aqua-pricing-subtitle")
                        AnyHTML("""
                        <ul class="aqua-pricing-features">
                            <li>Ultra-Fast Cloud Whisper (Groq & OpenAI)</li>
                            <li>Smart LLM Voice Refinement</li>
                            <li>Priority Cloud Gateway</li>
                            <li>Cross-Device Google OAuth</li>
                        </ul>
                        """)
                        Link("Go Pro", target: "#").class("aqua-btn")
                    }.class("aqua-pricing-card", "aqua-popular", "reveal-on-scroll", "reveal-stagger-2")
                }.class("aqua-pricing")
            }.class("aqua-container").id("pricing")
            
            // Footer
            Section {
                Text("© 2026 Scribe Inc. All rights reserved.")
            }.class("aqua-footer", "aqua-container")
            
        }
    }
}
