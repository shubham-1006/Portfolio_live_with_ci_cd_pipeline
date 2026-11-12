  const revealEls = document.querySelectorAll('.reveal');
  const io = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('in');
        io.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  revealEls.forEach(el => io.observe(el));

  function togglePanel(panelId, btnId){
    const panel = document.getElementById(panelId);
    const btn = document.getElementById(btnId);
    const isOpen = panel.classList.toggle('open');
    btn.setAttribute('aria-expanded', isOpen);
    btn.textContent = isOpen ? 'Quick facts ↑' : 'Quick facts ↓';
  }

  function toggleSkill(groupId){
    const group = document.getElementById(groupId);
    const btn = group.querySelector('.skill-toggle');
    const isOpen = group.classList.toggle('open');
    btn.setAttribute('aria-expanded', isOpen);
  }

  function toggleProject(cardId){
    const card = document.getElementById(cardId);
    const btn = card.querySelector('.know-more-btn');
    const isOpen = card.classList.toggle('open');
    btn.setAttribute('aria-expanded', isOpen);
    btn.textContent = isOpen ? 'Show less' : 'Know more about this';
  }
