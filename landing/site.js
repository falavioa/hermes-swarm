/* Shared behaviour for every page: nav scroll state, reveal-on-scroll,
   and copy-to-clipboard for any [data-copy] button. Page-specific demos
   (console feed, install terminal) live inline on their own pages. */
(function(){
  "use strict";
  var root = document.documentElement;
  root.classList.remove('no-js');
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(!reduce) root.classList.add('js-anim');

  /* nav scroll state */
  var nav = document.getElementById('nav');
  if(nav){
    var onScroll = function(){ nav.classList.toggle('scrolled', window.scrollY > 20); };
    onScroll(); window.addEventListener('scroll', onScroll, {passive:true});
  }

  /* reveal on intersection */
  var reveals = [].slice.call(document.querySelectorAll('.reveal'));
  if(reduce || !('IntersectionObserver' in window)){
    reveals.forEach(function(el){ el.classList.add('in'); });
  } else {
    var io = new IntersectionObserver(function(ents){
      ents.forEach(function(e){ if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
    }, {threshold:0.12, rootMargin:'0px 0px -8% 0px'});
    reveals.forEach(function(el){ io.observe(el); });
    setTimeout(function(){ reveals.forEach(function(el){ el.classList.add('in'); }); }, 2600);
  }

  /* copy-to-clipboard: any element with data-copy="..." */
  function flash(btn){
    var span = btn.querySelector('span');
    var prev = span ? span.textContent : btn.textContent;
    if(span) span.textContent = 'Copied'; else btn.textContent = 'Copied';
    setTimeout(function(){ if(span) span.textContent = prev; else btn.textContent = prev; }, 1500);
  }
  function copyText(txt, btn){
    if(navigator.clipboard && navigator.clipboard.writeText){
      navigator.clipboard.writeText(txt).then(function(){ flash(btn); }).catch(function(){});
    } else {
      var ta = document.createElement('textarea'); ta.value = txt;
      document.body.appendChild(ta); ta.select();
      try{ document.execCommand('copy'); flash(btn); }catch(e){}
      document.body.removeChild(ta);
    }
  }
  [].slice.call(document.querySelectorAll('[data-copy]')).forEach(function(btn){
    btn.addEventListener('click', function(){ copyText(btn.getAttribute('data-copy'), btn); });
  });
})();
