// Thumbnails on a breed page swap the big picture instead of navigating to the
// file. Without this script they stay ordinary links, which is what they are.
(function () {
  "use strict";

  function select(link) {
    var gallery = document.querySelector("[data-gallery]");
    if (!gallery) return;

    var hero = gallery.querySelector("[data-gallery-hero]");
    var heroLink = gallery.querySelector("[data-gallery-link]");
    var id = link.getAttribute("data-image-id");

    hero.src = link.getAttribute("data-large");
    heroLink.href = link.getAttribute("href");

    // Captions are rendered server side, one per image; only the one belonging
    // to the picture on display is shown.
    Array.prototype.forEach.call(gallery.querySelectorAll("[data-gallery-credit]"), function (credit) {
      credit.hidden = credit.getAttribute("data-gallery-credit") !== id;
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-gallery-item]"), function (item) {
      item.classList.toggle("is-current", item === link);
    });
  }

  function step(offset) {
    var items = Array.prototype.slice.call(document.querySelectorAll("[data-gallery-item]"));
    if (items.length < 2) return;

    var current = items.findIndex(function (item) {
      return item.classList.contains("is-current");
    });
    var next = (current + offset + items.length) % items.length;

    select(items[next]);
    items[next].focus();
  }

  document.addEventListener("click", function (event) {
    var link = event.target.closest("[data-gallery-item]");
    if (!link) return;

    // Ctrl, middle click and the like keep opening the file in a new tab.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;

    event.preventDefault();
    select(link);
  });

  document.addEventListener("keydown", function (event) {
    if (!document.querySelector("[data-gallery]")) return;
    if (event.target.closest("input, textarea")) return;

    if (event.key === "ArrowRight") step(1);
    if (event.key === "ArrowLeft") step(-1);
  });
})();
