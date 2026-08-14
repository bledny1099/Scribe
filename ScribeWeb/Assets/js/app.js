document.addEventListener('DOMContentLoaded', () => {
  // Splash Screen Logic
  document.body.classList.add('splash-active');
  setTimeout(() => {
    const splash = document.getElementById('splash-screen');
    if (splash) {
      splash.style.opacity = '0';
      splash.style.visibility = 'hidden';
      setTimeout(() => {
        splash.remove();
        document.body.classList.remove('splash-active');
        window.dispatchEvent(new Event('scroll'));
      }, 800);
    }
  }, 2500);

  // Smooth Scrolling for Nav Links
  document.querySelectorAll('.aqua-nav-link').forEach(link => {
    link.addEventListener('click', (e) => {
      const targetId = link.getAttribute('href');
      if (targetId && targetId.startsWith('#') && targetId.length > 1) {
        const targetElement = document.querySelector(targetId);
        if (targetElement) {
          e.preventDefault();
          const navHeight = document.querySelector('.aqua-nav')?.offsetHeight || 0;
          const targetPosition = targetElement.getBoundingClientRect().top + window.scrollY - navHeight;
          window.scrollTo({
            top: targetPosition,
            behavior: 'smooth'
          });
        }
      }
    });
  });

  // Floating Pill Live Typing Logic
  const pillTextElement = document.getElementById('pill-transcription-text');
  if (pillTextElement) {
    const textToType = "Write an analysis on cybersecurity in the field of artificial intelligence.";
    let i = 0;
    
    function typeWriter() {
      if (i < textToType.length) {
        pillTextElement.innerHTML += textToType.charAt(i);
        i++;
        // Randomize typing speed for realism (20ms to 60ms)
        const speed = Math.random() * (60 - 20) + 20;
        setTimeout(typeWriter, speed);
      } else {
        // Reset after 4 seconds
        setTimeout(() => {
          pillTextElement.innerHTML = '';
          i = 0;
          typeWriter();
        }, 4000);
      }
    }
    
    // Start typing after a short delay
    setTimeout(typeWriter, 1000);
  }
  // IntersectionObserver for Scroll Reveal Animations
  const observerOptions = {
    root: null,
    rootMargin: '0px',
    threshold: 0.15
  };

  const observer = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('reveal-active');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  document.querySelectorAll('.reveal-on-scroll').forEach((el) => {
    observer.observe(el);
  });

  // Demo Section Logic
  const startDemoBtn = document.getElementById('start-demo-btn');
  const demoText = document.getElementById('demo-text');
  const demoOverlay = document.getElementById('demo-overlay');
  
  const textToType = "Write a persuasive email to the team explaining why we should switch to Scribe for all our internal documentation. Emphasize the massive time savings and the zero-friction experience.";
  let typingTimer;
  let timeTimer;
  
  if (startDemoBtn) {
    startDemoBtn.addEventListener('click', () => {
      // Hide start overlay
      const startOverlay = document.getElementById('demo-start-overlay');
      if (startOverlay) {
        startOverlay.style.opacity = '0';
        startOverlay.style.pointerEvents = 'none';
      }

      // Reset
      startDemoBtn.disabled = true;
      demoText.textContent = "";
      const demoSubText = document.getElementById('demo-sub-text');
      if (demoSubText) demoSubText.textContent = "";
      demoOverlay.classList.add('active');
      clearInterval(timeTimer);
      clearTimeout(typingTimer);
      
      // Timer logic removed
      
      let i = 0;
      function typeChar() {
        if (i < textToType.length) {
          demoSubText.textContent += textToType.charAt(i);
          i++;
          typingTimer = setTimeout(typeChar, Math.random() * 30 + 10);
        } else {
          // Finished: paste to Notes and fade out
          setTimeout(() => {
            demoText.textContent = textToType; // Paste into Notes
            demoOverlay.classList.remove('active');
            clearInterval(timeTimer);
            startDemoBtn.disabled = false;
            startDemoBtn.textContent = "Try Again";
            
            // Show start overlay again after a slight delay
            setTimeout(() => {
              const startOverlay = document.getElementById('demo-start-overlay');
              if (startOverlay) {
                startOverlay.style.opacity = '1';
                startOverlay.style.pointerEvents = 'auto';
              }
            }, 500);
          }, 1000);
        }
      }
      
      // The widget pops up instantly. We wait 1.2s before typing starts.
      setTimeout(typeChar, 1200);
    });
  }
});
