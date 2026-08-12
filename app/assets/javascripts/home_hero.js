// The grid at the top of the homepage is one request to the public API,
// rendered. Shuffling asks for another page of the same collection, and every
// tile — picture, name, group, life span — is built from that single response.
(function () {
  "use strict";

  var PATH = "/api/v2/breeds";

  function ready(fn) {
    if (document.readyState !== "loading") return fn();
    document.addEventListener("DOMContentLoaded", fn);
  }

  ready(function () {
    var hero = document.querySelector("[data-hero]");
    if (!hero) return;

    var grid = hero.querySelector("[data-hero-grid]");
    var button = hero.querySelector("[data-hero-shuffle]");
    var spinner = hero.querySelector("[data-hero-spinner]");
    var url = hero.querySelector("[data-hero-url]");

    var pages = parseInt(hero.getAttribute("data-hero-pages"), 10) || 1;
    var size = parseInt(hero.getAttribute("data-hero-size"), 10) || 8;
    var current = null;
    var busy = false;

    function query(page) {
      return PATH + "?filter[has_images]=true&page[size]=" + size + "&page[number]=" + page + "&include=group";
    }

    function pick() {
      var next = 1 + Math.floor(Math.random() * pages);
      // One retry is enough to make repeats rare without looping on a short
      // collection.
      if (next === current && pages > 1) next = 1 + Math.floor(Math.random() * pages);

      return next;
    }

    function lifeSpan(life) {
      if (!life) return null;
      var years = [life.min, life.max].filter(function (value) {
        return value !== null && value !== undefined && value !== "";
      });

      return years.length ? years.join("–") + " years" : null;
    }

    // The groups arrive once each, as included records, however many breeds
    // point at them.
    function groups(payload) {
      var names = {};

      (payload.included || []).forEach(function (record) {
        if (record.type === "group") names[record.id] = record.attributes.name;
      });

      return names;
    }

    function path(name) {
      return "/breeds/" + name.toLowerCase().normalize("NFD")
        .replace(/[̀-ͯ]/g, "")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "");
    }

    function tile(breed, groupNames) {
      var attributes = breed.attributes;
      var picture = (attributes.images || [])[0];
      if (!picture) return null;

      var relation = breed.relationships && breed.relationships.group;
      var groupId = relation && relation.data && relation.data.id;
      var facts = [groupNames[groupId], lifeSpan(attributes.life)].filter(Boolean);

      var item = document.createElement("li");
      var link = document.createElement("a");
      var image = document.createElement("img");
      var name = document.createElement("strong");
      var meta = document.createElement("span");

      item.className = "home-hero-card";
      link.href = path(attributes.name);

      image.src = picture.medium;
      image.srcset = picture.thumb + " 200w, " + picture.medium + " 600w";
      image.sizes = "(max-width: 600px) 45vw, 15rem";
      image.alt = "A " + attributes.name;
      image.width = 600;
      image.height = 600;

      name.textContent = attributes.name;
      meta.className = "api-muted";
      meta.textContent = facts.join(" · ");

      link.appendChild(image);
      link.appendChild(name);
      link.appendChild(meta);
      item.appendChild(link);

      return item;
    }

    function render(payload) {
      var names = groups(payload);
      var tiles = (payload.data || []).map(function (breed) {
        return tile(breed, names);
      }).filter(Boolean);

      if (!tiles.length) return false;

      grid.textContent = "";
      tiles.forEach(function (item) {
        grid.appendChild(item);
      });

      return true;
    }

    function done() {
      busy = false;
      button.disabled = false;
      spinner.hidden = true;
      grid.classList.remove("is-loading");
    }

    function shuffle() {
      if (busy) return;

      busy = true;
      button.disabled = true;
      spinner.hidden = false;
      grid.classList.add("is-loading");

      var page = pick();

      fetch(query(page), {headers: {Accept: "application/vnd.api+json"}})
        .then(function (response) {
          if (!response.ok) throw new Error(response.status);

          return response.json();
        })
        .then(function (payload) {
          if (!render(payload)) return done();

          current = page;
          // The URL under the grid is the one that produced it, so it only
          // changes once the new dogs are on screen.
          url.textContent = "https://dogapi.dog" + query(page).replace("&include=group", "");

          // The last picture to arrive ends the wait, so the button comes back
          // when the grid is really there.
          var pictures = Array.prototype.slice.call(grid.querySelectorAll("img"));
          var pending = pictures.filter(function (image) {
            return !image.complete;
          });

          if (!pending.length) return done();

          var left = pending.length;
          pending.forEach(function (image) {
            var settle = function () {
              left -= 1;
              if (left === 0) done();
            };

            image.addEventListener("load", settle, {once: true});
            image.addEventListener("error", settle, {once: true});
          });
        })
        .catch(function () {
          done();
        });
    }

    // A single page would shuffle to the dogs already on screen, forever.
    if (button && pages > 1) {
      button.hidden = false;
      button.addEventListener("click", shuffle);
    }
  });
})();
