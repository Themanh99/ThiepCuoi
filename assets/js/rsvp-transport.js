(function () {
  'use strict';
  var boxes = document.querySelectorAll('[data-rsvp-transport]');
  function sync(box) {
    var form = box.closest('form');
    var attend = form.querySelector('input[name="attend"]:checked') || form.querySelector('input[type="hidden"][name="attend"]');
    var available = attend && attend.value === 'yes';
    var shuttle = form.elements.shuttle, select = form.elements.shuttle_return;
    box.hidden = !available;
    shuttle.disabled = !available;
    select.disabled = !available || !shuttle.checked;
    select.required = !select.disabled;
    box.querySelector('[data-shuttle-return]').hidden = select.disabled;
    box.querySelector('[data-shuttle-error]').hidden = true;
    select.removeAttribute('aria-invalid');
  }
  boxes.forEach(function (box) {
    var form = box.closest('form');
    form.addEventListener('change', function () { sync(box); });
    form.addEventListener('submit', function (event) {
      sync(box);
      var select = form.elements.shuttle_return;
      if (!select.disabled && !select.value) {
        event.preventDefault();
        event.stopImmediatePropagation();
        box.querySelector('[data-shuttle-error]').hidden = false;
        select.setAttribute('aria-invalid', 'true');
        select.focus();
      }
    }, true);
    sync(box);
  });
  // The invitation uses buttons to set its hidden attendance input.
  document.addEventListener('click', function (event) {
    if (event.target.closest('[data-ic-attend]')) boxes.forEach(sync);
  });
  document.addEventListener('ac:rsvp', function (event) {
    var answer = event.detail;
    if (!answer || !Object.prototype.hasOwnProperty.call(answer, 'shuttle_return')) return;
    boxes.forEach(function (box) {
      var form = box.closest('form');
      form.elements.shuttle.checked = !!answer.shuttle_return;
      form.elements.shuttle_return.value = answer.shuttle_return || '';
      sync(box);
    });
  });
})();
