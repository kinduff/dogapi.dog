// Interactive request panels for the API reference.
//
// Requests go to the current origin rather than the canonical host in the curl
// example, so the docs exercise whatever deployment you are looking at and the
// content security policy stays at connect-src 'self'.
(function () {
  "use strict";

  function paramInputs(form) {
    return Array.prototype.slice.call(form.querySelectorAll("[data-param]"));
  }

  function buildUrl(form) {
    var path = form.getAttribute("data-path");
    var query = [];

    paramInputs(form).forEach(function (input) {
      var name = input.getAttribute("data-param");
      var value = input.value.trim();

      if (input.getAttribute("data-in") === "path") {
        path = path.replace("{" + name + "}", encodeURIComponent(value || "{" + name + "}"));
      } else if (value !== "") {
        query.push(encodeURIComponent(name) + "=" + encodeURIComponent(value));
      }
    });

    return form.getAttribute("data-base") + path + (query.length ? "?" + query.join("&") : "");
  }

  function formatBody(text, contentType) {
    if (contentType && contentType.indexOf("json") !== -1) {
      try {
        return JSON.stringify(JSON.parse(text), null, 2);
      } catch (error) {
        return text;
      }
    }

    return text;
  }

  function show(form, className, message) {
    var output = form.querySelector("[data-api-output]");
    var status = form.querySelector("[data-api-status]");

    output.hidden = false;
    status.className = "api-status " + className;
    status.textContent = message;
  }

  function send(form) {
    var url = buildUrl(form);
    var body = form.querySelector("[data-api-body]");
    var urlLabel = form.querySelector("[data-api-url]");
    var startedAt = (window.performance || Date).now();

    urlLabel.textContent = url;
    show(form, "api-status-pending", "…");
    body.textContent = "";

    fetch(url, { headers: { Accept: "application/json" } })
      .then(function (response) {
        return response.text().then(function (text) {
          var elapsed = Math.round((window.performance || Date).now() - startedAt);
          var kind = response.ok ? "2xx" : String(response.status).charAt(0) + "xx";

          show(form, "api-status-" + kind, response.status + " " + response.statusText + " · " + elapsed + " ms");
          body.textContent = formatBody(text, response.headers.get("content-type"));
        });
      })
      .catch(function (error) {
        show(form, "api-status-4xx", "Request failed");
        body.textContent = String(error);
      });
  }

  function reset(form) {
    paramInputs(form).forEach(function (input) {
      input.value = input.getAttribute("data-default") || "";
    });

    var output = form.querySelector("[data-api-output]");
    output.hidden = true;
  }

  function copy(button) {
    var target = document.getElementById(button.getAttribute("data-api-copy"));
    if (!target) return;

    var done = function () {
      var original = button.textContent;
      button.textContent = "Copied";
      window.setTimeout(function () {
        button.textContent = original;
      }, 1500);
    };

    if (navigator.clipboard) {
      navigator.clipboard.writeText(target.textContent).then(done);
    }
  }

  document.addEventListener("submit", function (event) {
    var form = event.target.closest("[data-api-try]");
    if (!form) return;

    event.preventDefault();
    send(form);
  });

  document.addEventListener("click", function (event) {
    var resetButton = event.target.closest("[data-api-reset]");
    if (resetButton) {
      reset(resetButton.closest("[data-api-try]"));
      return;
    }

    var copyButton = event.target.closest("[data-api-copy]");
    if (copyButton) copy(copyButton);
  });
})();
