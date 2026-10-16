// spine.js: the "where is this happening?" panel follows the step being read.
//
// Everything hangs off the markup contract in lessons/README.md: section.step[id] for the steps,
// .where > .strip + .spine for the panel, .lane[data-lane] > .lane-tag + .bar for the lanes, and
// .box[data-step] / .arrow[data-step] inside a bar. The page works without this file; with it, the
// boxes of the step nearest the reading line light up, the strip below 1100 px shows one chip per
// lane, and clicking a box jumps to its step.
//
// No fetch, no modules, no dependencies: lessons run from file://.

(function () {
  'use strict';

  var WIDE    = '(min-width: 1100px)';
  var REDUCED = '(prefers-reduced-motion: reduce)';
  var STAGGER = 'spine-stagger';   // the id of the hand-off animation, so tests and cancels can find it

  var state = { active: null, mode: 'wide', expanded: false };

  var where, strip, spine, toggle;
  var steps = [], boxes = [], arrows = [], lanes = [], chips = {}, chipArrows = [];
  var initialized = false, ticking = false;

  // Pure: the index of the last step whose top is at or above the reading line, else 0.
  function pick(tops, line) {
    var index = 0;
    for (var i = 0; i < tops.length; i++) if (tops[i] <= line) index = i;
    return index;
  }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  function init(root) {
    if (initialized) return state;
    root  = root || document;
    where = root.querySelector('.where');
    if (!where) return state;
    strip = where.querySelector('.strip');
    spine = where.querySelector('.spine');
    if (!strip || !spine) return state;

    steps  = Array.prototype.slice.call(root.querySelectorAll('section.step[id]'));
    boxes  = Array.prototype.slice.call(spine.querySelectorAll('.box'));
    arrows = Array.prototype.slice.call(spine.querySelectorAll('.arrow'));
    lanes  = Array.prototype.slice.call(spine.querySelectorAll('.lane'));

    // the strip: a label, one chip per lane with an arrow between, then the toggle
    strip.textContent = '';
    strip.appendChild(el('span', 'strip-label', 'where'));
    lanes.forEach(function (lane, i) {
      if (i > 0) {
        var a = el('span', 'chip-arrow', '→');
        chipArrows.push(a);
        strip.appendChild(a);
      }
      var tag  = lane.querySelector('.lane-tag');
      var chip = el('span', 'chip', tag ? tag.textContent.trim() : lane.dataset.lane);
      chip.dataset.lane = lane.dataset.lane;
      chips[lane.dataset.lane] = chip;
      strip.appendChild(chip);
    });
    if (!spine.id) spine.id = 'spine';
    toggle = el('button', 'strip-toggle', 'expand ▾');
    toggle.type = 'button';
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-controls', spine.id);
    toggle.addEventListener('click', function () { setExpanded(!state.expanded); });
    strip.appendChild(toggle);

    boxes.forEach(function (b) {
      b.type = 'button';
      b.addEventListener('click', function () { jump(b.dataset.step); });
    });

    var wide = window.matchMedia(WIDE);
    setMode(wide.matches ? 'wide' : 'narrow');
    wide.addEventListener('change', function (e) { setMode(e.matches ? 'wide' : 'narrow'); });

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);

    initialized = true;
    update();
    return state;
  }

  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () {
      ticking = false;
      update();
    });
  }

  // The reading line sits 40 % down the viewport, below the strip when there is one.
  function update() {
    if (!steps.length) return;
    var tops = steps.map(function (s) { return s.getBoundingClientRect().top; });
    var line = 0.4 * window.innerHeight + (strip ? strip.offsetHeight : 0);
    var id = steps[pick(tops, line)].id;
    if (id !== state.active) activate(id);
  }

  function activate(id) {
    state.active = id;
    spine.classList.add('live');

    var lit = [];
    boxes.forEach(function (b) {
      var on = b.dataset.step === id;
      b.classList.toggle('on', on);
      if (on) lit.push(b);
    });
    arrows.forEach(function (a) { a.classList.toggle('on', a.dataset.step === id); });
    steps.forEach(function (s) {
      if (s.id === id) s.setAttribute('aria-current', 'step');
      else s.removeAttribute('aria-current');
    });
    updateChips(lit);

    // the hand-off: the step's boxes light one after another, in document order
    if (!window.matchMedia(REDUCED).matches && typeof Element.prototype.animate === 'function') {
      lit.forEach(function (b, i) {
        b.getAnimations().forEach(function (a) { if (a.id === STAGGER) a.cancel(); });
        b.animate([{ opacity: 0.4 }, { opacity: 1 }], { duration: 180, delay: i * 120, id: STAGGER });
      });
    }
    return state;
  }

  function updateChips(lit) {
    var litLanes = {};
    lit.forEach(function (b) {
      var lane = b.closest('.lane');
      if (lane) litLanes[lane.dataset.lane] = true;
    });
    var first = true;
    lanes.forEach(function (lane) {
      var name = lane.dataset.lane, chip = chips[name];
      var on = !!litLanes[name];
      chip.classList.toggle('on', on);
      var sub = chip.querySelector('.sub');
      if (sub) sub.remove();
      if (on && first) {
        first = false;
        chip.appendChild(el('span', 'sub', ' · ' + lit[0].textContent.trim()));
      }
    });
    chipArrows.forEach(function (a, i) {
      a.classList.toggle('on', !!(litLanes[lanes[i].dataset.lane] && litLanes[lanes[i + 1].dataset.lane]));
    });
  }

  function setExpanded(on) {
    state.expanded = !!on;
    if (where) where.classList.toggle('expanded', state.expanded);
    if (toggle) {
      toggle.setAttribute('aria-expanded', String(state.expanded));
      toggle.textContent = state.expanded ? 'collapse ▴' : 'expand ▾';
    }
    return state;
  }

  function setMode(mode) {
    state.mode = mode;
    setExpanded(false);
    return state;
  }

  function jump(id) {
    var step = null;
    steps.forEach(function (s) { if (s.id === id) step = s; });
    if (!step) return;
    window.history.replaceState(null, '', '#' + id);
    step.scrollIntoView({ block: 'start' });
    activate(id);
    if (state.mode === 'narrow') setExpanded(false);
  }

  window.Spine = { pick: pick, init: init, activate: activate, setExpanded: setExpanded, setMode: setMode, state: state };

  document.addEventListener('DOMContentLoaded', function () {
    if (document.querySelector('.where')) init(document);
  });
})();
