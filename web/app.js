document.addEventListener('DOMContentLoaded', () => {
  // Demo Logic
  const micBtn = document.getElementById('micBtn');
  const output = document.getElementById('output');
  const modeBtns = document.querySelectorAll('.mode-btn');

  const texts = {
    raw: '"So, uh, эээ we should update the Scribe Pro API response models, and, like, make sure that token validation happens in under 200 milliseconds."',
    executive: '"The Scribe Pro API response models must be revised to ensure token validation completes in <200ms."'
  };

  let mode = 'raw';
  let isTyping = false;

  modeBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      modeBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      mode = btn.getAttribute('data-mode');
      output.innerText = texts[mode];
    });
  });

  if (micBtn) {
    micBtn.addEventListener('click', () => {
      if (isTyping) return;
      isTyping = true;
      micBtn.classList.add('active');
      micBtn.querySelector('span').innerText = 'Processing...';
      
      const fullText = texts[mode];
      output.innerText = '';
      let i = 0;
      
      const int = setInterval(() => {
        if (i < fullText.length) {
          output.innerText += fullText[i];
          i++;
        } else {
          clearInterval(int);
          isTyping = false;
          micBtn.classList.remove('active');
          micBtn.querySelector('span').innerText = 'Simulate Voice';
        }
      }, 15);
    });
  }

  // Settings Panel Logic
  const checkSVG = `<svg class="check-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>`;

  document.querySelectorAll('.theme-option').forEach(opt => {
    opt.addEventListener('click', () => {
      // Update UI active states
      document.querySelectorAll('.theme-option').forEach(o => {
        o.classList.remove('active');
        const icon = o.querySelector('.check-icon');
        if (icon) icon.remove();
      });
      
      opt.classList.add('active');
      const circle = opt.querySelector('.theme-circle');
      if (circle) circle.insertAdjacentHTML('beforeend', checkSVG);

      // Update actual theme on body
      const targetTheme = opt.getAttribute('data-target');
      document.body.setAttribute('data-theme', targetTheme);
    });
  });

  document.querySelectorAll('.toggle').forEach(t => {
    t.addEventListener('click', () => {
      t.classList.toggle('active');
    });
  });

  // Handle all Segmented Controls logic
  document.querySelectorAll('.segmented-control').forEach(control => {
    const segments = control.querySelectorAll('.segment');
    segments.forEach(segment => {
      segment.addEventListener('click', () => {
        segments.forEach(s => s.classList.remove('active'));
        segment.classList.add('active');
      });
    });
  });

  // Handle Specific Overlay Style Preview Logic
  const overlayStyleControl = document.getElementById('overlayStyleControl');
  if (overlayStyleControl) {
    const styleSegments = overlayStyleControl.querySelectorAll('.segment');
    const previews = document.querySelectorAll('.preview-overlay');

    styleSegments.forEach(segment => {
      segment.addEventListener('click', () => {
        const selectedStyle = segment.getAttribute('data-style');
        
        // Hide all previews
        previews.forEach(p => p.classList.remove('active'));
        
        // Show the active one
        const activePreview = document.querySelector(`.overlay-${selectedStyle}`);
        if (activePreview) {
          activePreview.classList.add('active');
        }
      });
    });
  }
});
