// The picture at the top of the homepage. Shuffling it is a real call to the
// public API: one request for the breed, and the picture itself is the image
// endpoint, so what the page shows is what a reader would get from the same
// two URLs.
(function () {
  "use strict";

  var IMAGE_SIZE = "large";

  function ready(fn) {
    if (document.readyState !== "loading") return fn();
    document.addEventListener("DOMContentLoaded", fn);
  }

  ready(function () {
    var hero = document.querySelector("[data-hero]");
    if (!hero) return;

    var button = hero.querySelector("[data-hero-shuffle]");
    var image = hero.querySelector("[data-hero-image]");
    var spinner = hero.querySelector("[data-hero-spinner]");
    var name = hero.querySelector("[data-hero-name]");
    var meta = hero.querySelector("[data-hero-meta]");
    var url = hero.querySelector("[data-hero-url]");
    var status = hero.querySelector("[data-hero-status]");
    var links = hero.querySelectorAll("[data-hero-picture], [data-hero-link]");

    var pool = [];
    try {
      pool = JSON.parse(hero.getAttribute("data-hero-pool") || "[]");
    } catch (error) {
      pool = [];
    }

    // A single breed would shuffle to the dog already on screen, forever.
    if (!button || pool.length < 2) return;
    button.hidden = false;

    var current = null;
    var busy = false;

    function lifeSpan(life) {
      if (!life) return null;
      var years = [life.min, life.max].filter(function (value) {
        return value !== null && value !== undefined && value !== "";
      });

      return years.length ? years.join("–") + " years" : null;
    }

    function pick() {
      var next = pool[Math.floor(Math.random() * pool.length)];
      // One retry is enough to make repeats rare without looping on a short
      // list.
      if (current && next.id === current.id) next = pool[Math.floor(Math.random() * pool.length)];

      return next;
    }

    function groupName(payload) {
      var relation = payload.data.relationships && payload.data.relationships.group;
      var groupId = relation && relation.data && relation.data.id;
      var included = payload.included || [];

      for (var index = 0; index < included.length; index++) {
        if (included[index].id === groupId) return included[index].attributes.name;
      }

      return null;
    }

    function render(payload, breed) {
      var attributes = payload.data.attributes;
      var facts = [groupName(payload), lifeSpan(attributes.life)].filter(Boolean);

      name.textContent = attributes.name;
      meta.textContent = facts.join(" · ");
      image.alt = "A " + attributes.name;

      Array.prototype.forEach.call(links, function (link) {
        link.href = breed.path;
      });

      // The picture is a second request to the image endpoint, which is the
      // one the snippet under the card is about.
      var imageUrl = "/api/v2/breeds/" + breed.id + "/image?size=" + IMAGE_SIZE;
      url.textContent = imageUrl;
      image.src = imageUrl;
    }

    function done(message) {
      busy = false;
      button.disabled = false;
      spinner.hidden = true;
      status.textContent = message;
    }

    function shuffle() {
      if (busy) return;

      busy = true;
      button.disabled = true;
      spinner.hidden = false;
      status.textContent = "Asking the API…";

      var breed = pick();
      current = breed;

      // The group travels as an included record, which is where its name is:
      // the breed itself only carries the relationship.
      fetch("/api/v2/breeds/" + breed.id + "?include=group", {headers: {Accept: "application/vnd.api+json"}})
        .then(function (response) {
          if (!response.ok) throw new Error(response.status + " " + response.statusText);

          return response.json();
        })
        .then(function (payload) {
          render(payload, breed);

          // The button comes back when the picture is on screen, not when the
          // JSON lands, so a fast clicker cannot stack requests.
          if (image.complete) return done("200 OK");
          image.addEventListener("load", function () { done("200 OK"); }, {once: true});
          image.addEventListener("error", function () { done("The picture did not load"); }, {once: true});
        })
        .catch(function (error) {
          done("Could not reach the API (" + error.message + ")");
        });
    }

    button.addEventListener("click", shuffle);
  });
})();
