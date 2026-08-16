const selector = "select:not([multiple]):not([data-native-select])";

function closeAll(except = null) {
  document.querySelectorAll("[data-app-select-menu]").forEach((menu) => {
    if (menu !== except) menu.hidden = true;
  });
  document.querySelectorAll("[data-app-select-trigger]").forEach((trigger) => trigger.setAttribute("aria-expanded", "false"));
}

function enhance(select) {
  if (select.dataset.appSelectReady || select.disabled) return;
  select.dataset.appSelectReady = "true";
  const shell = document.createElement("div");
  shell.className = "app-select";
  shell.dataset.appSelect = "";
  select.parentNode.insertBefore(shell, select);
  shell.appendChild(select);
  select.classList.add("app-select-native");
  select.tabIndex = -1;

  const trigger = document.createElement("button");
  trigger.type = "button";
  trigger.className = "app-select-trigger";
  trigger.dataset.appSelectTrigger = "";
  trigger.setAttribute("aria-haspopup", "listbox");
  trigger.setAttribute("aria-expanded", "false");
  const label = document.createElement("span");
  const chevron = document.createElement("span");
  chevron.className = "app-select-chevron";
  chevron.textContent = "⌄";
  trigger.append(label, chevron);

  const menu = document.createElement("div");
  menu.className = "app-select-menu";
  menu.dataset.appSelectMenu = "";
  menu.setAttribute("role", "listbox");
  menu.hidden = true;
  shell.append(trigger, menu);

  const render = () => {
    label.textContent = select.selectedOptions[0]?.textContent?.trim() || "Seleccionar";
    menu.replaceChildren();
    Array.from(select.options).forEach((option) => {
      const item = document.createElement("button");
      item.type = "button";
      item.className = "app-select-option";
      item.textContent = option.text;
      item.disabled = option.disabled;
      item.classList.toggle("is-selected", option.selected);
      item.setAttribute("role", "option");
      item.setAttribute("aria-selected", option.selected ? "true" : "false");
      item.addEventListener("click", () => {
        select.value = option.value;
        select.dispatchEvent(new Event("change", { bubbles: true }));
        render(); closeAll();
      });
      menu.appendChild(item);
    });
  };
  trigger.addEventListener("click", () => {
    const open = menu.hidden;
    closeAll(menu);
    menu.hidden = !open;
    trigger.setAttribute("aria-expanded", open ? "true" : "false");
  });
  select.addEventListener("change", render);
  render();
}

function enhanceAll() { document.querySelectorAll(selector).forEach(enhance); }

function enhanceAutocomplete(root) {
  if (root.dataset.appAutocompleteReady) return;
  const input = root.querySelector("[data-breed-autocomplete-input]");
  const menu = root.querySelector("[data-breed-autocomplete-menu]");
  if (!input || !menu) return;

  root.dataset.appAutocompleteReady = "true";
  const options = JSON.parse(root.dataset.breedOptions || "[]");
  const render = (query = "") => {
    const normalizedQuery = query.trim().toLocaleLowerCase("es");
    const matches = options.filter((option) => option.toLocaleLowerCase("es").includes(normalizedQuery));
    menu.replaceChildren();
    matches.forEach((option) => {
      const item = document.createElement("button");
      item.type = "button";
      item.className = "app-select-option";
      item.textContent = option;
      item.setAttribute("role", "option");
      item.addEventListener("mousedown", (event) => event.preventDefault());
      item.addEventListener("click", () => {
        input.value = option;
        input.dispatchEvent(new Event("change", { bubbles: true }));
        menu.hidden = true;
        input.setAttribute("aria-expanded", "false");
      });
      menu.appendChild(item);
    });
  };
  const open = () => {
    closeAll(menu);
    render(input.value);
    menu.hidden = false;
    input.setAttribute("aria-expanded", "true");
  };
  input.addEventListener("focus", open);
  input.addEventListener("input", open);
  input.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      menu.hidden = true;
      input.setAttribute("aria-expanded", "false");
      input.blur();
    }
  });
}

function enhanceAutocompletes() { document.querySelectorAll("[data-breed-autocomplete]").forEach(enhanceAutocomplete); }
document.addEventListener("turbo:load", enhanceAll);
document.addEventListener("turbo:frame-load", enhanceAll);
document.addEventListener("turbo:load", enhanceAutocompletes);
document.addEventListener("turbo:frame-load", enhanceAutocompletes);
document.addEventListener("click", (event) => { if (!event.target.closest("[data-app-select]")) closeAll(); });
